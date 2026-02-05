// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IMarketplace} from "../../src/interfaces/IMarketplace.sol";

contract Cache {
    struct GhostOrder {
        address creator;
        uint256 eventTicketId;
        uint256 price;
        uint256 deadline;
        IMarketplace.OrderType orderType;
        IMarketplace.OrderStatus status;
    }

    address public ticket;
    address public sale;
    address public marketplace;
    address public organizer;
    address public protocolFeeRecipient;
    address public weth;

    uint256 public cachedTicketTotalSupply;
    uint256 public cachedTicketMaxSupply;
    uint256 public cachedNextTicketId;
    uint256 public cachedSaleStart;
    uint256 public cachedSaleEnd;
    uint256 public cachedTicketPriceWei;

    uint256 public cachedMarketplaceWethBalance;
    uint256 public cachedOrganizerWethBalance;
    uint256 public cachedProtocolWethBalance;

    mapping(uint256 => address) public cachedOwnerOf;
    mapping(uint256 => bool) public cachedTicketExists;

    uint256 public nextOrderId;

    uint256 public totalMinted;

    uint256 public activeBidEscrow;
    uint256 public totalWethIn;
    uint256 public totalWethOut;
    uint256 public totalWethPaidToSellers;
    uint256 public totalWethPaidToOrganizer;
    uint256 public totalWethPaidToProtocol;

    mapping(uint256 => GhostOrder) public orders;

    uint256[] public activeOrderIds;
    mapping(uint256 => uint256) public activeOrderIndex;

    uint256[] public activeBidOrderIds;
    mapping(uint256 => uint256) public activeBidOrderIndex;

    uint256[] public activeAskOrderIds;
    mapping(uint256 => uint256) public activeAskOrderIndex;

    uint256[] public activeAskTokenIds;
    mapping(uint256 => uint256) public activeAskTokenIndex;

    address public lastBuyer;
    uint256 public lastTotalCost;
    uint256 public lastOrganizerBalanceBefore;
    uint256 public lastOrganizerBalanceAfter;
    uint256 public lastMarketplaceBalanceBefore;
    uint256 public lastMarketplaceBalanceAfter;
    uint256 public lastTotalSupplyBefore;
    uint256 public lastTotalSupplyAfter;

    uint256 public lastOrderId;
    address public lastOrderCreator;
    address public lastOrderFiller;
    uint256 public lastOrderTicketId;
    IMarketplace.OrderType public lastOrderType;
    uint256 public lastOrderPriceBefore;
    uint256 public lastOrderPriceAfter;

    uint256[] private lastTicketIds;

    function setAddresses(
        address ticket_,
        address sale_,
        address marketplace_,
        address weth_,
        address organizer_,
        address protocolFeeRecipient_
    ) external {
        ticket = ticket_;
        sale = sale_;
        marketplace = marketplace_;
        weth = weth_;
        organizer = organizer_;
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    function syncTicketState(uint256 totalSupply, uint256 nextTicketId) external {
        cachedTicketTotalSupply = totalSupply;
        cachedNextTicketId = nextTicketId;
    }

    function syncSaleConfig(uint256 maxSupply, uint256 saleStart, uint256 saleEnd, uint256 priceWei) external {
        cachedTicketMaxSupply = maxSupply;
        cachedSaleStart = saleStart;
        cachedSaleEnd = saleEnd;
        cachedTicketPriceWei = priceWei;
    }

    function syncBalances(uint256 marketplaceBalance, uint256 organizerBalance, uint256 protocolBalance) external {
        cachedMarketplaceWethBalance = marketplaceBalance;
        cachedOrganizerWethBalance = organizerBalance;
        cachedProtocolWethBalance = protocolBalance;
    }

    function setOwner(uint256 tokenId, address owner) external {
        cachedOwnerOf[tokenId] = owner;
        cachedTicketExists[tokenId] = true;
    }

    function setLastBuyContext(
        address buyer,
        uint256 totalCost,
        uint256 organizerBalanceBefore,
        uint256 organizerBalanceAfter,
        uint256 totalSupplyBefore,
        uint256 totalSupplyAfter,
        uint256[] memory ticketIds
    ) external {
        lastBuyer = buyer;
        lastTotalCost = totalCost;
        lastOrganizerBalanceBefore = organizerBalanceBefore;
        lastOrganizerBalanceAfter = organizerBalanceAfter;
        lastTotalSupplyBefore = totalSupplyBefore;
        lastTotalSupplyAfter = totalSupplyAfter;

        _setLastTicketIds(ticketIds);
    }

    function setLastOrderContext(
        uint256 orderId,
        address creator,
        address filler,
        uint256 eventTicketId,
        IMarketplace.OrderType orderType,
        uint256 priceBefore,
        uint256 priceAfter
    ) external {
        lastOrderId = orderId;
        lastOrderCreator = creator;
        lastOrderFiller = filler;
        lastOrderTicketId = eventTicketId;
        lastOrderType = orderType;
        lastOrderPriceBefore = priceBefore;
        lastOrderPriceAfter = priceAfter;
    }

    function setLastMarketplaceBalances(uint256 balanceBefore, uint256 balanceAfter) external {
        lastMarketplaceBalanceBefore = balanceBefore;
        lastMarketplaceBalanceAfter = balanceAfter;
    }

    function setLastOrganizerBalances(uint256 balanceBefore, uint256 balanceAfter) external {
        lastOrganizerBalanceBefore = balanceBefore;
        lastOrganizerBalanceAfter = balanceAfter;
    }

    function setLastSupply(uint256 supplyBefore, uint256 supplyAfter) external {
        lastTotalSupplyBefore = supplyBefore;
        lastTotalSupplyAfter = supplyAfter;
    }

    function recordMint(uint256 amount) external {
        totalMinted += amount;
    }

    function getOrder(uint256 orderId) external view returns (GhostOrder memory) {
        return orders[orderId];
    }

    function recordOrderCreate(GhostOrder memory order) external returns (uint256 orderId) {
        orderId = nextOrderId;
        nextOrderId += 1;

        order.status = IMarketplace.OrderStatus.ACTIVE;
        orders[orderId] = order;

        _addActiveOrder(orderId);
        if (order.orderType == IMarketplace.OrderType.BID) {
            _addActiveBidOrder(orderId);
        } else {
            _addActiveAskOrder(orderId);
            _addActiveAskToken(order.eventTicketId);
        }
    }

    function recordOrderFill(uint256 orderId) external {
        orders[orderId].status = IMarketplace.OrderStatus.FILLED;
        _removeActiveOrder(orderId);
        if (orders[orderId].orderType == IMarketplace.OrderType.BID) {
            _removeActiveBidOrder(orderId);
        } else {
            _removeActiveAskOrder(orderId);
            _removeActiveAskToken(orders[orderId].eventTicketId);
        }
    }

    function recordOrderCancel(uint256 orderId) external {
        orders[orderId].status = IMarketplace.OrderStatus.CANCELLED;
        _removeActiveOrder(orderId);
        if (orders[orderId].orderType == IMarketplace.OrderType.BID) {
            _removeActiveBidOrder(orderId);
        } else {
            _removeActiveAskOrder(orderId);
            _removeActiveAskToken(orders[orderId].eventTicketId);
        }
    }

    function recordOrderUpdate(uint256 orderId, uint256 newPrice, uint256 newDeadline) external {
        orders[orderId].price = newPrice;
        orders[orderId].deadline = newDeadline;
        orders[orderId].status = IMarketplace.OrderStatus.ACTIVE;
    }

    function addBidEscrow(uint256 amount) external {
        activeBidEscrow += amount;
        totalWethIn += amount;
    }

    function removeBidEscrow(uint256 amount) external {
        activeBidEscrow -= amount;
        totalWethOut += amount;
    }

    function addWethIn(uint256 amount) external {
        totalWethIn += amount;
    }

    function addWethOut(uint256 amount) external {
        totalWethOut += amount;
    }

    function addSellerPayment(uint256 amount) external {
        totalWethPaidToSellers += amount;
    }

    function addOrganizerPayment(uint256 amount) external {
        totalWethPaidToOrganizer += amount;
    }

    function addProtocolPayment(uint256 amount) external {
        totalWethPaidToProtocol += amount;
    }

    function lastTicketIdsLength() external view returns (uint256) {
        return lastTicketIds.length;
    }

    function lastTicketIdAt(uint256 index) external view returns (uint256) {
        return lastTicketIds[index];
    }

    function activeOrderCount() external view returns (uint256) {
        return activeOrderIds.length;
    }

    function activeBidOrderCount() external view returns (uint256) {
        return activeBidOrderIds.length;
    }

    function activeAskOrderCount() external view returns (uint256) {
        return activeAskOrderIds.length;
    }

    function activeAskTokenCount() external view returns (uint256) {
        return activeAskTokenIds.length;
    }

    function activeOrderIdAt(uint256 index) external view returns (uint256) {
        return activeOrderIds[index];
    }

    function activeBidOrderIdAt(uint256 index) external view returns (uint256) {
        return activeBidOrderIds[index];
    }

    function activeAskTokenIdAt(uint256 index) external view returns (uint256) {
        return activeAskTokenIds[index];
    }

    function _setLastTicketIds(uint256[] memory ticketIds) internal {
        delete lastTicketIds;
        for (uint256 i = 0; i < ticketIds.length; i++) {
            lastTicketIds.push(ticketIds[i]);
        }
    }

    function _addActiveOrder(uint256 orderId) internal {
        activeOrderIndex[orderId] = activeOrderIds.length;
        activeOrderIds.push(orderId);
    }

    function _removeActiveOrder(uint256 orderId) internal {
        _removeFromArray(activeOrderIds, activeOrderIndex, orderId);
    }

    function _addActiveBidOrder(uint256 orderId) internal {
        activeBidOrderIndex[orderId] = activeBidOrderIds.length;
        activeBidOrderIds.push(orderId);
    }

    function _removeActiveBidOrder(uint256 orderId) internal {
        _removeFromArray(activeBidOrderIds, activeBidOrderIndex, orderId);
    }

    function _addActiveAskOrder(uint256 orderId) internal {
        activeAskOrderIndex[orderId] = activeAskOrderIds.length;
        activeAskOrderIds.push(orderId);
    }

    function _removeActiveAskOrder(uint256 orderId) internal {
        _removeFromArray(activeAskOrderIds, activeAskOrderIndex, orderId);
    }

    function _addActiveAskToken(uint256 tokenId) internal {
        activeAskTokenIndex[tokenId] = activeAskTokenIds.length;
        activeAskTokenIds.push(tokenId);
    }

    function _removeActiveAskToken(uint256 tokenId) internal {
        _removeFromArray(activeAskTokenIds, activeAskTokenIndex, tokenId);
    }

    function _removeFromArray(uint256[] storage values, mapping(uint256 => uint256) storage indexes, uint256 value)
        internal
    {
        uint256 lastIndex = values.length - 1;
        uint256 index = indexes[value];
        if (index != lastIndex) {
            uint256 lastValue = values[lastIndex];
            values[index] = lastValue;
            indexes[lastValue] = index;
        }
        values.pop();
        delete indexes[value];
    }
}
