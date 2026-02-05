// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IMarketplace} from "src/interfaces/IMarketplace.sol";
import {Cache} from "test/invariant/Cache.sol";
import {PreconditionsBase} from "test/invariant/preconditions/PreconditionsBase.sol";

abstract contract MarketplacePreconditions is PreconditionsBase {
    uint256 internal constant FEE_BPS = 10_000;
    uint256 internal constant MINIMUM_LISTING_DURATION = 5 minutes;

    function canCreateAsk(address seller, uint256 tokenId, uint256 price, uint256 deadline)
        external
        view
        returns (bool)
    {
        if (price < FEE_BPS) return false;
        if (deadline < block.timestamp + MINIMUM_LISTING_DURATION) return false;
        if (!_ownsToken(seller, tokenId)) return false;
        if (!_isApproved(seller, tokenId)) return false;
        return true;
    }

    function canCreateBid(address bidder, uint256 price, uint256 deadline) external view returns (bool) {
        if (price < FEE_BPS) return false;
        if (deadline < block.timestamp + MINIMUM_LISTING_DURATION) return false;
        if (weth.balanceOf(bidder) < price) return false;
        if (weth.allowance(bidder, address(marketplace)) < price) return false;
        return true;
    }

    function canFillOrder(address filler, uint256 orderId, uint256 priceLimit) external view returns (bool) {
        Cache.GhostOrder memory order = cache.getOrder(orderId);
        if (order.status != IMarketplace.OrderStatus.ACTIVE) return false;
        if (order.deadline < block.timestamp) return false;
        if (order.orderType == IMarketplace.OrderType.ASK) {
            if (priceLimit < order.price) return false;
            if (weth.balanceOf(filler) < order.price) return false;
            if (weth.allowance(filler, address(marketplace)) < order.price) return false;
            return true;
        }
        if (order.orderType == IMarketplace.OrderType.BID) {
            if (priceLimit > order.price) return false;
            if (!_ownsToken(filler, order.eventTicketId)) return false;
            if (!_isApproved(filler, order.eventTicketId)) return false;
            return true;
        }
        return false;
    }

    function canCancelOrder(address caller, uint256 orderId) external view returns (bool) {
        Cache.GhostOrder memory order = cache.getOrder(orderId);
        if (order.status != IMarketplace.OrderStatus.ACTIVE) return false;
        return order.creator == caller;
    }

    function canUpdateOrder(address caller, uint256 orderId, uint256 newPrice, uint256 newDeadline)
        external
        view
        returns (bool)
    {
        if (newPrice < FEE_BPS) return false;
        if (newDeadline < block.timestamp + MINIMUM_LISTING_DURATION) return false;

        Cache.GhostOrder memory order = cache.getOrder(orderId);
        if (order.status != IMarketplace.OrderStatus.ACTIVE) return false;
        if (order.creator != caller) return false;
        if (order.orderType != IMarketplace.OrderType.BID) return false;

        if (newPrice > order.price) {
            uint256 delta = newPrice - order.price;
            if (weth.balanceOf(caller) < delta) return false;
            if (weth.allowance(caller, address(marketplace)) < delta) return false;
        }
        return true;
    }

    function _ownsToken(address owner, uint256 tokenId) internal view returns (bool) {
        try ticket.ownerOf(tokenId) returns (address actualOwner) {
            return actualOwner == owner;
        } catch {
            return false;
        }
    }

    function _isApproved(address owner, uint256 tokenId) internal view returns (bool) {
        if (ticket.getApproved(tokenId) == address(marketplace)) return true;
        return ticket.isApprovedForAll(owner, address(marketplace));
    }
}
