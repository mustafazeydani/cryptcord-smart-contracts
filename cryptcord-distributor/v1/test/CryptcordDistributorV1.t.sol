// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {
    CryptcordDistributorV1,
    CryptcordDistributorV1__InvalidFeePercentage,
    CryptcordDistributorV1__TokenNotSupported,
    TokensTransferred
} from "../src/CryptcordDistributorV1.sol";
import {DeployCryptcordDistributorV1} from "../script/DeployCryptcordDistributorV1.s.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20MockUSDT} from "../src/mocks/ERC20MockUSDT.sol";
import {console} from "forge-std/console.sol";

contract CryptcordDistributorV1Test is Test {
    CryptcordDistributorV1 private s_cryptcordDistributorV1;
    ERC20MockUSDT private s_erc20MockUSDT;

    function getDistributeTokensArgs()
        internal
        view
        returns (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId)
    {
        // In these tests, sender is address(1) and receiver is address(2)
        return (
            address(s_erc20MockUSDT), 1 * 10 ** s_erc20MockUSDT.decimals(), address(1), address(2), bytes16(uint128(4))
        );
    }

    function setUp() public {
        address[] memory supportedTokens = new address[](0);
        uint256 initialSupply = 1_000_000;

        s_cryptcordDistributorV1 = new CryptcordDistributorV1(supportedTokens);
        s_erc20MockUSDT = new ERC20MockUSDT(initialSupply);

        // Distribute half of the initial supply to the sender address
        (,, address from,,) = getDistributeTokensArgs();
        s_erc20MockUSDT.transfer(from, (initialSupply / 2) * 10 ** s_erc20MockUSDT.decimals());
    }

    // ================================================================
    // │                    setFeePercentage() Tests                  │
    // ================================================================

    modifier ownerNotNullAddress() {
        vm.assertNotEq(s_cryptcordDistributorV1.owner(), address(0), "Owner address is set to address(0)");
        _;
    }

    function testSetFeePercentageNotOwner() public ownerNotNullAddress {
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
        vm.assertEq(newFeePercentage, actualFeePercentage, "Fee percentage not set correctly");
    }

    // ===========================================================================
    // │ addSupportedToken() - removeSupportedToken() - isTokenSupported() Tests │
    // ===========================================================================

    function testAddSupportedTokenNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.addSupportedToken(address(0));
    }

    function testAddSupportedToken() public {
        s_cryptcordDistributorV1.addSupportedToken(address(s_erc20MockUSDT));
        bool isSupportedToken = s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isSupportedToken, "Token not added");
    }

    function testRemoveSupportedTokenNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.removeSupportedToken(address(0));
    }

    function testRemoveSupportedToken() public {
        s_cryptcordDistributorV1.addSupportedToken(address(s_erc20MockUSDT));
        bool isTokenAdded = s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isTokenAdded, "Token not added");
        s_cryptcordDistributorV1.removeSupportedToken(address(s_erc20MockUSDT));
        bool isTokenRemoved = !s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isTokenRemoved, "Token not removed");
    }

    // ================================================================
    // │                    distributeTokens Tests                    │
    // ================================================================

    struct TransferResult {
        uint256 amountSent;
        uint256 fee;
    }

    function transferTokens() internal returns (TransferResult memory result) {
        (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId) = getDistributeTokensArgs();

        // Add erc20Address to supported tokens
        s_cryptcordDistributorV1.addSupportedToken(erc20Address);

        // Prank sender and approve tokens to distributor
        vm.prank(from);
        s_erc20MockUSDT.approve(address(s_cryptcordDistributorV1), amount);

        // Distribute tokens
        s_cryptcordDistributorV1.distributeTokens(erc20Address, amount, from, to, paymentId);

        // Calculate fee and amount sent
        uint256 fee = (amount * s_cryptcordDistributorV1.getFeePercentage()) / s_cryptcordDistributorV1.getScaleFactor();
        result.amountSent = amount - fee;
        result.fee = fee;
    }

    function testDistributeTokensTokenNotSupported() public {
        (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId) = getDistributeTokensArgs();

        // Expect revert (current supported tokens array is empty)
        vm.expectRevert(abi.encodeWithSelector(CryptcordDistributorV1__TokenNotSupported.selector, erc20Address));

        s_cryptcordDistributorV1.distributeTokens(erc20Address, amount, from, to, paymentId);
    }

    function testDistributeTokensFeeSentToOwner() public {
        // Get owner balance before transfer
        uint256 ownerBalanceBefore = s_erc20MockUSDT.balanceOf(s_cryptcordDistributorV1.owner());

        // Transfer tokens and calculate fee
        TransferResult memory result = transferTokens();

        // Get owner balance after transfer
        uint256 ownerBalanceAfter = s_erc20MockUSDT.balanceOf(s_cryptcordDistributorV1.owner());

        // Check if fee was sent to owner
        vm.assertEq(ownerBalanceBefore + result.fee, ownerBalanceAfter, "Fee not sent to owner");
    }

    function testDistributeTokensAmountSentToReceiver() public {
        // Transfer tokens and calculate fee
        TransferResult memory result = transferTokens();

        // Check if amount was sent to receiver
        uint256 receiverBalance = s_erc20MockUSDT.balanceOf(address(2));

        // Check if amount was sent to receiver
        vm.assertEq(result.amountSent, receiverBalance, "Amount not sent to receiver");
    }
}
