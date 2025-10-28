// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {Helper} from "../src/Helper.sol";
import {ERC20} from "./mocks/ERC20.sol";

contract HelperTest is Test {

    Auction auction;
    ERC20 asset;
    ERC20 dbr;
    Helper helper;

    function setUp() public {
        asset = new ERC20();
        dbr = new ERC20();
        auction = new Auction(
            address(1),
            address(2),
            address(dbr),
            address(asset),
            address(0),
            1e18,
            1e18
        );
        helper = new Helper(address(auction), address(asset));
    }

    function test_constructor() public {
        assertEq(address(helper.auction()), address(auction));
        assertEq(address(helper.asset()), address(asset));
    }

    function test_getDbrOut(uint assetIn) public {
        assetIn = bound(assetIn, 1, (type(uint).max - auction.assetReserve()) / auction.dbrReserve());
        uint newDbrReserve = auction.dbrReserve() - helper.getDbrOut(assetIn);
        uint newAssetReserve = auction.assetReserve() + assetIn;
        assertGe(newDbrReserve * newAssetReserve, auction.dbrReserve() * auction.assetReserve());
    }

    function test_getAssetIn(uint dbrOut) public {
        dbrOut = bound(dbrOut, 1, auction.dbrReserve() - 1);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newAssetReserve = auction.assetReserve() + helper.getAssetIn(dbrOut);
        assertGe(newDbrReserve * newAssetReserve, auction.dbrReserve() * auction.assetReserve());
    }

    function test_swapExactAssetForDbr(uint assetIn) public {
        assetIn = bound(assetIn, 1, (type(uint).max - auction.assetReserve()) / auction.dbrReserve());
        uint dbrOut = helper.getDbrOut(assetIn);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newAssetReserve = auction.assetReserve() + assetIn;
        asset.mint(address(this), assetIn);
        asset.approve(address(helper), assetIn);
        helper.swapExactAssetForDbr(assetIn, dbrOut);
        assertEq(auction.dbrReserve(), newDbrReserve);
        assertEq(auction.assetReserve(), newAssetReserve);
        assertEq(dbr.balanceOf(address(this)), dbrOut);
        assertEq(asset.balanceOf(address(this)), 0);
        assertEq(asset.balanceOf(address(auction)), assetIn);
    }

    function test_swapAssetForExactDbr(uint dbrOut) public {
        dbrOut = bound(dbrOut, 1, auction.dbrReserve() - 1);
        uint assetIn = helper.getAssetIn(dbrOut);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newAssetReserve = auction.assetReserve() + assetIn;
        asset.mint(address(this), assetIn);
        asset.approve(address(helper), assetIn);
        helper.swapAssetForExactDbr(dbrOut, assetIn);
        assertEq(auction.dbrReserve(), newDbrReserve);
        assertEq(auction.assetReserve(), newAssetReserve);
        assertEq(dbr.balanceOf(address(this)), dbrOut);
        assertEq(asset.balanceOf(address(this)), 0);
        assertEq(asset.balanceOf(address(auction)), assetIn);
    }

}