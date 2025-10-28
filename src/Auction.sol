// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IERC20 {
    function transfer(address,uint) external returns (bool);
    function transferFrom(address,address,uint) external returns (bool);
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

    address public gov;
    address public operator;
    IDBR public immutable dbr;
    IERC20 public immutable asset;
    ISaleHandler public saleHandler;
    uint public assetReserve;
    uint public dbrReserve;
    uint public dbrRatePerYear;
    uint public maxDbrRatePerYear;
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
        maxDbrRatePerYear = _maxRate;
        emit MaxRateUpdate(_maxRate);
        if(dbrRatePerYear > _maxRate) {
            dbrRatePerYear = _maxRate;
            emit RateUpdate(_maxRate);
        }
    }

    function setDbrRatePerYear(uint _rate) external onlyGovOrOperator updateReserves {
        require(_rate <= maxDbrRatePerYear, "Rate exceeds max");
        dbrRatePerYear = _rate;
        emit RateUpdate(_rate);
    }

    function setAssetReserve(uint _assetReserve) external onlyGov updateReserves {
        require(_assetReserve > 0, "Asset reserve must be positive");
        uint newDbrReserve = _assetReserve * dbrReserve / assetReserve;
        require(newDbrReserve > 0, "Resulting DBR reserve must be positive");
        assetReserve = _assetReserve;
        dbrReserve = newDbrReserve;
    }

    function setDbrReserve(uint _dbrReserve) external onlyGov updateReserves {
        require(_dbrReserve > 0, "DBR reserve must be positive");
        uint newAssetReserve = _dbrReserve * assetReserve / dbrReserve;
        require(newAssetReserve > 0, "Resulting asset reserve must be positive");
        dbrReserve = _dbrReserve;
        assetReserve = newAssetReserve;
    }

    function overrideReserves(uint _dbrReserve, uint _assetReserve) external onlyGov {
        require(_assetReserve > 0, "Asset reserve must be positive");
        require(_dbrReserve > 0, "DBR reserve must be positive");
        assetReserve = _assetReserve;
        dbrReserve = _dbrReserve;
        lastUpdate = block.timestamp;
    }

    function buyDBR(uint exactAssetIn, uint exactDbrOut, address to) external updateReserves {
        uint K = assetReserve * dbrReserve;
        assetReserve += exactAssetIn;
        dbrReserve -= exactDbrOut;
        require(assetReserve * dbrReserve >= K, "Invariant");
        asset.transferFrom(msg.sender, address(this), exactAssetIn);
        dbr.mint(to, exactDbrOut);
        emit Buy(msg.sender, to, exactAssetIn, exactDbrOut);
    }

    function sendToSaleHandler() public {
        require(address(saleHandler) != address(0), "No sale handler");
        uint bal = asset.balanceOf(address(this));
        require(bal > 0, "No asset to send");
        uint capacity = saleHandler.getCapacity();
        uint amount = bal > capacity ? capacity : bal;
        asset.transfer(address(saleHandler), amount);
        saleHandler.onReceive();
    }

    function sweep(address token, address destination, uint amount) external onlyGov {
        IERC20(token).transfer(destination, amount);
    }

    event Buy(address indexed caller, address indexed to, uint assetIn, uint dbrOut);
    event RateUpdate(uint newRate);
    event MaxRateUpdate(uint newMaxRate);
}
