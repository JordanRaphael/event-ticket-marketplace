// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PostconditionsBase} from "test/invariant/postconditions/PostconditionsBase.sol";

abstract contract GlobalPostconditions is PostconditionsBase {
    function afterConfigChange() external view {
        _assertGlobalInvariants();
    }
}
