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

    struct CreateTicketSaleParams {
        string name;
        string symbol;
        string baseURI;
        address organizer;
        uint256 priceInWei;
        uint256 maxSupply;
        uint256 saleStart;
        uint256 saleEnd;
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
