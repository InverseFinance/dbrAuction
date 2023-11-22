// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {ERC20} from "./mocks/ERC20.sol";

contract MockSaleHandler {
    uint public getCapacity;
    bool public received;

    function setCapacity(uint capacity) external {
        getCapacity = capacity;
    }

    function onReceive() external {
        received = true;
    }
}

contract AuctionTest is Test {

    address gov = address(1);
    address operator = address(2);
    ERC20 dbr;
    ERC20 dola;
    Auction auction;

    function setUp() public {
        dbr = new ERC20();
        dola = new ERC20();
        auction = new Auction(
            gov,
            operator,
            address(dbr),
            address(dola),
            1e18,
            1e18
        );
    }

    function test_constructor() public {
        assertEq(auction.gov(), gov);
        assertEq(auction.operator(), operator);
        assertEq(address(auction.dbr()), address(dbr));
        assertEq(address(auction.dola()), address(dola));
        assertEq(auction.dolaReserve(), 1e18);
        assertEq(auction.dbrReserve(), 1e18);
    }

    function test_getCurrentReserves() public {
        (uint _dolaReserve, uint _dbrReserve) = auction.getCurrentReserves();
        assertEq(_dolaReserve, 1e18);
        assertEq(_dbrReserve, 1e18);
        vm.prank(gov);
        auction.setMaxDbrRatePerYear(1e18);
        vm.prank(gov);
        auction.setDbrRatePerYear(1e18);
        (_dolaReserve, _dbrReserve) = auction.getCurrentReserves();
        assertEq(_dolaReserve, 1e18);
        assertEq(_dbrReserve, 1e18);
        vm.warp(block.timestamp + 365 days);
        (_dolaReserve, _dbrReserve) = auction.getCurrentReserves();
        assertApproxEqAbs(_dolaReserve, 0.5e18, 1e7);
        assertApproxEqAbs(_dbrReserve, 2 * 1e18, 1e8);
    }

    function test_getDbrOut(uint dolaIn) public {
        dolaIn = bound(dolaIn, 0, type(uint).max - 1e18); // max dola in = (max uint - dola reserve)
        uint x = 1e18;
        uint y = 1e18;
        uint K = x * y;
        uint yOut = x - (K / (x + dolaIn));
        assertEq(auction.getDbrOut(dolaIn), yOut);
    }

    function test_setGov() public {
        vm.expectRevert("onlyGov");
        auction.setGov(address(0));
        vm.prank(gov);
        auction.setGov(address(this));
        assertEq(auction.gov(), address(this));
    }

    function test_setOperator() public {
        vm.expectRevert("onlyGov");
        auction.setOperator(address(0));
        vm.prank(gov);
        auction.setOperator(address(this));
        assertEq(auction.operator(), address(this));
    }

    function test_setSaleHandler() public {
        vm.expectRevert("onlyGov");
        auction.setSaleHandler(address(0));
        vm.prank(gov);
        auction.setSaleHandler(address(this));
        assertEq(address(auction.saleHandler()), address(this));
    }

    function test_setMaxDbrRatePerYear() public {
        vm.expectRevert("onlyGov");
        auction.setMaxDbrRatePerYear(1e18);
        vm.startPrank(gov);
        auction.setMaxDbrRatePerYear(1e18);
        assertEq(auction.maxDbrRatePerYear(), 1e18);
        auction.setDbrRatePerYear(1e18);
        assertEq(auction.dbrRatePerYear(), 1e18);
        auction.setMaxDbrRatePerYear(0);
        assertEq(auction.maxDbrRatePerYear(), 0);
        assertEq(auction.dbrRatePerYear(), 0);
    }

    function test_setDbrRatePerYear() public {
        vm.expectRevert("onlyGov");
        auction.setDbrRatePerYear(1e18);
        vm.startPrank(gov);
        vm.expectRevert("Rate exceeds max");
        auction.setDbrRatePerYear(1e18);
        assertEq(auction.dbrRatePerYear(), 0);
        auction.setMaxDbrRatePerYear(1e18);
        auction.setDbrRatePerYear(1e18);
        assertEq(auction.dbrRatePerYear(), 1e18);
        vm.startPrank(operator);
        auction.setDbrRatePerYear(0);
        assertEq(auction.dbrRatePerYear(), 0);
    }

    function test_setDolaReserve() public {
        vm.expectRevert("onlyGov");
        auction.setDolaReserve(1e19);
        vm.startPrank(gov);
        vm.expectRevert("Dola reserve must be positive");
        auction.setDolaReserve(0);
        auction.setDolaReserve(1e19);
        assertEq(auction.dolaReserve(), 1e19);
        assertEq(auction.dbrReserve(), 1e17);
    }

    function test_setDbrReserve() public {
        vm.expectRevert("onlyGov");
        auction.setDbrReserve(1e19);
        vm.startPrank(gov);
        vm.expectRevert("DBR reserve must be positive");
        auction.setDbrReserve(0);
        auction.setDbrReserve(1e19);
        assertEq(auction.dolaReserve(), 1e17);
        assertEq(auction.dbrReserve(), 1e19);
    }

    function test_overrideReserves() public {
        vm.expectRevert("onlyGov");
        auction.overrideReserves(0,0);
        vm.startPrank(gov);
        vm.expectRevert("Dola reserve must be positive");
        auction.overrideReserves(1,0);
        vm.expectRevert("DBR reserve must be positive");
        auction.overrideReserves(0,1);
        uint newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);
        auction.overrideReserves(2,3);
        assertEq(auction.dbrReserve(), 2);
        assertEq(auction.dolaReserve(), 3);
        assertEq(auction.lastUpdate(), newTimestamp);
    }

    function test_sweep() public {
        vm.expectRevert("onlyGov");
        auction.sweep(address(1), address(1), 1);
        dola.mint(address(auction), 1);
        assertEq(dola.balanceOf(address(auction)), 1);
        vm.prank(gov);
        auction.sweep(address(dola), address(this), 1);
        assertEq(dola.balanceOf(address(auction)), 0);
        assertEq(dola.balanceOf(address(this)), 1);
    }

    function test_buyDBR(uint dolaIn) public {
        dolaIn = bound(dolaIn, 0, type(uint).max - 1e18); // max dola in = (max uint - dola reserve)
        dola.mint(address(this), dolaIn);
        dola.approve(address(auction), dolaIn);
        auction.buyDBR(dolaIn, 0);
        uint x = 1e18;
        uint y = 1e18;
        uint K = x * y;
        uint yOut = x - (K / (x + dolaIn));
        assertEq(dola.balanceOf(address(this)), 0);
        assertEq(dola.balanceOf(address(auction)), dolaIn);
        assertEq(dbr.balanceOf(address(this)), yOut);
        assertEq(auction.dbrReserve(), 1e18 - yOut);
        assertEq(auction.dolaReserve(), 1e18 + dolaIn);
    }

    function test_buyDBRWithHandlerWithCapacity(uint dolaIn) public {
        dolaIn = bound(dolaIn, 1, type(uint).max - 1e18); // max dola in = (max uint - dola reserve)
        MockSaleHandler handler = new MockSaleHandler();
        vm.prank(gov);
        auction.setSaleHandler(address(handler));
        dola.mint(address(this), dolaIn);
        dola.approve(address(auction), dolaIn);
        handler.setCapacity(dolaIn);
        auction.buyDBR(dolaIn, 0); // 0 capacity
        assertEq(dola.balanceOf(address(auction)), 0);
        assertEq(dola.balanceOf(address(handler)), dolaIn);
        assertEq(handler.received(), true);
    }

    function test_buyDBRWithHandlerNoCapacity(uint dolaIn) public {
        dolaIn = bound(dolaIn, 1, type(uint).max - 1e18); // max dola in = (max uint - dola reserve)
        MockSaleHandler handler = new MockSaleHandler();
        vm.prank(gov);
        auction.setSaleHandler(address(handler));
        dola.mint(address(this), dolaIn);
        dola.approve(address(auction), dolaIn);
        auction.buyDBR(dolaIn, 0); // 0 capacity
        assertEq(dola.balanceOf(address(auction)), dolaIn);
        assertEq(dola.balanceOf(address(handler)), 0);
        assertEq(handler.received(), false);
    }
}
