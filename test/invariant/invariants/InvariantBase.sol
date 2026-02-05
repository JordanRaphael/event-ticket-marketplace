// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {Cache} from "../Cache.sol";

abstract contract InvariantBase is Test {
    Cache public cache;

    function _setCache(Cache cache_) internal {
        cache = cache_;
    }
}
