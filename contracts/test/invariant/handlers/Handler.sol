// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {FactoryHandler} from "test/invariant/handlers/FactoryHandler.sol";
import {TicketHandler} from "test/invariant/handlers/TicketHandler.sol";
import {MarketplaceHandler} from "test/invariant/handlers/MarketplaceHandler.sol";
import {SaleHandler} from "test/invariant/handlers/SaleHandler.sol";
import {HandlerBase, Config} from "test/invariant/handlers/HandlerBase.sol";

contract Handler is TicketHandler, FactoryHandler, MarketplaceHandler, SaleHandler {
    constructor(Config memory config) HandlerBase(config) {}

    function advanceTime(uint256 secondsToAdvance) external {
        uint256 delta = bound(secondsToAdvance, 0, 14 days);
        vm.warp(block.timestamp + delta);

        postconditions.afterConfigChange();
    }
}
