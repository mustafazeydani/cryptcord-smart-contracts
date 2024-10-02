// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CryptcordDistributorV1} from "../src/CryptcordDistributorV1.sol";

contract DeployCryptcordDistributorV1 is Script {
    function run() external returns (CryptcordDistributorV1) {
        vm.startBroadcast();
        CryptcordDistributorV1 cryptcordDistributorV1 = new CryptcordDistributorV1();
        vm.stopBroadcast();
        return cryptcordDistributorV1;
    }
}