// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

interface ITicketMarketplace {
    struct TicketMarketplaceInitParams {
        address eventTicket;
        address organizer;
        address protocol;
        uint256 totalFees;
        uint256 organizerFee;
    }

    enum OrderStatus {
        NONE,
        ACTIVE,
        FILLED,
        CANCELLED
    }

    enum Action {
        CREATE_ORDER,
        FILL_ORDER,
        UPDATE_ORDER,
        CANCEL_ORDER
    }

    enum OrderType {
        ASK,
        BID
    }

    struct Order {
        address creator;
        uint256 orderId;
        uint256 eventTicketId;
        uint256 price;
        uint256 deadline;
        OrderType orderType;
        OrderStatus status;
    }

    function initialize(TicketMarketplaceInitParams memory initParams) external;

    event OrderCreated(
        address indexed creator,
        uint256 indexed eventTicketId,
        OrderType indexed orderType,
        uint256 timestamp,
        uint256 price,
        uint256 deadline
    );
    event OrderFilled(
        address indexed creator,
        address indexed filler,
        uint256 indexed eventTicketId,
        OrderType orderType,
        uint256 timestamp,
        uint256 price
    );
    event OrderUpdated(
        address indexed creator,
        uint256 indexed eventTicketId,
        OrderType indexed orderType,
        uint256 timestamp,
        uint256 newPrice,
        uint256 newDeadline
    );
    event OrderCancelled(
        address indexed creator,
        uint256 indexed eventTicketId,
        OrderType indexed orderType,
        uint256 timestamp,
        uint256 price
    );
}
