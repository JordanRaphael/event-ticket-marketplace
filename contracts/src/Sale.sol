// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {ERC2771Context} from "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Ticket} from "./Ticket.sol";
import {ISale} from "./interfaces/ISale.sol";

/// @notice Primary sale contract for event tickets.
/// @dev Handles minting and payment collection in WETH.
contract Sale is ISale, Initializable, ERC2771Context {
    using SafeERC20 for IERC20;

    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on Ethereum mainnet

    Ticket public ticket;

    address public eventOrganizer;
    uint256 public saleStart;
    uint256 public saleEnd;
    uint256 public ticketPriceWei;
    uint256 public ticketMaxSupply;
    uint256 public nextTicketId;

    modifier onlyOrganizer() {
        _onlyOrganizer();
        _;
    }

    /// @notice Disables initializers on the implementation contract.
    /// @dev Constructor runs only on the implementation used for clones.
    /// @param trustedForwarder_ ERC2771 trusted forwarder.
    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {
        _disableInitializers();
    }

    /// @notice Initializes the ticket sale.
    /// @dev Can only be called once.
    /// @param initParams Initialization parameters for the ticket sale.
    function initialize(SaleInitParams memory initParams) external initializer {
        ticket = Ticket(initParams.eventTicket);
        eventOrganizer = initParams.organizer;
        saleStart = initParams.saleStart;
        saleEnd = initParams.saleEnd;
        ticketPriceWei = initParams.ticketPriceInWei;
        ticketMaxSupply = initParams.ticketMaxSupply;
    }

    /// @notice Updates the max supply of tickets for the sale.
    /// @dev Updated max supply must be >= already minted supply.
    /// @param updatedMaxSupply Updated max supply value.
    function setTicketMaxSupply(uint256 updatedMaxSupply) external onlyOrganizer {
        require(
            updatedMaxSupply >= ticket.totalSupply(), "Max Supply can't be set lower than the ticket's total supply"
        );
        ticketMaxSupply = updatedMaxSupply;
        emit TicketMaxSupplySet(ticketMaxSupply);
    }

    /// @notice Updates the ticket price in wei.
    /// @param updatedTicketPriceWei Updated ticket price in wei.
    function setTicketPriceWei(uint256 updatedTicketPriceWei) external onlyOrganizer {
        ticketPriceWei = updatedTicketPriceWei;
        emit TicketPriceInWeiSet(ticketPriceWei);
    }

    /// @notice Updates the sale end timestamp.
    /// @dev Sale must be active or not yet started, and updated end must be after start.
    /// @param updatedSaleEnd Updated sale end timestamp.
    function setSaleEnd(uint256 updatedSaleEnd) external onlyOrganizer {
        require(block.timestamp <= saleEnd, "Sale ended");
        require(saleStart < updatedSaleEnd, "Updated sale end must be after sale start");
        saleEnd = updatedSaleEnd;
        emit SaleEndSet(saleEnd);
    }

    /// @notice Updates the sale start timestamp.
    /// @dev Sale must not have started yet.
    /// @param updatedSaleStart Updated sale start timestamp.
    function setSaleStart(uint256 updatedSaleStart) external onlyOrganizer {
        require(block.timestamp < saleStart, "Sale started");
        require(updatedSaleStart < saleEnd, "Updated sale start must be before sale end");
        saleStart = updatedSaleStart;
        emit SaleStartSet(saleStart);
    }

    /// @notice Buys tickets from the primary sale.
    /// @dev Mints tickets to the buyer and transfers WETH to the eventOrganizer.
    /// @param ticketAmount Desired number of tickets to buy.
    /// @param priceLimitPerTicket Max price per ticket to protect against slippage.
    /// @return ticketIds Array of minted ticket ids.
    function buy(uint256 ticketAmount, uint256 priceLimitPerTicket) external returns (uint256[] memory ticketIds) {
        // validate inputs
        require(ticketAmount > 0, "At least 1 ticket");
        require(ticketMaxSupply - ticket.totalSupply() > 0, "Tickets sold out");
        require(block.timestamp >= saleStart, "Sale isn't live yet");
        require(block.timestamp <= saleEnd, "Sale ended");

        if (ticketMaxSupply - ticket.totalSupply() < ticketAmount) {
            ticketAmount = ticketMaxSupply - ticket.totalSupply();
        }

        uint256 totalTicketCost = ticketAmount * ticketPriceWei;
        require(totalTicketCost <= ticketAmount * priceLimitPerTicket, "Price limit exceeded");

        // mint tickets
        ticketIds = new uint256[](ticketAmount);

        address sender = _msgSender();
        for (uint256 i = 0; i < ticketAmount; i++) {
            //@todo consider ERC721A for gas saving when buying multiple tickets
            ticket.mint(sender, nextTicketId);
            ticketIds[i] = nextTicketId;
            nextTicketId += 1;
        }

        // pay eventOrganizer
        WETH.safeTransferFrom(sender, eventOrganizer, totalTicketCost);

        emit TicketsBought(sender, ticketIds, ticketAmount, totalTicketCost);
    }

    function _onlyOrganizer() internal view {
        require(_msgSender() == eventOrganizer, "Callable only by the eventOrganizer");
    }
}
