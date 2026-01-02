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
}