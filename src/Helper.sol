// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IAuction {
    function getCurrentReserves() external view returns (uint assetReserve, uint dbrReserve);
    function buyDBR(uint exactAssetIn, uint exactDbrOut, address to) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint);
}

contract Helper {

    using SafeTransferLib for address;

    IAuction public immutable auction;
    IERC20 public immutable asset;

    constructor(
        address _auction,
        address _asset
    ) {
        auction = IAuction(_auction);
        asset = IERC20(_asset);
        address(asset).safeApprove(_auction, type(uint).max);
    }
    
    function getDbrOut(uint assetIn) public view returns (uint dbrOut) {
        require(assetIn > 0, "assetIn must be positive");
        (uint assetReserve, uint dbrReserve) = auction.getCurrentReserves();
        uint numerator = assetIn * dbrReserve;
        uint denominator = assetReserve + assetIn;
        dbrOut = numerator / denominator;
    }

    function getAssetIn(uint dbrOut) public view returns (uint assetIn) {
        require(dbrOut > 0, "dbrOut must be positive");
        (uint assetReserve, uint dbrReserve) = auction.getCurrentReserves();
        uint numerator = dbrOut * assetReserve;
        uint denominator = dbrReserve - dbrOut;
        assetIn = (numerator / denominator) + 1;
    }

    function swapExactAssetForDbr(uint assetIn, uint dbrOutMin) external returns (uint dbrOut) {
        dbrOut = getDbrOut(assetIn);
        require(dbrOut >= dbrOutMin, "dbrOut must be greater than dbrOutMin");
        address(asset).safeTransferFrom(msg.sender, address(this), assetIn);
        auction.buyDBR(assetIn, dbrOut, msg.sender);
    }

    function swapAssetForExactDbr(uint dbrOut, uint assetInMax) external returns (uint assetIn) {
        assetIn = getAssetIn(dbrOut);
        require(assetIn <= assetInMax, "assetIn must be less than assetInMax");
        address(asset).safeTransferFrom(msg.sender, address(this), assetIn);
        auction.buyDBR(assetIn, dbrOut, msg.sender);
    }

}