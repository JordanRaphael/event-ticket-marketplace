// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Cache} from "test/invariant/Cache.sol";
import {GlobalInvariants} from "test/invariant/invariants/GlobalInvariants.sol";

abstract contract PostconditionsBase is GlobalInvariants {
    constructor(Cache cache_) {
        _setCache(cache_);
    }
}
