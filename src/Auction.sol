// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint);
}

interface IDBR is IERC20 {
    function mint(address,uint) external;
}

interface ISaleHandler {
    function onReceive() external;
    function getCapacity() external view returns (uint);
}

contract Auction {

    using SafeTransferLib for address;

    address public gov;
    address public operator;
    IDBR public immutable dbr;
    IERC20 public immutable asset;
    ISaleHandler public saleHandler;
    uint public assetReserve;
    uint public dbrReserve;
    uint public dbrRatePerYear;
    uint public minDbrRatePerYear;
    uint public maxDbrRatePerYear = type(uint).max;
    uint public lastUpdate;
    
    constructor (
        address _gov,
        address _operator,
        address _dbr,
        address _asset,
        address handler,
        uint _assetReserve,
        uint _dbrReserve
    ) {
        require(_assetReserve > 0, "Asset reserve must be positive");
        require(_dbrReserve > 0, "DBR reserve must be positive");
        gov = _gov;
        operator = _operator;
        dbr = IDBR(_dbr);
        asset = IERC20(_asset);
        saleHandler = ISaleHandler(handler);
        assetReserve = _assetReserve;
        dbrReserve = _dbrReserve;
    }

    modifier updateReserves {
        (assetReserve, dbrReserve) = getCurrentReserves();
        lastUpdate = block.timestamp;
        _;
    }

    modifier onlyGov {
        require(msg.sender == gov, "onlyGov");
        _;
    }

    modifier onlyGovOrOperator {
        require(msg.sender == operator || msg.sender == gov, "onlyGov");
        _;
    }

    function getCurrentReserves() public view returns (uint _assetReserve, uint _dbrReserve) {
        uint timeElapsed = block.timestamp - lastUpdate;
        if(timeElapsed > 0) {
            uint K = assetReserve * dbrReserve;
            uint DbrsIn = timeElapsed * dbrRatePerYear / 365 days;
            _dbrReserve = dbrReserve + DbrsIn;
            _assetReserve = K / _dbrReserve;
        } else {
            _assetReserve = assetReserve;
            _dbrReserve = dbrReserve;
        }
    }

    function setGov(address _gov) external onlyGov { gov = _gov; }
    function setOperator(address _operator) external onlyGov { operator = _operator; }
    function setSaleHandler(address _saleHandler) external onlyGov { saleHandler = ISaleHandler(_saleHandler); }

    function setMaxDbrRatePerYear(uint _maxRate) external onlyGov updateReserves {
        require(_maxRate >= minDbrRatePerYear, "Max below min");
        maxDbrRatePerYear = _maxRate;
        emit MaxRateUpdate(_maxRate);
        if(dbrRatePerYear > _maxRate) {
            dbrRatePerYear = _maxRate;
            emit RateUpdate(_maxRate);
        }
    }

    function setMinDbrRatePerYear(uint _minRate) external onlyGov updateReserves {
        require(_minRate <= maxDbrRatePerYear, "Min above max");
        minDbrRatePerYear = _minRate;
        emit MinRateUpdate(_minRate);
        if(dbrRatePerYear < _minRate) {
            dbrRatePerYear = _minRate;
            emit RateUpdate(_minRate);
        }
    }

    function setDbrRatePerYear(uint _rate) external onlyGovOrOperator updateReserves {
        require(_rate <= maxDbrRatePerYear, "Rate exceeds max");
        require(_rate >= minDbrRatePerYear, "Rate below min");
        dbrRatePerYear = _rate;
        emit RateUpdate(_rate);
    }

    // changes K to preserve the ratio (price)
    function setAssetReserve(uint _assetReserve) external onlyGov updateReserves {
        require(_assetReserve > 0, "Asset reserve must be positive");
        uint newDbrReserve = _assetReserve * dbrReserve / assetReserve;
        require(newDbrReserve > 0, "Resulting DBR reserve must be positive");
        assetReserve = _assetReserve;
        dbrReserve = newDbrReserve;
        emit SetAssetReserve(_assetReserve, newDbrReserve);
    }

    // changes K to preserve the ratio (price)
    function setDbrReserve(uint _dbrReserve) external onlyGov updateReserves {
        require(_dbrReserve > 0, "DBR reserve must be positive");
        uint newAssetReserve = _dbrReserve * assetReserve / dbrReserve;
        require(newAssetReserve > 0, "Resulting asset reserve must be positive");
        dbrReserve = _dbrReserve;
        assetReserve = newAssetReserve;
        emit SetDbrReserve(_dbrReserve, newAssetReserve);
    }

    function overrideReserves(uint _dbrReserve, uint _assetReserve) external onlyGov {
        require(_assetReserve > 0, "Asset reserve must be positive");
        require(_dbrReserve > 0, "DBR reserve must be positive");
        assetReserve = _assetReserve;
        dbrReserve = _dbrReserve;
        lastUpdate = block.timestamp;
        emit OverrideReserves(_assetReserve, _dbrReserve);
    }

    function buyDBR(uint exactAssetIn, uint exactDbrOut, address to) external updateReserves {
        uint K = assetReserve * dbrReserve;
        assetReserve += exactAssetIn;
        dbrReserve -= exactDbrOut;
        require(assetReserve * dbrReserve >= K, "Invariant");
        address(asset).safeTransferFrom(msg.sender, address(this), exactAssetIn);
        dbr.mint(to, exactDbrOut);
        emit Buy(msg.sender, to, exactAssetIn, exactDbrOut);
    }

    function sendToSaleHandler() public {
        require(address(saleHandler) != address(0), "No sale handler");
        uint bal = asset.balanceOf(address(this));
        require(bal > 0, "No asset to send");
        uint capacity = saleHandler.getCapacity();
        uint amount = bal > capacity ? capacity : bal;
        address(asset).safeTransfer(address(saleHandler), amount);
        saleHandler.onReceive();
        emit SendToSaleHandler(amount);
    }

    // only if no sale handler is set
    function sendToGov() public {
        require(address(saleHandler) == address(0), "Sale handler set");
        uint bal = asset.balanceOf(address(this));
        require(bal > 0, "No asset to send");
        address(asset).safeTransfer(gov, bal);
        emit SendToGov(bal);
    }

    function sweep(address token, address destination, uint amount) external onlyGov {
        token.safeTransfer(destination, amount);
    }

    event Buy(address indexed caller, address indexed to, uint assetIn, uint dbrOut);
    event SetAssetReserve(uint assetReserve, uint dbrReserve);
    event SetDbrReserve(uint dbrReserve, uint assetReserve);
    event OverrideReserves(uint assetReserve, uint dbrReserve);
    event SendToSaleHandler(uint amount);
    event SendToGov(uint amount);
    event RateUpdate(uint newRate);
    event MaxRateUpdate(uint newMaxRate);
    event MinRateUpdate(uint newMinRate);
}
