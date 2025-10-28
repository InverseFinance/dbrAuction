// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {DolaSaleHandler} from "../src/DolaSaleHandler.sol";
import {Auction} from "../src/Auction.sol";
import {Helper} from "../src/Helper.sol";

contract DolaSaleHandlerMainnetDeployerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address anDola = 0x7Fcb7DAC61eE35b3D4a51117A7c58D53f0a8a670;
        address asset = 0x865377367054516e17014CcdED1e7d814EDC9ce4;
        address borrower1 = 0xf508c58ce37ce40a40997C715075172691F92e2D;
        address borrower2 = 0xeA0c959BBb7476DDD6cD4204bDee82b790AA1562;

        DolaSaleHandler handler = new DolaSaleHandler(
            asset,
            anDola,
            borrower1,
            borrower2
        );

    }
}
