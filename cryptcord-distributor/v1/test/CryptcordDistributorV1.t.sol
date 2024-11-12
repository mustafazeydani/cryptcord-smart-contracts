// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CryptcordDistributorV1, CryptcordDistributorV1__InvalidFeePercentage} from "../src/CryptcordDistributorV1.sol";
import {DeployCryptcordDistributorV1} from "../script/DeployCryptcordDistributorV1.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CryptcordDistributorV1Test is Test {
    CryptcordDistributorV1 private s_cryptcordDistributorV1;

    function setUp() public {
        address[] memory supportedTokens = new address[](0);
        s_cryptcordDistributorV1 = new CryptcordDistributorV1(supportedTokens);
    }

    // ================================================================
    // │                    setFeePercentage() Tests                  │
    // ================================================================

    function testSetFeePercentageNotOwner() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.setFeePercentage(0);
    }

    function testSetFeePercentageInvalidFeePercentage() public {
        uint256 invalidFeePercentage = s_cryptcordDistributorV1.getScaleFactor() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CryptcordDistributorV1__InvalidFeePercentage.selector, s_cryptcordDistributorV1.getScaleFactor() + 1
            )
        );
        s_cryptcordDistributorV1.setFeePercentage(invalidFeePercentage);
    }

    function testSetFeePercentage() public {
        uint256 newFeePercentage = 50;
        s_cryptcordDistributorV1.setFeePercentage(newFeePercentage);
        uint256 actualFeePercentage = s_cryptcordDistributorV1.getFeePercentage();
        vm.assertEq(newFeePercentage, actualFeePercentage);
    }

    // ===========================================================================
    // │ addSupportedToken() - removeSupportedToken() - isTokenSupported() Tests │
    // ===========================================================================

    function testAddSupportedTokenNotOwner() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.addSupportedToken(address(0));
    }

    function testAddSupportedToken() public {
        address supportedToken = address(1);
        s_cryptcordDistributorV1.addSupportedToken(supportedToken);
        bool isSupportedToken = s_cryptcordDistributorV1.isTokenSupported(supportedToken);
        vm.assertEq(true, isSupportedToken);
    }

    function testRemoveSupportedTokenNotOwner() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.removeSupportedToken(address(0));
    }

    function testRemoveSupportedToken() public {
        address supportedToken = address(1);
        s_cryptcordDistributorV1.addSupportedToken(supportedToken);
        s_cryptcordDistributorV1.removeSupportedToken(supportedToken);
        bool isSupportedToken = s_cryptcordDistributorV1.isTokenSupported(supportedToken);
        vm.assertEq(false, isSupportedToken);
    }
}
