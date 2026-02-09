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
        address twg = 0x9D5Df30F475CEA915b1ed4C0CCa59255C897b61B;
        address asset = 0x41D5D79431A913C4aE7d69a668ecdfE5fF9DFB68;
        address dbr = 0xAD038Eb671c44b853887A7E32528FaB35dC5D710;

        // 400:1 ratio, implying a 5c DBR starting price ($20 INV / 400 = $0.05 DBR)
        uint assetReserve = 1_250 * 1e18;
        uint dbrReserve = assetReserve * 400; // 500_000 DBR

        Auction auction = new Auction(
            gov,
            twg,
            dbr,
            asset,
            handler,
            assetReserve,
            dbrReserve
        );

        new Helper(
            address(auction),
            address(asset)
        );
    }
}
