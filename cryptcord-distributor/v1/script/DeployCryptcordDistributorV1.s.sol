// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {CryptcordDistributorV1} from "../src/CryptcordDistributorV1.sol";

contract DeployCryptcordDistributorV1 is Script {
    function run() external returns (CryptcordDistributorV1) {
        address[] memory supportedTokens = new address[](1);
        supportedTokens[0] = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0;
        vm.startBroadcast();
        CryptcordDistributorV1 cryptcordDistributorV1 = new CryptcordDistributorV1(supportedTokens);
        vm.stopBroadcast();
        return cryptcordDistributorV1;
    }
}
