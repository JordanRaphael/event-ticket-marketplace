// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC2771Context} from "openzeppelin-contracts/contracts/metatx/ERC2771Context.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {Ticket} from "./Ticket.sol";
import {IMarketplace} from "./interfaces/IMarketplace.sol";

/// @notice Secondary marketplace for event tickets using WETH.
/// @dev Uses meta-tx context and holds assets in escrow while orders are active.
contract Marketplace is IMarketplace, Initializable, IERC721Receiver, ERC2771Context {
    using SafeERC20 for IERC20;
    using SafeCast for *;

    IERC20 private constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on Ethereum mainnet

    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant MIN_ORDER_DURATION = 5 minutes;

    Ticket public ticket;

    address public protocolFeeRecipient;
    address public eventOrganizer;
    uint256 public totalFeeBps; // total fee percentage in BPS_DENOMINATOR
    uint256 public organizerFeeBps; // eventOrganizer's percentage of the total fees in BPS_DENOMINATOR

    // address to order Ids
    mapping(address => uint256[]) orderIdsByCreator;

    // orderId to order
    mapping(uint256 => Order) ordersById;

    // current order id
    uint256 nextOrderId;

    /// @notice Disables initializers on the implementation contract.
    /// @dev Constructor runs only on the implementation used for clones.
    /// @param trustedForwarder_ ERC2771 trusted forwarder.
    constructor(address trustedForwarder_) ERC2771Context(trustedForwarder_) {
        _disableInitializers();
    }

    /// @notice Initializes the marketplace.
    /// @dev Can only be called once.
    /// @param initParams Initialization parameters for the marketplace.
    function initialize(MarketplaceInitParams memory initParams) external initializer {
        ticket = Ticket(initParams.eventTicket);
        eventOrganizer = initParams.organizer;
        totalFeeBps = initParams.totalFees;
        organizerFeeBps = initParams.organizerFee;
        protocolFeeRecipient = initParams.protocol;
    }

    //@audit add matchOrders function, executable only by the protocol (off-chain matching engine)

    /// @notice Creates a single order and escrows the asset.
    /// @param params Order creation parameters.
    function createOrder(CreateOrder memory params) external {
        address sender = _msgSender();
        if (params.orderType == OrderType.ASK) {
            ticket.safeTransferFrom(sender, address(this), params.eventTicketId);
        } else if (params.orderType == OrderType.BID) {
            WETH.safeTransferFrom(sender, address(this), params.price);
        } else {
            revert("Invalid orderType");
        }

        _createOrder(params);
    }

    /// @notice Creates multiple orders and escrows their assets.
    /// @param paramsList Array of order creation parameters.
    function createOrders(CreateOrder[] memory paramsList) external {
        address sender = _msgSender();
        for (uint256 i = 0; i < paramsList.length; i++) {
            if (paramsList[i].orderType == OrderType.ASK) {
                ticket.safeTransferFrom(sender, address(this), paramsList[i].eventTicketId);
            } else if (paramsList[i].orderType == OrderType.BID) {
                WETH.safeTransferFrom(sender, address(this), paramsList[i].price);
            } else {
                revert("Invalid orderType");
            }
        }

        for (uint256 i = 0; i < paramsList.length; i++) {
            _createOrder(paramsList[i]);
        }
    }

    function _createOrder(CreateOrder memory params) private {
        require(params.price >= BPS_DENOMINATOR, "Invalid price");
        require(params.deadline >= block.timestamp + MIN_ORDER_DURATION, "Invalid deadline");

        uint256 orderId = nextOrderId;

        address sender = _msgSender();
        Order memory order = Order({
            creator: sender,
            orderId: orderId,
            eventTicketId: params.eventTicketId,
            price: params.price,
            deadline: params.deadline,
            orderType: params.orderType,
            status: OrderStatus.ACTIVE
        });

        _updateOrderStorage(orderId, order, Action.CREATE_ORDER);

        emit OrderCreated(
            sender, params.eventTicketId, params.orderType, block.timestamp, params.price, params.deadline
        );
    }

    /// @notice Fills a single order.
    /// @param orderId Order id to fill.
    /// @param priceLimit Price limit used to protect against slippage.
    function fillOrder(uint256 orderId, uint256 priceLimit) external {
        _fillOrder(orderId, priceLimit);
    }

    /// @notice Fills multiple orders.
    /// @param orderIds Array of order ids to fill.
    /// @param priceLimits Array of price limits corresponding to each order.
    function fillOrders(uint256[] memory orderIds, uint256[] memory priceLimits) external {
        require(orderIds.length == priceLimits.length, "Input array length mismatch");

        for (uint256 i = 0; i < orderIds.length; i++) {
            _fillOrder(orderIds[i], priceLimits[i]);
        }
    }

    function _fillOrder(uint256 orderId, uint256 priceLimit) private {
        Order memory order = ordersById[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.deadline >= block.timestamp, "Order expired");

        if (order.orderType == OrderType.ASK) {
            // buyer must provide ether, and the price must not exceed the priceLimit
            require(priceLimit >= order.price, "Price limit exceeded");
        } else if (order.orderType == OrderType.BID) {
            // sell must provide the NFT, and the priceLimit must not exceed the price
            require(priceLimit <= order.price, "Price limit exceeded");
        } else {
            revert("Invalid orderType");
        }

        order.status = OrderStatus.FILLED;

        _updateOrderStorage(orderId, order, Action.FILL_ORDER);

        address sender = _msgSender();
        if (order.orderType == OrderType.ASK) {
            // transfer payment in
            WETH.safeTransferFrom(sender, address(this), order.price);
            // send payment to creator
            _handlePayments(order.price, order.creator);
            // send NFT to buyer
            ticket.safeTransferFrom(address(this), sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            // send payment to seller
            _handlePayments(order.price, sender);
            // send NFT to creator
            ticket.safeTransferFrom(sender, order.creator, order.eventTicketId);
        } else {
            revert("Invalid orderType");
        }

        emit OrderFilled(order.creator, sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    /// @notice Updates a single order's price or deadline.
    /// @dev Handles WETH deposits or refunds to match the new price.
    /// @param orderId Order id to update.
    /// @param updatedPrice Updated price for the order.
    /// @param updatedDeadline Updated deadline for the order.
    function updateOrder(uint256 orderId, uint256 updatedPrice, uint256 updatedDeadline) external payable {
        int256 price = _updateOrder(orderId, updatedPrice, updatedDeadline);
        if (price > 0) {
            WETH.safeTransferFrom(_msgSender(), address(this), price.toUint256());
        } else if (price < 0) {
            WETH.safeTransfer(_msgSender(), (-price).toUint256());
        }
    }

    /// @notice Updates multiple orders' prices or deadlines.
    /// @dev Handles a net WETH deposit or refund to match the new prices.
    /// @param orderIds Array of order ids to update.
    /// @param updatedPrices Array of updated prices corresponding to each order.
    /// @param updatedDeadlines Array of updated deadlines corresponding to each order.
    function updateOrders(uint256[] memory orderIds, uint256[] memory updatedPrices, uint256[] memory updatedDeadlines)
        external
    {
        require(
            orderIds.length == updatedPrices.length && orderIds.length == updatedDeadlines.length,
            "Input array length mismatch"
        );

        int256 price = 0;
        for (uint256 i = 0; i < orderIds.length; i++) {
            price += _updateOrder(orderIds[i], updatedPrices[i], updatedDeadlines[i]);
        }

        if (price > 0) {
            WETH.safeTransferFrom(_msgSender(), address(this), price.toUint256());
        } else if (price < 0) {
            WETH.safeTransfer(_msgSender(), (-price).toUint256());
        }
    }

    function _updateOrder(uint256 orderId, uint256 updatedPrice, uint256 updatedDeadline) private returns (int256) {
        require(updatedPrice >= BPS_DENOMINATOR, "Invalid price");
        require(updatedDeadline >= block.timestamp + MIN_ORDER_DURATION, "Invalid deadline");

        Order memory order = ordersById[orderId];
        require(order.creator == _msgSender(), "Sender not creator");
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.orderType == OrderType.BID || updatedPrice == 0, "Can't update price of ASK orders");

        uint256 oldPrice = order.price;

        order.price = updatedPrice;
        order.deadline = updatedDeadline;

        _updateOrderStorage(orderId, order, Action.UPDATE_ORDER);

        emit OrderUpdated(
            _msgSender(), order.eventTicketId, order.orderType, block.timestamp, order.price, order.deadline
        );

        return updatedPrice.toInt256() - oldPrice.toInt256();
    }

    /// @notice Cancels a single order and returns the escrowed asset.
    /// @param orderId Order id to cancel.
    function cancelOrder(uint256 orderId) external {
        _cancelOrder(orderId);
    }

    /// @notice Cancels multiple orders and returns their escrowed assets.
    /// @param orderIds Array of order ids to cancel.
    function cancelOrders(uint256[] memory orderIds) external {
        for (uint256 i = 0; i < orderIds.length; i++) {
            _cancelOrder(orderIds[i]);
        }
    }

    function _cancelOrder(uint256 orderId) private {
        Order memory order = ordersById[orderId];
        address sender = _msgSender();
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.creator == sender, "Sender not creator");

        order.status = OrderStatus.CANCELLED;

        _updateOrderStorage(orderId, order, Action.CANCEL_ORDER);

        if (order.orderType == OrderType.ASK) {
            ticket.safeTransferFrom(address(this), sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            WETH.safeTransfer(sender, order.price);
        } else {
            revert("Invalid orderType");
        }

        emit OrderCancelled(sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    /// @notice ERC721 receive hook for escrowed tickets.
    /// @return selector ERC721 receiver selector.
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _handlePayments(uint256 grossAmount, address seller) private {
        uint256 fees = grossAmount * totalFeeBps / BPS_DENOMINATOR;
        uint256 paymentToSeller = grossAmount - fees;
        uint256 paymentToOrganizer = fees * organizerFeeBps / BPS_DENOMINATOR;
        uint256 paymentToProtocol = fees - paymentToOrganizer;

        WETH.safeTransfer(seller, paymentToSeller);
        if (paymentToOrganizer > 0) WETH.safeTransfer(eventOrganizer, paymentToOrganizer);
        if (paymentToProtocol > 0) WETH.safeTransfer(protocolFeeRecipient, paymentToProtocol);
    }

    function _updateOrderStorage(uint256 orderId, Order memory order, Action action) private {
        if (action == Action.CREATE_ORDER) {
            orderIdsByCreator[_msgSender()].push(orderId);
            ordersById[orderId] = order;
            nextOrderId += 1;
        } else if (action == Action.FILL_ORDER || action == Action.UPDATE_ORDER || action == Action.CANCEL_ORDER) {
            ordersById[orderId] = order;
        } else {
            revert("Invalid action");
        }
    }
}
