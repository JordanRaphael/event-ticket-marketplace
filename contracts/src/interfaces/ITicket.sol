// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ITicket {
    struct TicketInitParams {
        string name;
        string symbol;
        string baseURI;
        address organizer;
        address ticketSale;
        address ticketMarketplace;
    }

    function initialize(TicketInitParams memory initParams) external;

    event TicketRedeemed(address redeemer, uint256 ticketId);
}
