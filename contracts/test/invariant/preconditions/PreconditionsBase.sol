// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ticket} from "src/Ticket.sol";
import {Marketplace} from "src/Marketplace.sol";
import {Sale} from "src/Sale.sol";
import {Cache} from "test/invariant/Cache.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

abstract contract PreconditionsBase {
    Ticket public ticket;
    Marketplace public marketplace;
    Sale public sale;
    IERC20 public weth;
    Cache public cache;

    constructor(Ticket ticket_, Marketplace marketplace_, Sale sale_, IERC20 weth_, Cache cache_) {
        ticket = ticket_;
        marketplace = marketplace_;
        sale = sale_;
        weth = weth_;
        cache = cache_;
    }
}
