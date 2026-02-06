// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {PreconditionsBase} from "test/invariant/preconditions/PreconditionsBase.sol";

abstract contract SalePreconditions is PreconditionsBase {
    function computeBuy(address buyer, uint256 requestedAmount, uint256 priceLimitPerTicket)
        external
        view
        returns (bool ok, uint256 actualAmount, uint256 totalCost)
    {
        if (requestedAmount == 0) return (false, 0, 0);
        if (block.timestamp < sale.saleStart()) return (false, 0, 0);
        if (block.timestamp > sale.saleEnd()) return (false, 0, 0);

        uint256 remaining = sale.ticketMaxSupply() - ticket.totalSupply();
        if (remaining == 0) return (false, 0, 0);

        actualAmount = requestedAmount;

        uint256 ticketPrice = sale.ticketPriceWei();
        if (priceLimitPerTicket < ticketPrice) return (false, 0, 0);

        totalCost = actualAmount * ticketPrice;
        if (actualAmount > remaining) totalCost = remaining * ticketPrice;
        if (weth.balanceOf(buyer) < totalCost) return (false, 0, 0);
        if (weth.allowance(buyer, address(sale)) < totalCost) return (false, 0, 0);

        return (true, actualAmount, totalCost);
    }
}
