// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {DolaSaleHandler} from "../src/DolaSaleHandler.sol";
import {ERC20} from "./mocks/ERC20.sol";

contract MockAnDola {

    mapping(address => uint) public borrowBalanceStored;
    address public borrower;
    uint public repayAmount;

    function repayBorrowBehalf(address _borrower, uint _repayAmount) external returns (uint) {
        require(_repayAmount <= borrowBalanceStored[_borrower], "Insufficient debt");
        borrower = _borrower;
        repayAmount = _repayAmount;
        return 0;
    }

    function setBorrowBalance(address _borrower, uint value) external {
        borrowBalanceStored[_borrower] = value;
    }
    
    
}

contract SaleHandlerTest is Test {

    ERC20 asset;
    MockAnDola anDola;
    DolaSaleHandler handler;

    function setUp() public {
        asset = new ERC20();
        anDola = new MockAnDola();
        handler = new DolaSaleHandler(
            address(asset),
            address(anDola),
            address(1),
            address(2)
        );
    }

    function test_constructor() public {
        assertEq(address(handler.asset()), address(asset));
        assertEq(address(handler.anDola()), address(anDola));
        assertEq(handler.borrower1(), address(1));
        assertEq(handler.borrower2(), address(2));
        assertEq(asset.allowance(address(handler), address(anDola)), type(uint).max);
    }

    function test_onReceiveBorrower1(uint amount) public {
        amount = bound(amount, 1, type(uint).max / 2);
        asset.mint(address(handler), amount);
        anDola.setBorrowBalance(address(1), amount);
        handler.onReceive();
        assertEq(anDola.borrower(), address(1));
        assertEq(anDola.repayAmount(), amount);
    }

    function test_onReceiveBorrower2(uint amount) public {
        amount = bound(amount, 1, type(uint).max / 2);
        asset.mint(address(handler), amount);
        anDola.setBorrowBalance(address(2), amount);
        handler.onReceive();
        assertEq(anDola.borrower(), address(2));
        assertEq(anDola.repayAmount(), amount);
    }

    function test_getCapacity(uint debt1, uint debt2) public {
        debt1 = bound(debt1, 1, type(uint).max / 2);
        debt2 = bound(debt2, 1, type(uint).max / 2);
        anDola.setBorrowBalance(address(1), debt1);
        anDola.setBorrowBalance(address(2), debt2);
        assertEq(handler.getCapacity(), debt1 + debt2);
    }

}
