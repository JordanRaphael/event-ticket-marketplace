// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.33;

import { Initializable } from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { IERC721Receiver } from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

import { EventTicket } from "./EventTicket.sol";
import { IWETH } from "./interfaces/IWETH.sol";
import { ITicketMarketplace } from "./interfaces/ITicketMarketplace.sol";

contract TicketMarketplace is ITicketMarketplace, Initializable, IERC721Receiver {

    EventTicket public ticket;

    IWETH constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH on Ethereum mainnet
    uint256 constant FEE_BPS = 10_000;
    uint256 constant MINIMUM_LISTING_DURATION = 5 minutes;

    address public protocol;
    address public organizer;
    uint256 public totalFees; // total fee percentage in FEE_BPS
    uint256 public organizerFee; // organizer's percentage of the total fees in FEE_BPS

    // address to order Ids
    mapping (address => uint256[]) addressToOrderIds;

    // orderId to order
    mapping (uint256 => Order) orderIdToOrder;

    // current order id
    uint256 currentOrderId;
    
    event OrderCreated(address indexed creator, uint256 indexed eventTicketId, OrderType indexed orderType, uint256 timestamp, uint256 price, uint256 deadline);
    event OrderFilled(address indexed creator, address indexed filler, uint256 indexed eventTicketId, OrderType orderType, uint256 timestamp, uint256 price);
    event OrderUpdated(address indexed creator, uint256 indexed eventTicketId, OrderType indexed orderType, uint256 timestamp, uint256 newPrice, uint256 newDeadline);
    event OrderCancelled(address indexed creator, uint256 indexed eventTicketId, OrderType indexed orderType, uint256 timestamp, uint256 price);

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

    //@todo create helper function to create/fill/update/cancel multiple orders in one txn

    function createOrder(Order memory orderParams) external payable {
        require(orderParams.price >= FEE_BPS, "Invalid price");
        require(orderParams.deadline >= block.timestamp + MINIMUM_LISTING_DURATION, "Invalid deadline");

        if (orderParams.orderType == OrderType.ASK) {
            require(msg.value == 0, "Msg value should be zero");
            ticket.safeTransferFrom(msg.sender, address(this), orderParams.eventTicketId);
        } else if (orderParams.orderType == OrderType.BID) {
            require(msg.value == orderParams.price, "Msg value should match price");
        } else {
            revert("Invalid orderType"); // should be dead code
        }

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

        emit OrderCreated(msg.sender, orderParams.eventTicketId, orderParams.orderType, block.timestamp, orderParams.price, orderParams.deadline);
    }

    function fillOrder(uint256 orderId, uint256 priceLimit) external payable {
        Order memory order = orderIdToOrder[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.deadline >= block.timestamp, "Order expired");

        if (order.orderType == OrderType.ASK) {
            // buyer must provide ether, and the price must not exceed the priceLimit
            require(msg.value == order.price, "Msg.value not equal to order price");
            require(priceLimit >= order.price, "Price limit exceeded");
        } else if (order.orderType == OrderType.BID) {
            // sell must provide the NFT, and the priceLimit must not exceed the price
            require(msg.value == 0, "Msg.value should be zero");
            require(priceLimit <= order.price, "Price limit exceeded");
        } else {
            revert("Invalid orderType"); // should be dead code
        }

        order.status = OrderStatus.FILLED;

        _updateOrderStorage(orderId, order, Action.FILL_ORDER);

        if (order.orderType == OrderType.ASK) {
            // send payment to creator
            _handlePayments(order.price, order.creator);
            // send NFT to buyer
            ticket.safeTransferFrom(address(this), msg.sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            // send payment to seller
            _handlePayments(order.price, msg.sender);
            // send NFT to creator
            ticket.safeTransferFrom(msg.sender, order.creator, order.eventTicketId);
        } else {
            revert("Invalid orderType"); // should be dead code
        }

        emit OrderFilled(order.creator, msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    function updateOrder(uint256 orderId, uint256 newPrice, uint256 newDeadline) external payable {
        require(newPrice >= FEE_BPS, "Invalid price");
        require(newDeadline >= block.timestamp + MINIMUM_LISTING_DURATION, "Invalid deadline");

        Order memory order = orderIdToOrder[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");

        uint256 oldPrice = order.price;

        order.price = newPrice;
        order.deadline = newDeadline;

        _updateOrderStorage(orderId, order, Action.UPDATE_ORDER);

        if (order.orderType == OrderType.ASK) {
            require(msg.value == 0, "Msg value should be zero");
        } else if (order.orderType == OrderType.BID) {
            if (newPrice > oldPrice) {
                // user increased bid
                require(msg.value == newPrice - oldPrice, "Msg.value not equal to updated price difference");
            } else if (newPrice < oldPrice) {
                // user decreased bid
                _sendWeth(msg.sender, oldPrice - newPrice);
            }
        } else {
            revert("Invalid orderType"); // should be dead code
        }

        emit OrderUpdated(msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price, order.deadline);
    }

    function cancelOrder(uint256 orderId) external {
        Order memory order = orderIdToOrder[orderId];
        require(order.status == OrderStatus.ACTIVE, "Order not active");
        require(order.creator == msg.sender, "Sender not creator");

        order.status = OrderStatus.CANCELLED;

        _updateOrderStorage(orderId, order, Action.CANCEL_ORDER);

        if (order.orderType == OrderType.ASK) {
            ticket.safeTransferFrom(address(this), msg.sender, order.eventTicketId);
        } else if (order.orderType == OrderType.BID) {
            _sendWeth(msg.sender, order.price);
        } else {
            revert("Invalid orderType"); // should be dead code
        }

        emit OrderCancelled(msg.sender, order.eventTicketId, order.orderType, block.timestamp, order.price);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata 
    ) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function _handlePayments(uint256 totalPayment, address seller) private {
        uint256 fees = totalPayment * totalFees / FEE_BPS;
        uint256 paymentToSeller = totalPayment - fees;
        uint256 paymentToOrganizer = fees * organizerFee / FEE_BPS;
        uint256 paymentToProtocol = fees - paymentToOrganizer;

        _sendWeth(seller, paymentToSeller);
        if (paymentToOrganizer > 0) _sendWeth(organizer, paymentToOrganizer);
        if (paymentToProtocol > 0) _sendWeth(protocol, paymentToProtocol);
    }

    function _sendWeth(address to, uint256 _value) private { //@todo consolidate all ether/erc20 transfers to helper util contract
        WETH.deposit{value: _value}();
        require(WETH.transfer(to, _value), "Transfer failed");
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
            revert("Invalid action"); // should be dead code
        }
    }

}