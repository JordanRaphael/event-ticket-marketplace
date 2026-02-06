// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IMarketplace} from "src/interfaces/IMarketplace.sol";
import {PostconditionsBase} from "test/invariant/postconditions/PostconditionsBase.sol";

abstract contract MarketplacePostconditions is PostconditionsBase {
    function afterCreateAsk() external view {
        _assertGlobalInvariants();
        _inv_order_type_ask();
        _inv_order_status_active();
        _inv_marketplace_balance_unchanged();
        _inv_ask_escrowed();
    }

    function afterCreateBid() external view {
        _assertGlobalInvariants();
        _inv_order_type_bid();
        _inv_order_status_active();
        _inv_marketplace_balance_increased();
    }

    function afterFillOrder() external view {
        _assertGlobalInvariants();
        _inv_order_status_filled();

        if (cache.lastOrderType() == IMarketplace.OrderType.ASK) {
            _inv_fill_ask_balance_unchanged();
            _inv_fill_ask_owner();
        } else {
            _inv_fill_bid_balance_decreased();
            _inv_fill_bid_owner();
        }
    }

    function afterCancelOrder() external view {
        _assertGlobalInvariants();
        _inv_order_status_cancelled();

        if (cache.lastOrderType() == IMarketplace.OrderType.ASK) {
            _inv_cancel_ask_balance_unchanged();
            _inv_cancel_ask_owner();
        } else {
            _inv_cancel_bid_balance_decreased();
        }
    }

    function afterUpdateOrder() external view {
        _assertGlobalInvariants();
        _inv_order_type_bid();
        _inv_order_status_active();
        _inv_update_balance_delta();
    }

    function _inv_order_type_ask() internal view {
        require(cache.lastOrderType() == IMarketplace.OrderType.ASK, "PostCreateAsk: wrong type");
    }

    function _inv_order_type_bid() internal view {
        require(cache.lastOrderType() == IMarketplace.OrderType.BID, "PostCreateBid: wrong type");
    }

    function _inv_order_status_active() internal view {
        require(
            cache.getOrder(cache.lastOrderId()).status == IMarketplace.OrderStatus.ACTIVE, "PostOrder: status mismatch"
        );
    }

    function _inv_order_status_filled() internal view {
        require(
            cache.getOrder(cache.lastOrderId()).status == IMarketplace.OrderStatus.FILLED, "PostFill: status mismatch"
        );
    }

    function _inv_order_status_cancelled() internal view {
        require(
            cache.getOrder(cache.lastOrderId()).status == IMarketplace.OrderStatus.CANCELLED,
            "PostCancel: status mismatch"
        );
    }

    function _inv_marketplace_balance_unchanged() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore(), "PostOrder: balance changed"
        );
    }

    function _inv_marketplace_balance_increased() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore() + cache.lastOrderPriceAfter(),
            "PostCreateBid: balance delta mismatch"
        );
    }

    function _inv_ask_escrowed() internal view {
        require(cache.cachedOwnerOf(cache.lastOrderTicketId()) == cache.marketplace(), "PostCreateAsk: not escrowed");
    }

    function _inv_fill_ask_balance_unchanged() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore(), "PostFill: ask balance changed"
        );
    }

    function _inv_fill_ask_owner() internal view {
        require(
            cache.cachedOwnerOf(cache.lastOrderTicketId()) == cache.lastOrderFiller(), "PostFill: ask owner mismatch"
        );
    }

    function _inv_fill_bid_balance_decreased() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore() - cache.lastOrderPriceBefore(),
            "PostFill: bid balance delta mismatch"
        );
    }

    function _inv_fill_bid_owner() internal view {
        require(
            cache.cachedOwnerOf(cache.lastOrderTicketId()) == cache.lastOrderCreator(), "PostFill: bid owner mismatch"
        );
    }

    function _inv_cancel_ask_balance_unchanged() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore(),
            "PostCancel: ask balance changed"
        );
    }

    function _inv_cancel_ask_owner() internal view {
        require(
            cache.cachedOwnerOf(cache.lastOrderTicketId()) == cache.lastOrderCreator(), "PostCancel: ask owner mismatch"
        );
    }

    function _inv_cancel_bid_balance_decreased() internal view {
        require(
            cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore() - cache.lastOrderPriceBefore(),
            "PostCancel: bid balance delta mismatch"
        );
    }

    function _inv_update_balance_delta() internal view {
        if (cache.lastOrderPriceAfter() > cache.lastOrderPriceBefore()) {
            uint256 delta = cache.lastOrderPriceAfter() - cache.lastOrderPriceBefore();
            require(
                cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore() + delta,
                "PostUpdate: increase delta mismatch"
            );
        } else if (cache.lastOrderPriceAfter() < cache.lastOrderPriceBefore()) {
            uint256 delta = cache.lastOrderPriceBefore() - cache.lastOrderPriceAfter();
            require(
                cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore() - delta,
                "PostUpdate: decrease delta mismatch"
            );
        } else {
            require(
                cache.lastMarketplaceBalanceAfter() == cache.lastMarketplaceBalanceBefore(),
                "PostUpdate: zero delta mismatch"
            );
        }
    }
}
