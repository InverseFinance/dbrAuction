// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {Auction} from "../src/Auction.sol";
import {Helper} from "../src/Helper.sol";

contract AuctionMainnetDeployerScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Optional: specify a handler address to deploy with
        address handler = address(0);

        address gov = 0x926dF14a23BE491164dCF93f4c468A50ef659D5B;
        address fedChair = 0x8F97cCA30Dbe80e7a8B462F1dD1a51C32accDfC8;
        address dola = 0x865377367054516e17014CcdED1e7d814EDC9ce4;
        address dbr = 0xAD038Eb671c44b853887A7E32528FaB35dC5D710;

        // 5:1 ratio, implying a 20c DBR starting price
        uint dolaReserve = 500_000 * 1e18;
        uint dbrReserve = dolaReserve * 5;
        
        Auction auction = new Auction(
            gov,
            fedChair,
            dbr,
            dola,
            handler,
            dolaReserve,
            dbrReserve
        );

        new Helper(
            address(auction),
            address(dola)
        );
    }
}
