// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {IEventTicket} from "./interfaces/IEventTicket.sol";
import {ITicketSale} from "./interfaces/ITicketSale.sol";
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import {IEventFactory} from "./interfaces/IEventFactory.sol";

/// @notice Factory for cloning and initializing event ticketing contracts.
/// @dev Ownable with a timelocked implementation upgrade flow.
contract EventFactory is IEventFactory, Ownable2Step {
    using Clones for address;

    uint256 constant IMPLEMENTATION_UPGRADE_DELAY = 7 days;
    uint256 constant TOTAL_FEE_BPS = 1_000; // 10% of sales
    uint256 constant ORGANIZER_FEE_BPS_OF_TOTAL = 5_000; // 50% of total fees

    address public eventTicketImpl;
    address public ticketSaleImpl;
    address public ticketMarketplaceImpl;

    address public pendingEventTicketImpl;
    address public pendingTicketSaleImpl;
    address public pendingTicketMarketplaceImpl;

    uint256 public implementationUpgradeTime;
    uint256 public nextEventId;

    // Event ID => Event Entry
    mapping(uint256 => EventEntry) eventsById;

    // Organzizer => Event IDs
    mapping(address => uint256[]) eventIdsByOrganizer;

    // Event Ticket address => Event ID
    mapping(address => uint256) eventIdByTicket;

    /// @notice Creates the factory and sets the initial implementations.
    /// @dev Reverts if any implementation address is not a contract.
    /// @param _owner Owner address for the factory.
    /// @param _eventTicketImpl Event ticket implementation address.
    /// @param _ticketSaleImpl Ticket sale implementation address.
    /// @param _ticketMarketplaceImpl Ticket marketplace implementation address.
    constructor(address _owner, address _eventTicketImpl, address _ticketSaleImpl, address _ticketMarketplaceImpl)
        Ownable(_owner)
    {
        require(_eventTicketImpl.code.length > 0, "Not a contract");
        require(_ticketSaleImpl.code.length > 0, "Not a contract");
        require(_ticketMarketplaceImpl.code.length > 0, "Not a contract");
        eventTicketImpl = _eventTicketImpl;
        ticketSaleImpl = _ticketSaleImpl;
        ticketMarketplaceImpl = _ticketMarketplaceImpl;
    }

    /// @notice Proposes new implementation addresses subject to the upgrade delay.
    /// @dev Only callable by the owner.
    /// @param _eventTicketImpl Proposed event ticket implementation.
    /// @param _ticketSaleImpl Proposed ticket sale implementation.
    /// @param _ticketMarketplaceImpl Proposed ticket marketplace implementation.
    function proposeImplementationUpgrade(
        address _eventTicketImpl,
        address _ticketSaleImpl,
        address _ticketMarketplaceImpl
    ) external onlyOwner {
        require(_eventTicketImpl.code.length > 0, "Not a contract");
        require(_ticketSaleImpl.code.length > 0, "Not a contract");
        require(_ticketMarketplaceImpl.code.length > 0, "Not a contract");
        pendingEventTicketImpl = _eventTicketImpl;
        pendingTicketSaleImpl = _ticketSaleImpl;
        pendingTicketMarketplaceImpl = _ticketMarketplaceImpl;
        implementationUpgradeTime = block.timestamp + IMPLEMENTATION_UPGRADE_DELAY;
        emit ImplementationsProposed(
            pendingEventTicketImpl, pendingTicketSaleImpl, pendingTicketMarketplaceImpl, implementationUpgradeTime
        );
    }

    /// @notice Executes the implementation upgrade after the upgrade delay.
    /// @dev Only callable by the owner and only after a proposal is active and mature.
    function executeImplementationUpgrade() external onlyOwner {
        require(implementationUpgradeTime > 0, "No active proposal");
        require(block.timestamp > implementationUpgradeTime, "Upgrade delay haven't passed");

        eventTicketImpl = pendingEventTicketImpl;
        ticketSaleImpl = pendingTicketSaleImpl;
        ticketMarketplaceImpl = pendingTicketMarketplaceImpl;

        implementationUpgradeTime = 0;
        pendingEventTicketImpl = address(0);
        pendingTicketSaleImpl = address(0);
        pendingTicketMarketplaceImpl = address(0);

        emit ImplementationsUpgraded(eventTicketImpl, ticketSaleImpl, ticketMarketplaceImpl, block.timestamp);
    }

    /// @notice Clones and initializes ticket, sale, and marketplace contracts for a new event.
    /// @dev Organizer stored in factory is the caller, but params can set organizer in child contracts.
    /// @param createTicketSaleParams Parameters to initialize the event contracts.
    function createTicketSale(IEventFactory.CreateTicketSaleParams memory createTicketSaleParams) external {
        // clone implementations
        address eventTicket = eventTicketImpl.clone();
        address ticketSale = ticketSaleImpl.clone();
        address ticketMarketplace = ticketMarketplaceImpl.clone();

        IEventTicket.EventTicketInitParams memory eventTicketInitParams = IEventTicket.EventTicketInitParams({
            name: createTicketSaleParams.name,
            symbol: createTicketSaleParams.symbol,
            baseURI: createTicketSaleParams.baseURI,
            organizer: createTicketSaleParams.organizer,
            ticketSale: ticketSale,
            ticketMarketplace: ticketMarketplace
        });
        IEventTicket(eventTicket).initialize(eventTicketInitParams);

        ITicketSale.TicketSaleInitParams memory ticketSaleInitParams = ITicketSale.TicketSaleInitParams({
            eventTicket: eventTicket,
            organizer: createTicketSaleParams.organizer,
            saleStart: createTicketSaleParams.saleStart,
            saleEnd: createTicketSaleParams.saleEnd,
            ticketPriceInWei: createTicketSaleParams.priceInWei,
            ticketMaxSupply: createTicketSaleParams.maxSupply
        });
        require(ticketSaleInitParams.saleStart >= block.timestamp, "Sale start cannot be in the past");
        require(
            ticketSaleInitParams.saleStart < ticketSaleInitParams.saleEnd, "Sale end must be greater than sale start"
        );
        require(ticketSaleInitParams.ticketMaxSupply > 0, "Sale should have positive number of ticket supply");
        ITicketSale(ticketSale).initialize(ticketSaleInitParams);

        ITicketMarketplace.TicketMarketplaceInitParams memory ticketMarketplaceInitParams =
            ITicketMarketplace.TicketMarketplaceInitParams({
                eventTicket: eventTicket,
                organizer: createTicketSaleParams.organizer,
                protocol: owner(),
                totalFees: TOTAL_FEE_BPS,
                organizerFee: ORGANIZER_FEE_BPS_OF_TOTAL
            });
        ITicketMarketplace(ticketMarketplace).initialize(ticketMarketplaceInitParams);

        EventEntry memory eventEntry = EventEntry({
            id: nextEventId,
            organizer: msg.sender,
            eventTicket: eventTicket,
            ticketSale: ticketSale,
            ticketMarketplace: ticketMarketplace
        });

        eventIdsByOrganizer[msg.sender].push(nextEventId);

        eventIdByTicket[address(eventTicket)] = nextEventId;

        eventsById[nextEventId] = eventEntry;

        nextEventId += 1;

        emit EventCreated(msg.sender, nextEventId - 1, eventTicket, ticketSale, ticketMarketplace);
    }

    /// @notice Returns the sale contract for a given event ticket contract.
    /// @param eventTicket Event ticket contract address.
    /// @return ticketSale Ticket sale contract address.
    function getTicketSale(address eventTicket) external view returns (address ticketSale) {
        uint256 eventId = eventIdByTicket[eventTicket];
        ticketSale = eventsById[eventId].ticketSale;
    }

    /// @notice Returns the marketplace contract for a given event ticket contract.
    /// @param eventTicket Event ticket contract address.
    /// @return ticketMarketplace Ticket marketplace contract address.
    function getTicketMarketplace(address eventTicket) external view returns (address ticketMarketplace) {
        uint256 eventId = eventIdByTicket[eventTicket];
        ticketMarketplace = eventsById[eventId].ticketMarketplace;
    }
}
