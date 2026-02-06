// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {InvariantBase} from "./InvariantBase.sol";

abstract contract SaleInvariants is InvariantBase {
    function _assertSaleInvariants() internal view {
        _inv_supply_within_max();
        _inv_sale_window_valid();
    }

    function _inv_supply_within_max() internal view {
        require(cache.cachedTicketTotalSupply() <= cache.cachedTicketMaxSupply(), "Sale: supply exceeds max");
    }

    function _inv_sale_window_valid() internal view {
        require(cache.cachedSaleStart() < cache.cachedSaleEnd(), "Sale: invalid time window");
    }
}
