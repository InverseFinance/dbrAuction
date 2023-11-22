// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {SaleHandler} from "../src/SaleHandler.sol";
import {Auction} from "../src/Auction.sol";

contract MainnetDeployerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address gov = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
        address fedChair = 0x8F97cCA30Dbe80e7a8B462F1dD1a51C32accDfC8;
        address anDola = 0x7Fcb7DAC61eE35b3D4a51117A7c58D53f0a8a670;
        address dola = 0x865377367054516e17014CcdED1e7d814EDC9ce4;
        address dbr = 0xAD038Eb671c44b853887A7E32528FaB35dC5D710;
        address borrower1 = 0xf508c58ce37ce40a40997C715075172691F92e2D;
        address borrower2 = 0xeA0c959BBb7476DDD6cD4204bDee82b790AA1562;

        // 5:1 ratio, implying a 20c DBR starting price
        uint dolaReserve = 500_000 * 1e18;
        uint dbrReserve = 2_500_000 * 1e18;

        SaleHandler handler = new SaleHandler(
            dola,
            anDola,
            borrower1,
            borrower2
        );

        new Auction(
            gov,
            fedChair,
            dbr,
            dola,
            address(handler),
            dolaReserve,
            dbrReserve
        );
    }
}
