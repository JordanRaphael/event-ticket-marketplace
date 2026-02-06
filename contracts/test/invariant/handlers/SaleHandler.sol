// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {HandlerBase} from "test/invariant/handlers/HandlerBase.sol";

abstract contract SaleHandler is HandlerBase {
    function buyTickets(uint256 buyerSeed, uint256 amount, uint256 priceLimit) external {
        address buyer = _trader(buyerSeed);
        uint256 boundedAmount = bound(amount, 1, 10);
        uint256 boundedPriceLimit = bound(priceLimit, 0, MAX_PRICE);

        (bool ok, uint256 actualAmount, uint256 totalCost) =
            preconditions.computeBuy(buyer, boundedAmount, boundedPriceLimit);
        if (!ok) return;

        uint256 totalSupplyBefore = ticket.totalSupply();
        address saleOrganizer = sale.eventOrganizer();
        uint256 organizerBalanceBefore = weth.balanceOf(saleOrganizer);

        vm.prank(buyer);
        uint256[] memory ticketIds = sale.buy(actualAmount, boundedPriceLimit);

        cache.recordMint(ticketIds.length);
        for (uint256 i = 0; i < ticketIds.length; i++) {
            cache.setOwner(ticketIds[i], buyer);
        }
        uint256 totalSupplyAfter = ticket.totalSupply();
        uint256 organizerBalanceAfter = weth.balanceOf(saleOrganizer);
        cache.setLastBuyContext(
            buyer,
            totalCost,
            organizerBalanceBefore,
            organizerBalanceAfter,
            totalSupplyBefore,
            totalSupplyAfter,
            ticketIds
        );

        _syncState();
        postconditions.afterBuy();
    }

    function setTicketMaxSupply(uint256 newMaxSupplySeed) external {
        uint256 currentSupply = ticket.totalSupply();
        uint256 newMaxSupply = bound(newMaxSupplySeed, currentSupply, currentSupply + 1000);

        vm.prank(organizer);
        sale.setTicketMaxSupply(newMaxSupply);

        _syncState();
        postconditions.afterConfigChange();
    }

    function setTicketPrice(uint256 newPriceSeed) external {
        uint256 newPrice = bound(newPriceSeed, 0, MAX_PRICE);
        vm.prank(organizer);
        sale.setTicketPriceWei(newPrice);

        _syncState();
        postconditions.afterConfigChange();
    }

    function setSaleEnd(uint256 newEndSeed) external {
        if (block.timestamp > sale.saleEnd()) return;

        uint256 newEnd = block.timestamp + bound(newEndSeed, 1 days, 30 days);
        if (sale.saleStart() >= newEnd) return;

        vm.prank(organizer);
        sale.setSaleEnd(newEnd);

        _syncState();
        postconditions.afterConfigChange();
    }

    function setSaleStart(uint256 newStartSeed) external {
        if (block.timestamp >= sale.saleStart()) return;

        uint256 newStart = bound(newStartSeed, 0, sale.saleEnd() - 1);
        vm.prank(organizer);
        sale.setSaleStart(newStart);

        _syncState();
        postconditions.afterConfigChange();
    }
}
