// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IWETH} from "../interfaces/IWETH.sol";

library TransferUtils {
    function _sendWeth(address weth, address to, uint256 _value) internal {
        IWETH(weth).deposit{value: _value}();
        require(IWETH(weth).transfer(to, _value), "Transfer failed");
    }
}
