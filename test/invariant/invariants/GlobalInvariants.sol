// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {MarketplaceInvariants} from "./MarketplaceInvariants.sol";
import {TicketInvariants} from "./TicketInvariants.sol";
import {SaleInvariants} from "./SaleInvariants.sol";

abstract contract GlobalInvariants is MarketplaceInvariants, TicketInvariants, SaleInvariants {
    function _assertGlobalInvariants() internal view {
        _assertMarketplaceInvariants();
        _assertTicketInvariants();
        _assertSaleInvariants();
    }
}
