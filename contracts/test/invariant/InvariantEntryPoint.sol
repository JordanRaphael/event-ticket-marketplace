// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Vm} from "forge-std/Vm.sol";

import {IFactory} from "src/interfaces/IFactory.sol";
import {Ticket} from "src/Ticket.sol";
import {Sale} from "src/Sale.sol";
import {Marketplace} from "src/Marketplace.sol";
import {Factory} from "src/Factory.sol";

import {MockWETH} from "test/mocks/MockWETH.sol";
import {Handler} from "test/invariant/handlers/Handler.sol";
import {Config} from "test/invariant/handlers/HandlerBase.sol";
import {Cache} from "./Cache.sol";
import {Preconditions} from "test/invariant/preconditions/Preconditions.sol";
import {Postconditions} from "test/invariant/postconditions/Postconditions.sol";
import {GlobalInvariants} from "./invariants/GlobalInvariants.sol";

contract InvariantEntryPointTest is GlobalInvariants {
    address internal constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    Factory internal factory;
    Ticket internal ticket;
    Sale internal sale;
    Marketplace internal marketplace;
    MockWETH internal weth;

    Preconditions internal preconditions;
    Postconditions internal postconditions;
    Handler internal handler;

    address internal protocolOwner;
    address internal organizer;

    function setUp() public {
        protocolOwner = address(0xBEEF);
        organizer = address(0xCAFE);

        _deployMockWeth();
        weth = MockWETH(WETH_ADDRESS);

        Ticket eventTicketImpl = new Ticket(address(0xF1));
        Sale ticketSaleImpl = new Sale(address(0xF1), WETH_ADDRESS);
        Marketplace ticketMarketplaceImpl = new Marketplace(address(0xF1), WETH_ADDRESS);

        factory = new Factory(
            protocolOwner, address(eventTicketImpl), address(ticketSaleImpl), address(ticketMarketplaceImpl)
        );

        IFactory.CreateSaleParams memory params = IFactory.CreateSaleParams({
            name: "Test Event",
            symbol: "TIX",
            baseURI: "ipfs://base",
            organizer: organizer,
            priceInWei: 0.1 ether,
            maxSupply: 200,
            saleStart: block.timestamp + 1 days,
            saleEnd: block.timestamp + 30 days
        });

        vm.recordLogs();
        vm.prank(organizer);
        factory.createSale(params);
        (address eventTicketAddr, address ticketSaleAddr, address ticketMarketplaceAddr) = _extractEventCreated();

        ticket = Ticket(eventTicketAddr);
        sale = Sale(ticketSaleAddr);
        marketplace = Marketplace(ticketMarketplaceAddr);

        cache = new Cache();
        _setCache(cache);
        cache.setAddresses(
            address(ticket),
            address(sale),
            address(marketplace),
            address(weth),
            sale.eventOrganizer(),
            marketplace.protocolFeeRecipient()
        );
        cache.syncTicketState(ticket.totalSupply(), sale.nextTicketId());
        cache.syncSaleConfig(sale.ticketMaxSupply(), sale.saleStart(), sale.saleEnd(), sale.ticketPriceWei());
        cache.syncBalances(
            weth.balanceOf(address(marketplace)),
            weth.balanceOf(sale.eventOrganizer()),
            weth.balanceOf(marketplace.protocolFeeRecipient())
        );

        preconditions = new Preconditions(ticket, marketplace, sale, weth, cache);
        postconditions = new Postconditions(cache);

        address[] memory traders = new address[](4);
        traders[0] = address(0xA11CE);
        traders[1] = address(0xB0B);
        traders[2] = address(0xC0C0A);
        traders[3] = address(0xD1E);

        for (uint256 i = 0; i < traders.length; i++) {
            weth.mint(traders[i], 1_000 ether);
            vm.prank(traders[i]);
            weth.approve(address(marketplace), type(uint256).max);
            vm.prank(traders[i]);
            weth.approve(address(sale), type(uint256).max);
        }

        Ticket upgradeTicketImpl = new Ticket(address(0xF2));
        Sale upgradeSaleImpl = new Sale(address(0xF2), WETH_ADDRESS);
        Marketplace upgradeMarketplaceImpl = new Marketplace(address(0xF2), WETH_ADDRESS);

        Config memory config = Config({
            factory: factory,
            ticket: ticket,
            sale: sale,
            marketplace: marketplace,
            weth: weth,
            cache: cache,
            preconditions: preconditions,
            postconditions: postconditions,
            organizer: organizer,
            protocolOwner: protocolOwner,
            traders: traders,
            eventTicketImplUpgrade: address(upgradeTicketImpl),
            ticketSaleImplUpgrade: address(upgradeSaleImpl),
            ticketMarketplaceImplUpgrade: address(upgradeMarketplaceImpl)
        });

        handler = new Handler(config);

        bytes4[] memory selectors = new bytes4[](14);
        selectors[0] = handler.approveMarketplace.selector;
        selectors[1] = handler.buyTickets.selector;
        selectors[2] = handler.createAsk.selector;
        selectors[3] = handler.createBid.selector;
        selectors[4] = handler.fillOrder.selector;
        selectors[5] = handler.cancelOrder.selector;
        selectors[6] = handler.updateOrder.selector;
        selectors[7] = handler.setTicketMaxSupply.selector;
        selectors[8] = handler.setTicketPrice.selector;
        selectors[9] = handler.setSaleEnd.selector;
        selectors[10] = handler.setSaleStart.selector;
        selectors[11] = handler.proposeUpgrade.selector;
        selectors[12] = handler.executeUpgrade.selector;
        selectors[13] = handler.advanceTime.selector;

        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_global() external view {
        _assertGlobalInvariants();
    }

    function _deployMockWeth() internal {
        MockWETH mock = new MockWETH();
        vm.etch(WETH_ADDRESS, address(mock).code);
    }

    function _extractEventCreated()
        internal
        returns (address eventTicket, address ticketSale, address ticketMarketplace)
    {
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 signature = keccak256("EventCreated(address,uint256,address,address,address)");

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length == 0) continue;
            if (entries[i].topics[0] != signature) continue;
            (eventTicket, ticketSale, ticketMarketplace) = abi.decode(entries[i].data, (address, address, address));
            return (eventTicket, ticketSale, ticketMarketplace);
        }

        revert("EventCreated not found");
    }
}
