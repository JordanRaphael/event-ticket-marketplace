// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {HandlerBase} from "test/invariant/handlers/HandlerBase.sol";

abstract contract FactoryHandler is HandlerBase {
    function proposeUpgrade() external {
        vm.prank(protocolOwner);
        factory.proposeImplementationUpgrade(
            eventTicketImplUpgrade, ticketSaleImplUpgrade, ticketMarketplaceImplUpgrade
        );

        _syncState();
        postconditions.afterConfigChange();
    }

    function executeUpgrade() external {
        if (factory.implementationUpgradeTime() == 0) return;
        if (block.timestamp <= factory.implementationUpgradeTime()) return;

        vm.prank(protocolOwner);
        factory.executeImplementationUpgrade();

        _syncState();
        postconditions.afterConfigChange();
    }
}
