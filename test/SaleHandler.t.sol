// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {SaleHandler} from "../src/SaleHandler.sol";
import {ERC20} from "./mocks/ERC20.sol";

contract MockAnDola {

    ERC20 public dola;
    mapping(address => uint) public borrowBalanceStored;
    address public borrower;
    uint public repayAmount;

    constructor(ERC20 _dola) {
        dola = _dola;
    }

    function repayBorrowBehalf(address _borrower, uint _repayAmount) external returns (uint) {
        require(_repayAmount <= borrowBalanceStored[_borrower], "Insufficient debt");
        borrower = _borrower;
        repayAmount = _repayAmount;
        dola.transferFrom(msg.sender, address(this), _repayAmount);
        return 0;
    }

    function setBorrowBalance(address _borrower, uint value) external {
        borrowBalanceStored[_borrower] = value;
    }
    
    
}

contract SaleHandlerTest is Test {

    ERC20 dola;
    MockAnDola anDola;
    SaleHandler handler;

    address immutable OWNER = address(this);
    address constant BENEFICIARY = address(1);
    address constant BORROWER1 = address(2);
    address constant BORROWER2 = address(3);
    address constant NON_OWNER = address(4);
    address constant NEW_OWNER = address(5);
    address constant NEW_BENEFICIARY = address(6);
    uint256 constant INITIAL_REPAY_BPS = 10000;

    function setUp() public {
        dola = new ERC20();
        anDola = new MockAnDola(dola);
        handler = new SaleHandler(
            OWNER,
            BENEFICIARY,
            INITIAL_REPAY_BPS,
            address(dola),
            address(anDola),
            BORROWER1,
            BORROWER2
        );
    }

    function test_constructor() public {
        assertEq(address(handler.dola()), address(dola));
        assertEq(address(handler.anDola()), address(anDola));
        assertEq(handler.borrower1(), BORROWER1);
        assertEq(handler.borrower2(), BORROWER2);
        assertEq(handler.repayBps(), INITIAL_REPAY_BPS);
        assertEq(handler.owner(), OWNER);
        assertEq(handler.beneficiary(), BENEFICIARY);
        assertEq(dola.allowance(address(handler), address(anDola)), type(uint).max);
    }

    function test_onReceiveBorrower1(uint amount) public {
        amount = bound(amount, 1, type(uint128).max);
        dola.mint(address(handler), amount);
        anDola.setBorrowBalance(BORROWER1, amount);
        handler.onReceive();
        assertEq(anDola.borrower(), BORROWER1);
        assertEq(anDola.repayAmount(), amount);
    }

    function test_onReceiveBorrower2(uint amount) public {
        amount = bound(amount, 1, type(uint128).max);
        dola.mint(address(handler), amount);
        anDola.setBorrowBalance(BORROWER2, amount);
        handler.onReceive();
        assertEq(anDola.borrower(), BORROWER2);
        assertEq(anDola.repayAmount(), amount);
    }

    function test_onReceiveWithBeneficiary(uint amount) public {
        amount = bound(amount, 1, type(uint128).max);
        handler.setRepayBps(5000);
        
        dola.mint(address(handler), amount);

        uint repayAmount = amount / 2;
        anDola.setBorrowBalance(BORROWER1, repayAmount);
        
        handler.onReceive();
        
        uint beneficiaryAmount = amount - repayAmount;
        assertEq(dola.balanceOf(BENEFICIARY), beneficiaryAmount);
    }

    function test_getCapacity(uint debt1, uint debt2) public {
        debt1 = bound(debt1, 1, type(uint128).max);
        debt2 = bound(debt2, 1, type(uint128).max);
        anDola.setBorrowBalance(BORROWER1, debt1);
        anDola.setBorrowBalance(BORROWER2, debt2);
        assertEq(handler.getCapacity(), debt1 + debt2);
    }

    function test_setOwner() public {
        handler.setOwner(NEW_OWNER);
        assertEq(handler.owner(), NEW_OWNER);
    }

    function test_setBeneficiary() public {
        handler.setBeneficiary(NEW_BENEFICIARY);
        assertEq(handler.beneficiary(), NEW_BENEFICIARY);
    }

    function test_setRepayBps() public {
        handler.setRepayBps(5000);
        assertEq(handler.repayBps(), 5000);
    }

    function test_fail_setRepayBpsAbove10000() public {
        vm.expectRevert("Repay bps must be less than or equal to 10000");
        handler.setRepayBps(10001);
    }

    function test_fail_onReceiveWithoutBeneficiary() public {
        handler.setRepayBps(5000);
        handler.setBeneficiary(address(0));
        dola.mint(address(handler), 100);
        vm.expectRevert("Either all goes to repayment or beneficiary must be set");
        handler.onReceive();
    }

    function test_fail_onlyOwnerCanSetOwner() public {
        vm.prank(NON_OWNER);
        vm.expectRevert("Only owner can call this function");
        handler.setOwner(NEW_OWNER);
    }

    function test_fail_onlyOwnerCanSetBeneficiary() public {
        vm.prank(NON_OWNER);
        vm.expectRevert("Only owner can call this function");
        handler.setBeneficiary(NEW_BENEFICIARY);
    }

    function test_fail_onlyOwnerCanSetRepayBps() public {
        vm.prank(NON_OWNER);
        vm.expectRevert("Only owner can call this function");
        handler.setRepayBps(5000);
    }
}
