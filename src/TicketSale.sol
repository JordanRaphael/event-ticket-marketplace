// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC2771Context} from "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {EventTicket} from "./EventTicket.sol";
import {ITicketSale} from "./interfaces/ITicketSale.sol";

contract TicketSale is ITicketSale, Initializable, ERC2771Context {
    using SafeERC20 for IERC20;

    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on Ethereum mainnet

    EventTicket public ticket;

    address public organizer;
    uint256 public saleStart;
    uint256 public saleEnd;
    uint256 public ticketPriceInWei;
    uint256 public ticketMaxSupply;
    uint256 public currentTicketId;

    modifier onlyOrganizer() {
        _onlyOrganizer();
        _;
    }

    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {
        _disableInitializers();
    }

    function initialize(TicketSaleInitParams memory initParams) external initializer {
        ticket = EventTicket(initParams.eventTicket);
        organizer = initParams.organizer;
        saleStart = initParams.saleStart;
        saleEnd = initParams.saleEnd;
        ticketPriceInWei = initParams.ticketPriceInWei;
        ticketMaxSupply = initParams.ticketMaxSupply;
    }

    // new total supply must not be less than the already minted supply
    function setTicketMaxSupply(uint256 newMaxSupply) external onlyOrganizer {
        require(newMaxSupply >= ticket.totalSupply(), "Max Supply can't be set lower than the ticket's total supply");
        ticketMaxSupply = newMaxSupply;
        emit TicketMaxSupplySet(ticketMaxSupply);
    }

    // no specific limits to the new price
    function setTicketPriceInWei(uint256 newTicketPriceInWei) external onlyOrganizer {
        ticketPriceInWei = newTicketPriceInWei;
        emit TicketPriceInWeiSet(ticketPriceInWei);
    }

    // Sale must be live or not started yet.
    // New Sale end can't be less than sale start
    function setSaleEnd(uint256 newSaleEnd) external onlyOrganizer {
        require(block.timestamp <= saleEnd, "Sale ended");
        require(saleStart < newSaleEnd, "New sale end must be after sale start");
        saleEnd = newSaleEnd;
        emit SaleEndSet(saleEnd);
    }

    // Sale must not be live yet.
    function setSaleStart(uint256 newSaleStart) external onlyOrganizer {
        require(block.timestamp < saleStart, "Sale started");
        saleStart = newSaleStart;
        emit SaleStartSet(saleStart);
    }

    function buy(uint256 ticketAmount, uint256 priceLimitPerTicket)
        external
        returns (uint256[] memory ticketIds)
    {
        // validate inputs
        require(ticketAmount > 0, "At least 1 ticket");
        require(ticketMaxSupply - ticket.totalSupply() >= ticketAmount, "Not enough tickets left"); //@todo allow to buy remaining tickets if less are left
        require(block.timestamp >= saleStart, "Sale isn't live yet");
        require(block.timestamp <= saleEnd, "Sale ended");

        uint256 totalTicketCost = ticketAmount * ticketPriceInWei;
        require(totalTicketCost <= ticketAmount * priceLimitPerTicket, "Price limit exceeded");

        // mint tickets
        ticketIds = new uint256[](ticketAmount);

        address sender = _msgSender();
        for (uint256 i = 0; i < ticketAmount; i++) {
            //@todo consider ERC721A for gas saving when buying multiple tickets
            ticket.mint(sender, currentTicketId);
            ticketIds[i] = currentTicketId;
            currentTicketId += 1;
        }

        // pay organizer
        WETH.safeTransferFrom(sender, organizer, totalTicketCost);

        emit TicketsBought(sender, ticketIds, ticketAmount, totalTicketCost);
    }

    function _onlyOrganizer() internal view {
        require(_msgSender() == organizer, "Callable only by the organizer");
    }
}
