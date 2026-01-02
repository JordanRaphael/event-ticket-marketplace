// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.33;

interface ITicketSale {

    struct TicketSaleInitParams {
        address eventTicket;
        address organizer;
        uint256 saleStart;
        uint256 saleEnd;
        uint256 ticketPriceInWei;
        uint256 ticketMaxSupply;
    }

    function initialize(TicketSaleInitParams memory initParams) external;
}