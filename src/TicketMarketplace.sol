// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

import {EventTicket} from "./EventTicket.sol";
import {TransferUtils} from "./utils/TransferUtils.sol";
import {ITicketMarketplace} from "./interfaces/ITicketMarketplace.sol";

contract TicketMarketplace is ITicketMarketplace, Initializable, IERC721Receiver {
    using TransferUtils for address;
    using SafeCast for *;

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH on Ethereum mainnet

    uint256 private constant FEE_BPS = 10_000;
    uint256 private constant MINIMUM_LISTING_DURATION = 5 minutes;

    EventTicket public ticket;

    address public protocol;
    address public organizer;
    uint256 public totalFees; // total fee percentage in FEE_BPS
    uint256 public organizerFee; // organizer's percentage of the total fees in FEE_BPS

    // address to order Ids
    mapping(address => uint256[]) addressToOrderIds;

    // orderId to order
    mapping(uint256 => Order) orderIdToOrder;

    // current order id
    uint256 currentOrderId;

    constructor() {
        _disableInitializers();
    }

    function initialize(TicketMarketplaceInitParams memory initParams) external initializer {
        ticket = EventTicket(initParams.eventTicket);
        organizer = initParams.organizer;
        totalFees = initParams.totalFees;
        organizerFee = initParams.organizerFee;
        protocol = initParams.protocol;
    }

    function createOrder(Order memory orderParams) external payable {
        if (orderParams.orderType == OrderType.ASK) {
            require(msg.value == 0, "Msg value should be zero");
            ticket.safeTransferFrom(msg.sender, address(this), orderParams.eventTicketId);
        } else if (orderParams.orderType == OrderType.BID) {
            require(msg.value == orderParams.price, "Msg value should match price");
        } else {
            revert("Invalid orderType");
        }

        _createOrder(orderParams);
    }

    function createOrders(Order[] memory orderParams) external payable {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < orderParams.length; i++) {
            if (orderParams[i].orderType == OrderType.ASK) {
                require(msg.value == 0, "Msg value should be zero");
                ticket.safeTransferFrom(msg.sender, address(this), orderParams[i].eventTicketId);
            } else if (orderParams[i].orderType == OrderType.BID) {
                totalValue += orderParams[i].price;
            } else {
                revert("Invalid orderType");
            }
        }

        require(msg.value == totalValue, "Msg value should match total bid prices");

        for (uint256 i = 0; i < orderParams.length; i++) {
            _createOrder(orderParams[i]);
        }
    }

    function _createOrder(Order memory orderParams) private {
        require(orderParams.price >= FEE_BPS, "Invalid price");
        require(orderParams.deadline >= block.timestamp + MINIMUM_LISTING_DURATION, "Invalid deadline");

        uint256 orderId = currentOrderId;

        Order memory order = Order({
            creator: msg.sender,
            orderId: orderId,
            eventTicketId: orderParams.eventTicketId,
            price: orderParams.price,
            deadline: orderParams.deadline,
            orderType: orderParams.orderType,
            status: OrderStatus.ACTIVE
        });

        _updateOrderStorage(orderId, order, Action.CREATE_ORDER);

        emit OrderCreated(
            msg.sender,
            orderParams.eventTicketId,
            orderParams.orderType,
            block.timestamp,
            orderParams.price,
            orderParams.deadline
        );
    }

    function fillOrder(uint256 orderId, uint256 priceLimit) external payable {
        uint256 price = _fillOrder(orderId, priceLimit);
        require(msg.value >= price, "Msg.value not greater or equal to order price");

        if (msg.value - price > 0) {
            WETH._sendWeth(msg.sender, msg.value - price);
        }
    }

    function fillOrders(uint256[] memory orderIds, uint256[] memory priceLimits) external payable {
        require(orderIds.length == priceLimits.length, "Input array length mismatch");

        uint256 price = 0;
        for (uint256 i = 0; i < orderIds.length; i++) {
            price += _fillOrder(orderIds[i], priceLimits[i]);
            require(msg.value >= price, "Msg.value not greater or equal to order price");
        }

        if (msg.value - price > 0) {
            WETH._sendWeth(msg.sender, msg.value - price);
        }
    }

    function _fillOrder(uint256 orderId, uint256 priceLimit) private returns (uint256 price) {
        Order memory order = orderIdToOrder[orderId];
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

        if (order.orderType == OrderType.ASK) {
            // send payment to creator
            _handlePayments(order.price, order.creator);
            price = 0; // msg.sender sells his NFT
            // send NFT to buyer
            ticket.safeTransferFrom(address(this), msg.sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            // send payment to seller
            _handlePayments(order.price, msg.sender);
            price = order.price;
            // send NFT to creator
            ticket.safeTransferFrom(msg.sender, order.creator, order.eventTicketId);
        } else {
            revert("Invalid orderType");
        }

        emit OrderFilled(order.creator, msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    function updateOrder(uint256 orderId, uint256 newPrice, uint256 newDeadline) external payable {
        int256 price = _updateOrder(orderId, newPrice, newDeadline);
        if (price > 0) {
            require(msg.value == price.toUint256(), "Msg value must be equal to price change");
        } else if (price < 0) {
            WETH._sendWeth(msg.sender, (-price).toUint256());
        }
    }

    function updateOrders(uint256[] memory orderIds, uint256[] memory newPrices, uint256[] memory newDeadlines)
        external
        payable
    {
        require(
            orderIds.length == newPrices.length && orderIds.length == newDeadlines.length, "Input array length mismatch"
        );

        int256 price = 0;
        for (uint256 i = 0; i < orderIds.length; i++) {
            price += _updateOrder(orderIds[i], newPrices[i], newDeadlines[i]);
        }

        if (price > 0) {
            require(msg.value == price.toUint256(), "Msg value must be equal to price change");
        } else if (price < 0) {
            WETH._sendWeth(msg.sender, (-price).toUint256());
        }
    }

    function _updateOrder(uint256 orderId, uint256 newPrice, uint256 newDeadline) private returns (int256) {
        require(newPrice >= FEE_BPS, "Invalid price");
        require(newDeadline >= block.timestamp + MINIMUM_LISTING_DURATION, "Invalid deadline");

        Order memory order = orderIdToOrder[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.orderType == OrderType.BID || newPrice == 0, "Can't increase price of ASK orders");

        uint256 oldPrice = order.price;

        order.price = newPrice;
        order.deadline = newDeadline;

        _updateOrderStorage(orderId, order, Action.UPDATE_ORDER);

        emit OrderUpdated(
            msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price, order.deadline
        );

        return newPrice.toInt256() - oldPrice.toInt256();
    }

    function cancelOrder(uint256 orderId) external {
        _cancelOrder(orderId);
    }

    function cancelOrders(uint256[] memory orderIds) external {
        for (uint256 i = 0; i < orderIds.length; i++) {
            _cancelOrder(orderIds[i]);
        }
    }

    function _cancelOrder(uint256 orderId) private {
        Order memory order = orderIdToOrder[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.creator == msg.sender, "Sender not creator");

        order.status = OrderStatus.CANCELLED;

        _updateOrderStorage(orderId, order, Action.CANCEL_ORDER);

        if (order.orderType == OrderType.ASK) {
            ticket.safeTransferFrom(address(this), msg.sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            WETH._sendWeth(msg.sender, order.price);
        } else {
            revert("Invalid orderType");
        }

        emit OrderCancelled(msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _handlePayments(uint256 totalPayment, address seller) private {
        uint256 fees = totalPayment * totalFees / FEE_BPS;
        uint256 paymentToSeller = totalPayment - fees;
        uint256 paymentToOrganizer = fees * organizerFee / FEE_BPS;
        uint256 paymentToProtocol = fees - paymentToOrganizer;

        WETH._sendWeth(seller, paymentToSeller);
        if (paymentToOrganizer > 0) WETH._sendWeth(organizer, paymentToOrganizer);
        if (paymentToProtocol > 0) WETH._sendWeth(protocol, paymentToProtocol);
    }

    function _updateOrderStorage(uint256 orderId, Order memory order, Action action) private {
        if (action == Action.CREATE_ORDER) {
            addressToOrderIds[msg.sender].push(orderId);
            orderIdToOrder[orderId] = order;
            currentOrderId += 1;
        } else if (action == Action.FILL_ORDER) {
            orderIdToOrder[orderId] = order;
        } else if (action == Action.UPDATE_ORDER) {
            orderIdToOrder[orderId] = order;
        } else if (action == Action.CANCEL_ORDER) {
            orderIdToOrder[orderId] = order;
        } else {
            revert("Invalid action");
        }
    }
}
