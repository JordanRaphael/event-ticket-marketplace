// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IMarketplace} from "src/interfaces/IMarketplace.sol";
import {Cache} from "../Cache.sol";
import {InvariantBase} from "./InvariantBase.sol";

abstract contract MarketplaceInvariants is InvariantBase {
    function _assertMarketplaceInvariants() internal view {
        _inv_escrow_matches_balance();
        _inv_flow_matches_balance();
        _inv_asks_escrowed();
        _inv_active_bid_sum_matches_escrow();
    }

    function _inv_escrow_matches_balance() internal view {
        require(cache.cachedMarketplaceWethBalance() == cache.activeBidEscrow(), "Marketplace: escrow balance mismatch");
    }

    function _inv_flow_matches_balance() internal view {
        require(
            cache.cachedMarketplaceWethBalance() == cache.totalWethIn() - cache.totalWethOut(),
            "Marketplace: in/out mismatch"
        );
    }

    function _inv_asks_escrowed() internal view {
        uint256 askCount = cache.activeAskTokenCount();
        address market = cache.marketplace();
        for (uint256 i = 0; i < askCount; i++) {
            uint256 tokenId = cache.activeAskTokenIdAt(i);
            require(cache.cachedOwnerOf(tokenId) == market, "Marketplace: ask not escrowed");
        }
    }

    function _inv_active_bid_sum_matches_escrow() internal view {
        uint256 bidCount = cache.activeBidOrderCount();
        uint256 sum;
        for (uint256 i = 0; i < bidCount; i++) {
            uint256 orderId = cache.activeBidOrderIdAt(i);
            Cache.GhostOrder memory order = cache.getOrder(orderId);
            if (uint8(order.status) == uint8(IMarketplace.OrderStatus.ACTIVE)) {
                sum += order.price;
            }
        }
        require(sum == cache.activeBidEscrow(), "Marketplace: active bid sum mismatch");
    }
}
