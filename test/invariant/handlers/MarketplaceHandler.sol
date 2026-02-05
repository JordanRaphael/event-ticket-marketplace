// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IMarketplace} from "src/interfaces/IMarketplace.sol";

import {Cache} from "test/invariant/Cache.sol";
import {HandlerBase} from "test/invariant/handlers/HandlerBase.sol";

abstract contract MarketplaceHandler is HandlerBase {
    function createAsk(uint256 sellerSeed, uint256 tokenSeed, uint256 priceSeed, uint256 deadlineSeed) external {
        uint256 minted = sale.nextTicketId();
        if (minted == 0) return;

        address seller = _trader(sellerSeed);
        uint256 tokenId = bound(tokenSeed, 0, minted - 1);
        uint256 price = bound(priceSeed, FEE_BPS, MAX_PRICE);
        uint256 deadline = block.timestamp + MINIMUM_LISTING_DURATION + bound(deadlineSeed, 0, 30 days);

        if (!preconditions.canCreateAsk(seller, tokenId, price, deadline)) return;

        uint256 balanceBefore = weth.balanceOf(address(marketplace));

        vm.prank(seller);
        marketplace.createOrder(
            IMarketplace.CreateOrder({
                eventTicketId: tokenId, price: price, deadline: deadline, orderType: IMarketplace.OrderType.ASK
            })
        );

        Cache.GhostOrder memory order = Cache.GhostOrder({
            creator: seller,
            eventTicketId: tokenId,
            price: price,
            deadline: deadline,
            orderType: IMarketplace.OrderType.ASK,
            status: IMarketplace.OrderStatus.ACTIVE
        });
        uint256 orderId = cache.recordOrderCreate(order);
        cache.setOwner(tokenId, address(marketplace));

        uint256 balanceAfter = weth.balanceOf(address(marketplace));
        cache.setLastMarketplaceBalances(balanceBefore, balanceAfter);
        cache.setLastOrderContext(orderId, seller, address(0), tokenId, IMarketplace.OrderType.ASK, price, price);

        _syncState();
        postconditions.afterCreateAsk();
    }

    function createBid(uint256 buyerSeed, uint256 tokenSeed, uint256 priceSeed, uint256 deadlineSeed) external {
        uint256 minted = sale.nextTicketId();
        if (minted == 0) return;

        address buyer = _trader(buyerSeed);
        uint256 tokenId = bound(tokenSeed, 0, minted - 1);
        uint256 price = bound(priceSeed, FEE_BPS, MAX_PRICE);
        uint256 deadline = block.timestamp + MINIMUM_LISTING_DURATION + bound(deadlineSeed, 0, 30 days);

        if (!preconditions.canCreateBid(buyer, price, deadline)) return;

        uint256 balanceBefore = weth.balanceOf(address(marketplace));

        vm.prank(buyer);
        marketplace.createOrder(
            IMarketplace.CreateOrder({
                eventTicketId: tokenId, price: price, deadline: deadline, orderType: IMarketplace.OrderType.BID
            })
        );

        Cache.GhostOrder memory order = Cache.GhostOrder({
            creator: buyer,
            eventTicketId: tokenId,
            price: price,
            deadline: deadline,
            orderType: IMarketplace.OrderType.BID,
            status: IMarketplace.OrderStatus.ACTIVE
        });
        uint256 orderId = cache.recordOrderCreate(order);
        cache.addBidEscrow(price);
        uint256 balanceAfter = weth.balanceOf(address(marketplace));
        cache.setLastMarketplaceBalances(balanceBefore, balanceAfter);
        cache.setLastOrderContext(orderId, buyer, address(0), tokenId, IMarketplace.OrderType.BID, 0, price);

        _syncState();
        postconditions.afterCreateBid();
    }

    function fillOrder(uint256 fillerSeed, uint256 orderSeed, uint256 priceSeed) external {
        uint256 activeCount = cache.activeOrderCount();
        if (activeCount == 0) return;

        uint256 orderId = cache.activeOrderIdAt(bound(orderSeed, 0, activeCount - 1));
        Cache.GhostOrder memory order = cache.getOrder(orderId);

        uint256 priceLimit;
        if (order.orderType == IMarketplace.OrderType.ASK) {
            priceLimit = order.price + bound(priceSeed, 0, MAX_PRICE);
        } else {
            priceLimit = bound(priceSeed, 0, order.price);
        }

        address filler = _trader(fillerSeed);
        if (!preconditions.canFillOrder(filler, orderId, priceLimit)) return;

        uint256 balanceBefore = weth.balanceOf(address(marketplace));

        vm.prank(filler);
        marketplace.fillOrder(orderId, priceLimit);

        cache.recordOrderFill(orderId);
        if (order.orderType == IMarketplace.OrderType.ASK) {
            cache.setOwner(order.eventTicketId, filler);
        } else {
            cache.setOwner(order.eventTicketId, order.creator);
        }

        _recordFillPayments(order, order.orderType == IMarketplace.OrderType.ASK);

        uint256 balanceAfter = weth.balanceOf(address(marketplace));
        cache.setLastMarketplaceBalances(balanceBefore, balanceAfter);
        cache.setLastOrderContext(
            orderId, order.creator, filler, order.eventTicketId, order.orderType, order.price, order.price
        );

        _syncState();
        postconditions.afterFillOrder();
    }

    function cancelOrder(uint256 callerSeed, uint256 orderSeed) external {
        uint256 activeCount = cache.activeOrderCount();
        if (activeCount == 0) return;

        uint256 orderId = cache.activeOrderIdAt(bound(orderSeed, 0, activeCount - 1));
        Cache.GhostOrder memory order = cache.getOrder(orderId);
        address caller = _trader(callerSeed);
        if (!preconditions.canCancelOrder(caller, orderId)) return;

        uint256 balanceBefore = weth.balanceOf(address(marketplace));

        vm.prank(caller);
        marketplace.cancelOrder(orderId);

        cache.recordOrderCancel(orderId);
        if (order.orderType == IMarketplace.OrderType.BID) {
            cache.removeBidEscrow(order.price);
        } else {
            cache.setOwner(order.eventTicketId, order.creator);
        }

        uint256 balanceAfter = weth.balanceOf(address(marketplace));
        cache.setLastMarketplaceBalances(balanceBefore, balanceAfter);
        cache.setLastOrderContext(
            orderId, order.creator, address(0), order.eventTicketId, order.orderType, order.price, order.price
        );

        _syncState();
        postconditions.afterCancelOrder();
    }

    function updateOrder(uint256 callerSeed, uint256 orderSeed, uint256 newPriceSeed, uint256 deadlineSeed) external {
        uint256 activeBidCount = cache.activeBidOrderCount();
        if (activeBidCount == 0) return;

        uint256 orderId = cache.activeBidOrderIdAt(bound(orderSeed, 0, activeBidCount - 1));
        Cache.GhostOrder memory order = cache.getOrder(orderId);

        address caller = _trader(callerSeed);
        uint256 newPrice = bound(newPriceSeed, FEE_BPS, MAX_PRICE);
        uint256 newDeadline = block.timestamp + MINIMUM_LISTING_DURATION + bound(deadlineSeed, 0, 30 days);

        if (!preconditions.canUpdateOrder(caller, orderId, newPrice, newDeadline)) return;

        uint256 balanceBefore = weth.balanceOf(address(marketplace));

        vm.prank(caller);
        marketplace.updateOrder(orderId, newPrice, newDeadline);

        if (newPrice > order.price) {
            uint256 delta = newPrice - order.price;
            cache.addBidEscrow(delta);
        } else if (newPrice < order.price) {
            uint256 delta = order.price - newPrice;
            cache.removeBidEscrow(delta);
        }

        cache.recordOrderUpdate(orderId, newPrice, newDeadline);

        uint256 balanceAfter = weth.balanceOf(address(marketplace));
        cache.setLastMarketplaceBalances(balanceBefore, balanceAfter);
        cache.setLastOrderContext(
            orderId, order.creator, address(0), order.eventTicketId, order.orderType, order.price, newPrice
        );

        _syncState();
        postconditions.afterUpdateOrder();
    }
}
