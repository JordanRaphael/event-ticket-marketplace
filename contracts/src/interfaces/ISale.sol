// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ISale {
    struct SaleInitParams {
        address eventTicket;
        address organizer;
        uint256 saleStart;
        uint256 saleEnd;
        uint256 ticketPriceInWei;
        uint256 ticketMaxSupply;
    }

    function initialize(SaleInitParams memory initParams) external;

    event TicketsBought(
        address indexed buyer, uint256[] indexed ticketIds, uint256 ticketAmount, uint256 totalTicketCost
    );
    event TicketMaxSupplySet(uint256 newMaxSupply);
    event TicketPriceInWeiSet(uint256 ticketPriceInWei);
    event SaleEndSet(uint256 saleEnd);
    event SaleStartSet(uint256 saleStart);
}
