// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.33;

interface IEventTicket {

    struct EventTicketInitParams {
        string name;
        string symbol;
        string baseURI;
        address organizer;
        address ticketSale;
        address ticketMarketplace;
    }

    function initialize(EventTicketInitParams memory initParams) external;
}