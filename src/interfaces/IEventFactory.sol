// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface IEventFactory {
    struct EventEntry {
        uint256 id;
        address organizer;
        address eventTicket;
        address ticketSale;
        address ticketMarketplace;
    }

    event ImplementationsProposed(
        address eventTicket, address ticketSale, address ticketMarketplace, uint256 timestamp
    );
    event ImplementationsUpgraded(
        address eventTicket, address ticketSale, address ticketMarketplace, uint256 timestamp
    );
    event EventCreated(
        address indexed organizer,
        uint256 indexed id,
        address eventTicket,
        address ticketSale,
        address ticketMarketplace
    );
}
