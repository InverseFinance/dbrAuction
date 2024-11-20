// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IERC20 {
    function approve(address,uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function transfer(address,uint) external returns (bool);
}

interface IAnDola {
    function repayBorrowBehalf(address borrower, uint repayAmount) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint); // stored is good enough for our use case
}

contract SaleHandler {

    address public owner;
    address public beneficiary;
    IERC20 public immutable dola;
    IAnDola public immutable anDola;
    address public immutable borrower1;
    address public immutable borrower2;
    uint public repayBps;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        address _owner,
        address _beneficiary,
        uint _repayBps,
        address _dola,
        address _anDola,
        address _borrower1,
        address _borrower2
    ) {
        require(_repayBps <= 10000, "Repay bps must be less than or equal to 10000");
        owner = _owner;
        beneficiary = _beneficiary;
        repayBps = _repayBps;
        dola = IERC20(_dola);
        anDola = IAnDola(_anDola);
        borrower1 = _borrower1;
        borrower2 = _borrower2;
        dola.approve(_anDola,type(uint).max);
    }

    function onReceive() external {
        require(repayBps == 10000 || beneficiary != address(0), "Either all goes to repayment or beneficiary must be set");
        uint bal = dola.balanceOf(address(this));
        uint repayment = bal * repayBps / 10000;
        uint debt1 = getDebtOf(borrower1);
        uint debt2 = getDebtOf(borrower2);
        if(debt1 > debt2) {
            uint errCode = anDola.repayBorrowBehalf(borrower1, repayment);
            if(errCode > 0) require(anDola.repayBorrowBehalf(borrower2, repayment) == 0, "Failed to repay");
        } else {
            uint errCode = anDola.repayBorrowBehalf(borrower2, repayment);
            if(errCode > 0) require(anDola.repayBorrowBehalf(borrower1, repayment) == 0, "Failed to repay");
        }

        uint remaining = dola.balanceOf(address(this));
        if(remaining > 0) dola.transfer(beneficiary, remaining);
    }

    function getDebtOf(address borrower) internal view returns (uint) {
        return anDola.borrowBalanceStored(borrower);
    }

    function getCapacity() external view returns (uint) {
        return getDebtOf(borrower1) + getDebtOf(borrower2) - dola.balanceOf(address(this));
    }

    function setOwner(address _owner) external onlyOwner { owner = _owner; }

    function setBeneficiary(address _beneficiary) external onlyOwner { beneficiary = _beneficiary; }

    function setRepayBps(uint _repayBps) external onlyOwner {
        require(_repayBps <= 10000, "Repay bps must be less than or equal to 10000");
        repayBps = _repayBps;
    }

}