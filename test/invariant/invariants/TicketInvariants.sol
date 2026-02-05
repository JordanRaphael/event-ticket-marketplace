// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {InvariantBase} from "./InvariantBase.sol";

abstract contract TicketInvariants is InvariantBase {
    function _assertTicketInvariants() internal view {
        _inv_total_supply_matches_minted();
        _inv_next_id_matches_minted();
    }

    function _inv_total_supply_matches_minted() internal view {
        require(cache.cachedTicketTotalSupply() == cache.totalMinted(), "Ticket: total supply mismatch");
    }

    function _inv_next_id_matches_minted() internal view {
        require(cache.cachedNextTicketId() == cache.totalMinted(), "Ticket: next id mismatch");
    }
}
