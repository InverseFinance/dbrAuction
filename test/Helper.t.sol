// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Auction} from "../src/Auction.sol";
import {Helper} from "../src/Helper.sol";
import {ERC20} from "./mocks/ERC20.sol";

contract HelperTest is Test {

    Auction auction;
    ERC20 dola;
    ERC20 dbr;
    Helper helper;

    function setUp() public {
        dola = new ERC20();
        dbr = new ERC20();
        auction = new Auction(
            address(1),
            address(2),
            address(dbr),
            address(dola),
            address(0),
            1e18,
            1e18
        );
        helper = new Helper(address(auction), address(dola));
    }

    function test_constructor() public {
        assertEq(address(helper.auction()), address(auction));
        assertEq(address(helper.dola()), address(dola));
    }

    function test_getDbrOut(uint dolaIn) public {
        dolaIn = bound(dolaIn, 1, (type(uint).max - auction.dolaReserve()) / auction.dbrReserve());
        uint newDbrReserve = auction.dbrReserve() - helper.getDbrOut(dolaIn);
        uint newDolaReserve = auction.dolaReserve() + dolaIn;
        assertGe(newDbrReserve * newDolaReserve, auction.dbrReserve() * auction.dolaReserve());
    }

    function test_getDolaIn(uint dbrOut) public {
        dbrOut = bound(dbrOut, 1, auction.dbrReserve() - 1);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newDolaReserve = auction.dolaReserve() + helper.getDolaIn(dbrOut);
        assertGe(newDbrReserve * newDolaReserve, auction.dbrReserve() * auction.dolaReserve());
    }

    function test_swapExactDolaForDbr(uint dolaIn) public {
        dolaIn = bound(dolaIn, 1, (type(uint).max - auction.dolaReserve()) / auction.dbrReserve());
        uint dbrOut = helper.getDbrOut(dolaIn);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newDolaReserve = auction.dolaReserve() + dolaIn;
        dola.mint(address(this), dolaIn);
        dola.approve(address(helper), dolaIn);
        helper.swapExactDolaForDbr(dolaIn, dbrOut);
        assertEq(auction.dbrReserve(), newDbrReserve);
        assertEq(auction.dolaReserve(), newDolaReserve);
        assertEq(dbr.balanceOf(address(this)), dbrOut);
        assertEq(dola.balanceOf(address(this)), 0);
        assertEq(dola.balanceOf(address(auction)), dolaIn);
    }

    function test_swapDolaForExactDbr(uint dbrOut) public {
        dbrOut = bound(dbrOut, 1, auction.dbrReserve() - 1);
        uint dolaIn = helper.getDolaIn(dbrOut);
        uint newDbrReserve = auction.dbrReserve() - dbrOut;
        uint newDolaReserve = auction.dolaReserve() + dolaIn;
        dola.mint(address(this), dolaIn);
        dola.approve(address(helper), dolaIn);
        helper.swapDolaForExactDbr(dbrOut, dolaIn);
        assertEq(auction.dbrReserve(), newDbrReserve);
        assertEq(auction.dolaReserve(), newDolaReserve);
        assertEq(dbr.balanceOf(address(this)), dbrOut);
        assertEq(dola.balanceOf(address(this)), 0);
        assertEq(dola.balanceOf(address(auction)), dolaIn);
    }

}