// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Cache} from "test/invariant/Cache.sol";
import {GlobalPostconditions} from "test/invariant/postconditions/GlobalPostconditions.sol";
import {MarketplacePostconditions} from "test/invariant/postconditions/MarketplacePostconditions.sol";
import {PostconditionsBase} from "test/invariant/postconditions/PostconditionsBase.sol";
import {SalePostconditions} from "test/invariant/postconditions/SalePostconditions.sol";

contract Postconditions is MarketplacePostconditions, SalePostconditions, GlobalPostconditions {
    constructor(Cache cache_) PostconditionsBase(cache_) {}
}
