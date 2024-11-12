// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {CryptcordDistributorV1, CryptcordDistributorV1__InvalidFeePercentage} from "../src/CryptcordDistributorV1.sol";
import {DeployCryptcordDistributorV1} from "../script/DeployCryptcordDistributorV1.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CryptcordDistributorV1Test is Test {
    CryptcordDistributorV1 private s_cryptcordDistributorV1;

    modifier setContractOwner() {
        vm.startPrank(s_cryptcordDistributorV1.owner());
        _;
        vm.stopPrank();
    }

    function setUp() public {
        DeployCryptcordDistributorV1 deployScript = new DeployCryptcordDistributorV1();
        s_cryptcordDistributorV1 = deployScript.deployCryptcordDistributerV1();
    }

    function testSetFeePercentageNotOwner() public {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.setFeePercentage(0);
    }

    function testSetFeePercentageInvalidFeePercentage() public setContractOwner {
        uint256 invalidFeePercentage = s_cryptcordDistributorV1.getScaleFactor() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CryptcordDistributorV1__InvalidFeePercentage.selector, s_cryptcordDistributorV1.getScaleFactor() + 1
            )
        );
        s_cryptcordDistributorV1.setFeePercentage(invalidFeePercentage);
    }

    function testSetFeePercentage() public setContractOwner {
        uint256 newFeePercentage = 50;
        s_cryptcordDistributorV1.setFeePercentage(newFeePercentage);
        uint256 actualFeePercentage = s_cryptcordDistributorV1.getFeePercentage();
        vm.assertEq(newFeePercentage, actualFeePercentage);
    }
}
