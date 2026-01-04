// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Ownable2Step, Ownable} from "openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import {IEventTicket} from "./interfaces/IEventTicket.sol";
import {ITicketSale} from "./interfaces/ITicketSale.sol";
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";
import {IEventFactory} from "./interfaces/IEventFactory.sol";

contract EventFactory is IEventFactory, Ownable2Step {
    using Clones for address;

    uint256 constant DELAY_WINDOW = 7 days;

    address public eventTicketImpl;
    address public ticketSaleImpl;
    address public ticketMarketplaceImpl;

    address public pendingEventTicketImpl;
    address public pendingTicketSaleImpl;
    address public pendingTicketMarketplaceImpl;

    uint256 public implementationsProposedTimestamp;
    uint256 public currentEventId;

    // Event ID => Event Entry
    mapping(uint256 => EventEntry) eventIdToEventEntry;

    // Organzizer => Event IDs
    mapping(address => uint256[]) organizerEventIds;

    // Event Ticket address => Event ID
    mapping(address => uint256) eventTicketToEventId;

    constructor(address _owner, address _eventTicketImpl, address _ticketSaleImpl, address _ticketMarketplaceImpl)
        Ownable(_owner)
    {
        require(eventTicketImpl.code.length > 0, "Not a contract");
        require(ticketSaleImpl.code.length > 0, "Not a contract");
        require(ticketMarketplaceImpl.code.length > 0, "Not a contract");
        eventTicketImpl = _eventTicketImpl;
        ticketSaleImpl = _ticketSaleImpl;
        ticketMarketplaceImpl = _ticketMarketplaceImpl;
    }

    function proposeImplementations(address _eventTicketImpl, address _ticketSaleImpl, address _ticketMarketplaceImpl)
        external
        onlyOwner
    {
        require(_eventTicketImpl.code.length > 0, "Not a contract");
        require(_ticketSaleImpl.code.length > 0, "Not a contract");
        require(_ticketMarketplaceImpl.code.length > 0, "Not a contract");
        pendingEventTicketImpl = _eventTicketImpl;
        pendingTicketSaleImpl = _ticketSaleImpl;
        pendingTicketMarketplaceImpl = _ticketMarketplaceImpl;
        implementationsProposedTimestamp = block.timestamp + DELAY_WINDOW;
        emit ImplementationsProposed(
            pendingEventTicketImpl,
            pendingTicketSaleImpl,
            pendingTicketMarketplaceImpl,
            implementationsProposedTimestamp
        );
    }

    function executeImplementationsUpgrade() external onlyOwner {
        require(implementationsProposedTimestamp > 0, "No active proposal");
        require(block.timestamp > implementationsProposedTimestamp, "Delay window still active");

        eventTicketImpl = pendingEventTicketImpl;
        ticketSaleImpl = pendingTicketSaleImpl;
        ticketMarketplaceImpl = pendingTicketMarketplaceImpl;

        implementationsProposedTimestamp = 0;
        pendingEventTicketImpl = address(0);
        pendingTicketSaleImpl = address(0);
        pendingTicketMarketplaceImpl = address(0);

        emit ImplementationsUpgraded(eventTicketImpl, ticketSaleImpl, ticketMarketplaceImpl, block.timestamp);
    }

    function createTicketSale(
        IEventTicket.EventTicketInitParams memory eventTicketInitParams,
        ITicketSale.TicketSaleInitParams memory ticketSaleInitParams,
        ITicketMarketplace.TicketMarketplaceInitParams memory ticketMarketplaceInitParams
    ) external {
        // clone implementations
        address eventTicket = eventTicketImpl.clone();
        address ticketSale = ticketSaleImpl.clone();
        address ticketMarketplace = ticketMarketplaceImpl.clone();

        // initialize
        eventTicketInitParams.ticketSale = ticketSale;
        eventTicketInitParams.ticketMarketplace = ticketMarketplace;
        IEventTicket(eventTicket).initialize(eventTicketInitParams);

        require(ticketSaleInitParams.saleStart >= block.timestamp, "Sale start cannot be in the past");
        require(
            ticketSaleInitParams.saleStart < ticketSaleInitParams.saleEnd, "Sale end must be greater than sale start"
        );
        ticketSaleInitParams.eventTicket = eventTicket;
        ITicketSale(ticketSale).initialize(ticketSaleInitParams);

        ticketMarketplaceInitParams.eventTicket = eventTicket;
        ticketMarketplaceInitParams.protocol = owner();
        ticketMarketplaceInitParams.totalFees = 1_000; // 10% of sales
        ticketMarketplaceInitParams.organizerFee = 5_000; // 50% of total fees
        ITicketMarketplace(ticketMarketplace).initialize(ticketMarketplaceInitParams);

        EventEntry memory eventEntry = EventEntry({
            id: currentEventId,
            organizer: msg.sender,
            eventTicket: eventTicket,
            ticketSale: ticketSale,
            ticketMarketplace: ticketMarketplace
        });

        organizerEventIds[msg.sender].push(currentEventId);

        eventTicketToEventId[address(eventTicket)] = currentEventId;

        eventIdToEventEntry[currentEventId] = eventEntry;

        currentEventId += 1;

        emit EventCreated(msg.sender, currentEventId - 1, eventTicket, ticketSale, ticketMarketplace);
    }

    function getTicketSale(address eventTicket) external view returns (address ticketSale) {
        uint256 eventId = eventTicketToEventId[eventTicket];
        ticketSale = eventIdToEventEntry[eventId].ticketSale;
    }

    function getTicketMarketplace(address eventTicket) external view returns (address ticketMarketplace) {
        uint256 eventId = eventTicketToEventId[eventTicket];
        ticketMarketplace = eventIdToEventEntry[eventId].ticketMarketplace;
    }
}
