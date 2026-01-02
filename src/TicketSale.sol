// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.33;

import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

import { EventTicket } from "./EventTicket.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { ITicketSale } from "./interfaces/ITicketSale.sol";

contract TicketSale is ITicketSale, Initializable {

    EventTicket public ticket;

    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on Ethereum mainnet

    address public organizer;
    uint256 public saleStart;
    uint256 public saleEnd;
    uint256 public ticketPriceInWei;
    uint256 public ticketMaxSupply;
    uint256 public currentTicketId;

    event TicketsBought(address indexed buyer, uint256[] indexed ticketIds, uint256 ticketAmount, uint256 totalTicketCost);
    event TicketMaxSupplySet(uint256 newMaxSupply);
    event TicketPriceInWeiSet(uint256 ticketPriceInWei);
    event SaleEndSet(uint256 saleEnd);
    event SaleStartSet(uint256 saleStart);

    modifier onlyOrganizer() {
        _onlyOrganizer();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        TicketSaleInitParams memory initParams
    ) external initializer {
        ticket = EventTicket(initParams.eventTicket);
        organizer = initParams.organizer;
        saleStart = initParams.saleStart;
        saleEnd = initParams.saleEnd;
        ticketPriceInWei = initParams.ticketPriceInWei;
        ticketMaxSupply = initParams.ticketMaxSupply;
    }

    // new total supply must not be less than the already minted supply
    function setTicketMaxSupply(uint256 newMaxSupply) external onlyOrganizer() {
        require(newMaxSupply >= ticket.totalSupply(), "Max Supply can't be set lower than the ticket's total supply");
        ticketMaxSupply = newMaxSupply;
        emit TicketMaxSupplySet(ticketMaxSupply);
    }

    // no specific limits to the new price
    function setTicketPriceInWei(uint256 newTicketPriceInWei) external onlyOrganizer() {
        ticketPriceInWei = newTicketPriceInWei;
        emit TicketPriceInWeiSet(ticketPriceInWei);
    }

    // Sale must be live or not started yet.
    // New Sale end can't be less than sale start
    function setSaleEnd(uint256 newSaleEnd) external onlyOrganizer() {
        require(block.timestamp <= saleEnd, "Sale ended");
        require(saleStart < newSaleEnd, "New sale end must be after sale start");
        saleEnd = newSaleEnd;
        emit SaleEndSet(saleEnd);
    }

    // Sale must not be live yet.
    function setSaleStart(uint256 newSaleStart) external onlyOrganizer() {
        require(block.timestamp < saleStart, "Sale started");
        saleStart = newSaleStart;
        emit SaleStartSet(saleStart);
    }

    //@todo add feature for gasless transactions

    function buy(uint256 ticketAmount, uint256 priceLimitPerTicket) external payable returns (uint256[] memory ticketIds) {

        // validate inputs
        require(ticketAmount > 0, "At least 1 ticket");
        require(ticketMaxSupply - ticket.totalSupply() >= ticketAmount, "Not enough tickets left"); //@todo allow to buy remaining tickets if less are left
        require(block.timestamp >= saleStart, "Sale isn't live yet");
        require(block.timestamp <= saleEnd, "Sale ended");
        
        uint256 totalTicketCost = ticketAmount * ticketPriceInWei;
        require(totalTicketCost <= msg.value, "Not enough ether");
        require(totalTicketCost <= ticketAmount * priceLimitPerTicket, "Price limit exceeded");

        // mint tickets
        ticketIds = new uint256[](ticketAmount);

        for (uint256 i = 0; i < ticketAmount; i++) {
            //@todo consider ERC721A for gas saving when buying multiple tickets
            ticket.mint(msg.sender, currentTicketId);
            ticketIds[i] = currentTicketId;
            currentTicketId += 1;
        }
        
        // pay organizer / refund buyer //@todo consolidate all ether/erc20 transfers to helper util contract
        WETH.deposit{value: totalTicketCost}();
        require(WETH.transfer(organizer, totalTicketCost), "Transfer failed");

        emit TicketsBought(msg.sender, ticketIds, ticketAmount, totalTicketCost);

        if (msg.value > totalTicketCost) {
            (bool success, ) = msg.sender.call{value: msg.value - totalTicketCost}("");
            require(success, "ETH transfer failed");
        }
    }

    function _onlyOrganizer() internal view {
        require(msg.sender == organizer, "Callable only by the organizer");
    }

}