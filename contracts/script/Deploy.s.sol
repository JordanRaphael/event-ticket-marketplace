// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Script, console2} from "forge-std/Script.sol";

import {Factory} from "../src/Factory.sol";
import {Marketplace} from "../src/Marketplace.sol";
import {Sale} from "../src/Sale.sol";
import {Ticket} from "../src/Ticket.sol";

contract Deploy is Script {
    function run() external {
        address factoryOwner = vm.envAddress("FACTORY_OWNER");
        address trustedForwarder = vm.envAddress("TRUSTED_FORWARDER");
        address weth = vm.envAddress("WETH");

        vm.startBroadcast();

        Ticket ticketImpl = new Ticket(trustedForwarder);
        Sale saleImpl = new Sale(trustedForwarder, weth);
        Marketplace marketplaceImpl = new Marketplace(trustedForwarder, weth);
        Factory factory = new Factory(factoryOwner, address(ticketImpl), address(saleImpl), address(marketplaceImpl));

        vm.stopBroadcast();

        console2.log("Ticket implementation", address(ticketImpl));
        console2.log("Sale implementation", address(saleImpl));
        console2.log("Marketplace implementation", address(marketplaceImpl));
        console2.log("Factory", address(factory));
    }
}
