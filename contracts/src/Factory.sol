// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {ITicket} from "./interfaces/ITicket.sol";
import {ISale} from "./interfaces/ISale.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";
import {IFactory} from "./interfaces/IFactory.sol";

/// @notice Factory for cloning and initializing event ticketing contracts.
/// @dev Ownable with a timelocked implementation upgrade flow.
contract Factory is IFactory, Ownable2Step {
    using Clones for address;

    uint256 public constant IMPLEMENTATION_UPGRADE_DELAY = 7 days;
    uint256 public constant TOTAL_FEE_BPS = 1_000; // 10% of sales
    uint256 public constant ORGANIZER_FEE_BPS_OF_TOTAL = 5_000; // 50% of total fees

    address public eventTicketImpl;
    address public ticketSaleImpl;
    address public ticketMarketplaceImpl;

    address public pendingTicketImpl;
    address public pendingSaleImpl;
    address public pendingMarketplaceImpl;

    uint256 public implementationUpgradeTime;
    uint256 public nextEventId;

    // Event ID => Event Entry
    mapping(uint256 => EventEntry) public eventsById;

    // Organzizer => Event IDs
    mapping(address => uint256[]) public eventIdsByOrganizer;

    // Event Ticket address => Event ID
    mapping(address => uint256) public eventIdByTicket;

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
        pendingTicketImpl = _eventTicketImpl;
        pendingSaleImpl = _ticketSaleImpl;
        pendingMarketplaceImpl = _ticketMarketplaceImpl;
        implementationUpgradeTime = block.timestamp + IMPLEMENTATION_UPGRADE_DELAY;
        emit ImplementationsProposed(
            pendingTicketImpl, pendingSaleImpl, pendingMarketplaceImpl, implementationUpgradeTime
        );
    }

    /// @notice Executes the implementation upgrade after the upgrade delay.
    /// @dev Only callable by the owner and only after a proposal is active and mature.
    function executeImplementationUpgrade() external onlyOwner {
        require(implementationUpgradeTime > 0, "No active proposal");
        require(block.timestamp > implementationUpgradeTime, "Upgrade delay haven't passed");

        eventTicketImpl = pendingTicketImpl;
        ticketSaleImpl = pendingSaleImpl;
        ticketMarketplaceImpl = pendingMarketplaceImpl;

        implementationUpgradeTime = 0;
        pendingTicketImpl = address(0);
        pendingSaleImpl = address(0);
        pendingMarketplaceImpl = address(0);

        emit ImplementationsUpgraded(eventTicketImpl, ticketSaleImpl, ticketMarketplaceImpl, block.timestamp);
    }

    /// @notice Clones and initializes ticket, sale, and marketplace contracts for a new event.
    /// @dev Organizer stored in factory is the caller, but params can set organizer in child contracts.
    /// @param createSaleParams Parameters to initialize the event contracts.
    function createSale(IFactory.CreateSaleParams memory createSaleParams) external {
        // clone implementations
        address eventTicket = eventTicketImpl.clone();
        address ticketSale = ticketSaleImpl.clone();
        address ticketMarketplace = ticketMarketplaceImpl.clone();

        ITicket.TicketInitParams memory eventTicketInitParams = ITicket.TicketInitParams({
            name: createSaleParams.name,
            symbol: createSaleParams.symbol,
            baseURI: createSaleParams.baseURI,
            organizer: createSaleParams.organizer,
            ticketSale: ticketSale,
            ticketMarketplace: ticketMarketplace
        });
        ITicket(eventTicket).initialize(eventTicketInitParams);

        ISale.SaleInitParams memory ticketSaleInitParams = ISale.SaleInitParams({
            eventTicket: eventTicket,
            organizer: createSaleParams.organizer,
            saleStart: createSaleParams.saleStart,
            saleEnd: createSaleParams.saleEnd,
            ticketPriceInWei: createSaleParams.priceInWei,
            ticketMaxSupply: createSaleParams.maxSupply
        });
        require(ticketSaleInitParams.saleStart >= block.timestamp, "Sale start cannot be in the past");
        require(
            ticketSaleInitParams.saleStart < ticketSaleInitParams.saleEnd, "Sale end must be greater than sale start"
        );
        require(ticketSaleInitParams.ticketMaxSupply > 0, "Sale should have positive number of ticket supply");
        ISale(ticketSale).initialize(ticketSaleInitParams);

        IMarketplace.MarketplaceInitParams memory ticketMarketplaceInitParams = IMarketplace.MarketplaceInitParams({
            eventTicket: eventTicket,
            organizer: createSaleParams.organizer,
            protocol: owner(),
            totalFees: TOTAL_FEE_BPS,
            organizerFee: ORGANIZER_FEE_BPS_OF_TOTAL
        });
        IMarketplace(ticketMarketplace).initialize(ticketMarketplaceInitParams);

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
    function getSale(address eventTicket) external view returns (address ticketSale) {
        uint256 eventId = eventIdByTicket[eventTicket];
        ticketSale = eventsById[eventId].ticketSale;
    }

    /// @notice Returns the marketplace contract for a given event ticket contract.
    /// @param eventTicket Event ticket contract address.
    /// @return ticketMarketplace Ticket marketplace contract address.
    function getMarketplace(address eventTicket) external view returns (address ticketMarketplace) {
        uint256 eventId = eventIdByTicket[eventTicket];
        ticketMarketplace = eventsById[eventId].ticketMarketplace;
    }
}
