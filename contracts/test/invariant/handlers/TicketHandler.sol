// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {HandlerBase} from "test/invariant/handlers/HandlerBase.sol";

abstract contract TicketHandler is HandlerBase {
    function approveMarketplace(uint256 traderSeed) external {
        address trader = _trader(traderSeed);
        vm.prank(trader);
        ticket.setApprovalForAll(address(marketplace), true);

        _syncState();
        postconditions.afterConfigChange();
    }
}
