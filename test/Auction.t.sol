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
    ERC20 asset;
    Auction auction;

    function setUp() public {
        dbr = new ERC20();
        asset = new ERC20();
        auction = new Auction(
            gov,
            operator,
            address(dbr),
            address(asset),
            address(0),
            1e18,
            1e18
        );
    }

    function test_constructor() public {
        assertEq(auction.gov(), gov);
        assertEq(auction.operator(), operator);
        assertEq(address(auction.dbr()), address(dbr));
        assertEq(address(auction.asset()), address(asset));
        assertEq(auction.assetReserve(), 1e18);
        assertEq(auction.dbrReserve(), 1e18);
    }

    function test_getCurrentReserves() public {
        (uint _assetReserve, uint _dbrReserve) = auction.getCurrentReserves();
        assertEq(_assetReserve, 1e18);
        assertEq(_dbrReserve, 1e18);
        vm.prank(gov);
        auction.setMaxDbrRatePerYear(1e18);
        vm.prank(gov);
        auction.setDbrRatePerYear(1e18);
        (_assetReserve, _dbrReserve) = auction.getCurrentReserves();
        assertEq(_assetReserve, 1e18);
        assertEq(_dbrReserve, 1e18);
        vm.warp(block.timestamp + 365 days);
        (_assetReserve, _dbrReserve) = auction.getCurrentReserves();
        assertApproxEqAbs(_assetReserve, 0.5e18, 1e7);
        assertApproxEqAbs(_dbrReserve, 2 * 1e18, 1e8);
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

    function test_setAssetReserve() public {
        vm.expectRevert("onlyGov");
        auction.setAssetReserve(1e19);
        vm.startPrank(gov);
        vm.expectRevert("Asset reserve must be positive");
        auction.setAssetReserve(0);
        uint oldAssetReserve = auction.assetReserve();
        uint oldDbrReserve = auction.dbrReserve();
        uint ratioMantissaBefore = oldDbrReserve * 1e18 / oldAssetReserve;
        uint newAssetReserve = 1e19;
        uint expectedDbrReserve = newAssetReserve * oldDbrReserve / oldAssetReserve;
        auction.setAssetReserve(newAssetReserve);
        uint updatedAssetReserve = auction.assetReserve();
        uint updatedDbrReserve = auction.dbrReserve();
        assertEq(updatedAssetReserve, newAssetReserve);
        assertEq(updatedDbrReserve, expectedDbrReserve);
        uint ratioMantissaAfter = updatedDbrReserve * 1e18 / updatedAssetReserve;
        assertEq(ratioMantissaAfter, ratioMantissaBefore);
    }

    function test_setDbrReserve() public {
        vm.expectRevert("onlyGov");
        auction.setDbrReserve(1e19);
        vm.startPrank(gov);
        vm.expectRevert("DBR reserve must be positive");
        auction.setDbrReserve(0);
        uint oldAssetReserve = auction.assetReserve();
        uint oldDbrReserve = auction.dbrReserve();
        uint ratioMantissaBefore = oldDbrReserve * 1e18 / oldAssetReserve;
        uint newDbrReserve = 1e19;
        uint expectedAssetReserve = newDbrReserve * oldAssetReserve / oldDbrReserve;
        auction.setDbrReserve(newDbrReserve);
        uint updatedDbrReserve = auction.dbrReserve();
        uint updatedAssetReserve = auction.assetReserve();
        assertEq(updatedDbrReserve, newDbrReserve);
        assertEq(updatedAssetReserve, expectedAssetReserve);
        uint ratioMantissaAfter = updatedDbrReserve * 1e18 / updatedAssetReserve;
        assertEq(ratioMantissaAfter, ratioMantissaBefore);
    }

    function test_overrideReserves() public {
        vm.expectRevert("onlyGov");
        auction.overrideReserves(0,0);
        vm.startPrank(gov);
        vm.expectRevert("Asset reserve must be positive");
        auction.overrideReserves(1,0);
        vm.expectRevert("DBR reserve must be positive");
        auction.overrideReserves(0,1);
        uint newTimestamp = block.timestamp + 1;
        vm.warp(newTimestamp);
        auction.overrideReserves(2,3);
        assertEq(auction.dbrReserve(), 2);
        assertEq(auction.assetReserve(), 3);
        assertEq(auction.lastUpdate(), newTimestamp);
    }

    function test_sweep() public {
        vm.expectRevert("onlyGov");
        auction.sweep(address(1), address(1), 1);
        asset.mint(address(auction), 1);
        assertEq(asset.balanceOf(address(auction)), 1);
        vm.prank(gov);
        auction.sweep(address(asset), address(this), 1);
        assertEq(asset.balanceOf(address(auction)), 0);
        assertEq(asset.balanceOf(address(this)), 1);
    }

    function test_sendToSaleHandler(uint assetIn) public {
        assetIn = bound(assetIn, 1, type(uint).max - 1e18); // max asset in = (max uint - asset reserve)
        MockSaleHandler handler = new MockSaleHandler();
        vm.expectRevert("No sale handler");
        auction.sendToSaleHandler();
        vm.prank(gov);
        auction.setSaleHandler(address(handler));
        asset.mint(address(auction), assetIn);
        handler.setCapacity(assetIn - 1);
        auction.sendToSaleHandler();
        assertEq(asset.balanceOf(address(auction)), 1);
        assertEq(asset.balanceOf(address(handler)), assetIn - 1);
        assertEq(handler.received(), true);
    }

    function test_buyDBR(uint exactAssetIn, uint exactDbrOut) public {
        exactDbrOut = bound(exactDbrOut, 1, auction.dbrReserve());
        exactAssetIn = bound(exactAssetIn, 0, (type(uint).max - auction.assetReserve()) / auction.dbrReserve() - exactDbrOut);
        asset.mint(address(this), exactAssetIn);
        asset.approve(address(auction), exactAssetIn);
        uint K = auction.assetReserve() * auction.dbrReserve();
        uint newDbrReserve = auction.dbrReserve() - exactDbrOut;
        uint newAssetReserve = auction.assetReserve() + exactAssetIn;
        uint newK = newAssetReserve * newDbrReserve;
        if(newK < K) {
            vm.expectRevert("Invariant");
            auction.buyDBR(exactAssetIn, exactDbrOut, address(1));
        } else {
            auction.buyDBR(exactAssetIn, exactDbrOut, address(1));
            assertEq(asset.balanceOf(address(this)), 0);
            assertEq(asset.balanceOf(address(auction)), exactAssetIn);
            assertEq(dbr.balanceOf(address(1)), exactDbrOut);
            assertEq(auction.dbrReserve(), newDbrReserve);
            assertEq(auction.assetReserve(), newAssetReserve);
        }
    }

}
