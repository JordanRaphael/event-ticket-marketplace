// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PostconditionsBase} from "test/invariant/postConditions/PostconditionsBase.sol";

abstract contract SalePostconditions is PostconditionsBase {
    function afterBuy() external view {
        _assertGlobalInvariants();
        _inv_buy_supply_delta();
        _inv_buy_cached_supply_matches();
        _inv_buy_organizer_paid();
        _inv_buy_tickets_owned();
    }

    function _inv_buy_supply_delta() internal view {
        uint256 mintedCount = cache.lastTicketIdsLength();
        require(
            cache.lastTotalSupplyAfter() == cache.lastTotalSupplyBefore() + mintedCount,
            "PostBuy: supply delta mismatch"
        );
    }

    function _inv_buy_cached_supply_matches() internal view {
        require(cache.cachedTicketTotalSupply() == cache.lastTotalSupplyAfter(), "PostBuy: cached supply mismatch");
    }

    function _inv_buy_organizer_paid() internal view {
        require(
            cache.lastOrganizerBalanceAfter() == cache.lastOrganizerBalanceBefore() + cache.lastTotalCost(),
            "PostBuy: organizer payment mismatch"
        );
    }

    function _inv_buy_tickets_owned() internal view {
        address buyer = cache.lastBuyer();
        uint256 mintedCount = cache.lastTicketIdsLength();
        for (uint256 i = 0; i < mintedCount; i++) {
            uint256 tokenId = cache.lastTicketIdAt(i);
            require(cache.cachedOwnerOf(tokenId) == buyer, "PostBuy: ticket owner mismatch");
        }
    }
}
