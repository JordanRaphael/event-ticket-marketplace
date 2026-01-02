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
}