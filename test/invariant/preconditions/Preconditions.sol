// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Ticket} from "src/Ticket.sol";
import {Marketplace} from "src/Marketplace.sol";
import {Sale} from "src/Sale.sol";
import {Cache} from "test/invariant/Cache.sol";
import {MarketplacePreconditions} from "test/invariant/preconditions/MarketplacePreconditions.sol";
import {PreconditionsBase} from "test/invariant/preconditions/PreconditionsBase.sol";
import {SalePreconditions} from "test/invariant/preconditions/SalePreconditions.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Preconditions is MarketplacePreconditions, SalePreconditions {
    constructor(Ticket ticket_, Marketplace marketplace_, Sale sale_, IERC20 weth_, Cache cache_)
        PreconditionsBase(ticket_, marketplace_, sale_, weth_, cache_)
    {}
}
