// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig, Types} from "./HelperConfig.s.sol";
import {CryptcordDistributorV1} from "../src/CryptcordDistributorV1.sol";

contract DeployCryptcordDistributorV1 is Script, Types {
    function deployCryptcordDistributerV1() public returns (CryptcordDistributorV1) {
        HelperConfig helperConfig = new HelperConfig();
        address[] memory supportedTokens = helperConfig.getConfigByChainId(block.chainid).supportedTokens;
        vm.startBroadcast();
        CryptcordDistributorV1 cryptcordDistributorV1 = new CryptcordDistributorV1(supportedTokens);
        vm.stopBroadcast();
        return cryptcordDistributorV1;
    }

    function run() external returns (CryptcordDistributorV1) {
        return deployCryptcordDistributerV1();
    }
}
