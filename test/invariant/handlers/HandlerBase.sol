// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";

import {Ticket} from "src/Ticket.sol";
import {Sale} from "src/Sale.sol";
import {Marketplace} from "src/Marketplace.sol";
import {Factory} from "src/Factory.sol";

import {Cache} from "test/invariant/Cache.sol";
import {Preconditions} from "test/invariant/preconditions/Preconditions.sol";
import {Postconditions} from "test/invariant/postconditions/Postconditions.sol";
import {MockWETH} from "test/mocks/MockWETH.sol";

struct Config {
    Factory factory;
    Ticket ticket;
    Sale sale;
    Marketplace marketplace;
    MockWETH weth;
    Cache cache;
    Preconditions preconditions;
    Postconditions postconditions;
    address organizer;
    address protocolOwner;
    address[] traders;
    address eventTicketImplUpgrade;
    address ticketSaleImplUpgrade;
    address ticketMarketplaceImplUpgrade;
}

abstract contract HandlerBase is Test {
    uint256 internal constant FEE_BPS = 10_000;
    uint256 internal constant MINIMUM_LISTING_DURATION = 5 minutes;
    uint256 internal constant MAX_PRICE = 100 ether;

    Factory public factory;
    Ticket public ticket;
    Sale public sale;
    Marketplace public marketplace;
    MockWETH public weth;
    Cache public cache;
    Preconditions public preconditions;
    Postconditions public postconditions;

    address public organizer;
    address public protocolOwner;

    address[] public traders;

    address public eventTicketImplUpgrade;
    address public ticketSaleImplUpgrade;
    address public ticketMarketplaceImplUpgrade;

    constructor(Config memory config) {
        factory = config.factory;
        ticket = config.ticket;
        sale = config.sale;
        marketplace = config.marketplace;
        weth = config.weth;
        cache = config.cache;
        preconditions = config.preconditions;
        postconditions = config.postconditions;
        organizer = config.organizer;
        protocolOwner = config.protocolOwner;
        traders = config.traders;
        eventTicketImplUpgrade = config.eventTicketImplUpgrade;
        ticketSaleImplUpgrade = config.ticketSaleImplUpgrade;
        ticketMarketplaceImplUpgrade = config.ticketMarketplaceImplUpgrade;
    }

    function _syncState() internal {
        cache.syncTicketState(ticket.totalSupply(), sale.nextTicketId());
        cache.syncSaleConfig(sale.ticketMaxSupply(), sale.saleStart(), sale.saleEnd(), sale.ticketPriceWei());
        cache.syncBalances(
            weth.balanceOf(address(marketplace)),
            weth.balanceOf(sale.eventOrganizer()),
            weth.balanceOf(marketplace.protocolFeeRecipient())
        );
    }

    function _recordFillPayments(Cache.GhostOrder memory order, bool isAsk) internal {
        uint256 totalFees = marketplace.totalFeeBps();
        uint256 organizerFee = marketplace.organizerFeeBps();

        uint256 fees = order.price * totalFees / FEE_BPS;
        uint256 paymentToSeller = order.price - fees;
        uint256 paymentToOrganizer = fees * organizerFee / FEE_BPS;
        uint256 paymentToProtocol = fees - paymentToOrganizer;

        if (isAsk) {
            cache.addWethIn(order.price);
            cache.addWethOut(order.price);
        } else {
            cache.removeBidEscrow(order.price);
        }

        cache.addSellerPayment(paymentToSeller);
        cache.addOrganizerPayment(paymentToOrganizer);
        cache.addProtocolPayment(paymentToProtocol);
    }

    function _trader(uint256 seed) internal view returns (address) {
        return traders[seed % traders.length];
    }

    function _containsId(uint256[] memory values, uint256 length, uint256 value) internal pure returns (bool) {
        for (uint256 i = 0; i < length; i++) {
            if (values[i] == value) return true;
        }
        return false;
    }
}
