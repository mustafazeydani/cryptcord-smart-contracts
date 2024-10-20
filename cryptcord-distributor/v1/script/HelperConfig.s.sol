// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";

abstract contract Constants {
    // ================================================================
    // │                             Chain IDs                        │
    // ================================================================
    uint256 public constant ANVIL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant MAINNET_CHAIN_ID = 1;
    uint256 public constant BSC_CHAIN_ID = 56;
    uint256 public constant POLYGON_CHAIN_ID = 137;
}

// ================================================================
// │                             Types                            │
// ================================================================

abstract contract Types {
    struct NetworkConfig {
        bool isInitialized;
        address[] supportedTokens;
    }
}

// ================================================================
// │                             Errors                           │
// ================================================================

error HelperConfig__InvalidChainId();

contract HelperConfig is Constants, Types, Script {
    // ================================================================
    // │                         State Variables                      │
    // ================================================================

    NetworkConfig private s_localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) private s_networkConfigs;

    // ================================================================
    // │                         Constructor                          │
    // ================================================================

    constructor() {
        s_networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaConfig();
        s_networkConfigs[MAINNET_CHAIN_ID] = getMainnetConfig();
        s_networkConfigs[BSC_CHAIN_ID] = getBSCConfig();
        s_networkConfigs[POLYGON_CHAIN_ID] = getPolygonConfig();
    }

    // ================================================================
    // │                             Config                           │
    // ================================================================

    function getOrCreateAnvilConfig()
        public
        pure
        returns (NetworkConfig memory)
    {}

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = 0xaA8E23Fb1079EA71e0a56F48a2aA51851D8433D0; // USDT
        tokens[1] = 0xf08A50178dfcDe18524640EA6618a1f965821715; // USDC
        return NetworkConfig({isInitialized: true, supportedTokens: tokens});
    }

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        tokens[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        return NetworkConfig({isInitialized: true, supportedTokens: tokens});
    }

    function getBSCConfig() public pure returns (NetworkConfig memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = 0x55d398326f99059fF775485246999027B3197955; // USDT
        tokens[1] = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d; // USDC
        return NetworkConfig({isInitialized: true, supportedTokens: tokens});
    }

    function getPolygonConfig() public pure returns (NetworkConfig memory) {
        address[] memory tokens = new address[](2);
        tokens[0] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT
        tokens[1] = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359; // USDC
        return NetworkConfig({isInitialized: true, supportedTokens: tokens});
    }

    function getConfigByChainId(
        uint256 chainId
    ) public view returns (NetworkConfig memory) {
        if (s_networkConfigs[chainId].isInitialized) {
            return s_networkConfigs[chainId];
        } else if (chainId == ANVIL_CHAIN_ID) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
}
