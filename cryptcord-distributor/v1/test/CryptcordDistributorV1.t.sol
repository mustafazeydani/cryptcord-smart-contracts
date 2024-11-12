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

/**
 * @notice In these tests, owner is address(1), sender is address(2) and receiver is address(3)
 */
contract CryptcordDistributorV1Test is Test {
    address private s_owner = address(1);
    CryptcordDistributorV1 private s_cryptcordDistributorV1;
    ERC20MockUSDT private s_erc20MockUSDT;

    /**
     * @notice Get arguments for distributeTokens function
     */
    function getDistributeTokensArgs()
        internal
        view
        returns (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId)
    {
        return (
            address(s_erc20MockUSDT), 1 * 10 ** s_erc20MockUSDT.decimals(), address(2), address(3), bytes16(uint128(4))
        );
    }

    // ================================================================
    // │                           Modifiers                          │
    // ================================================================

    modifier setOwner() {
        vm.startPrank(s_owner);
        _;
        vm.stopPrank();
    }

    modifier ownerNotNullAddress() {
        vm.assertNotEq(s_owner, address(0), "Owner is address(0)");
        _;
    }

    // ================================================================
    // │                           Setup                              │
    // ================================================================

    /**
     * @notice Set up the test environment
     */
    function setUp() public setOwner {
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

    /**
     * @notice Test setFeePercentage function when the caller is not the owner
     */
    function testSetFeePercentageNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.setFeePercentage(0);
    }

    /**
     * @notice Test setFeePercentage function when the fee percentage is invalid
     */
    function testSetFeePercentageInvalidFeePercentage() public setOwner {
        uint256 invalidFeePercentage = s_cryptcordDistributorV1.getScaleFactor() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CryptcordDistributorV1__InvalidFeePercentage.selector, s_cryptcordDistributorV1.getScaleFactor() + 1
            )
        );
        s_cryptcordDistributorV1.setFeePercentage(invalidFeePercentage);
    }

    /**
     * @notice Test setFeePercentage function when the fee percentage is valid
     */
    function testSetFeePercentage() public setOwner {
        uint256 newFeePercentage = 50; // 5%
        s_cryptcordDistributorV1.setFeePercentage(newFeePercentage);
        uint256 actualFeePercentage = s_cryptcordDistributorV1.getFeePercentage();
        vm.assertEq(newFeePercentage, actualFeePercentage, "Fee percentage not set correctly");
    }

    // ===========================================================================
    // │ addSupportedToken() - removeSupportedToken() - isTokenSupported() Tests │
    // ===========================================================================

    /**
     * @notice Test addSupportedToken function when the caller is not the owner
     */
    function testAddSupportedTokenNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.addSupportedToken(address(0));
    }

    /**
     * @notice Test addSupportedToken function
     */
    function testAddSupportedToken() public setOwner {
        s_cryptcordDistributorV1.addSupportedToken(address(s_erc20MockUSDT));
        bool isSupportedToken = s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isSupportedToken, "Token not added");
    }

    /**
     * @notice Test removeSupportedToken function when the caller is not the owner
     */
    function testRemoveSupportedTokenNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.removeSupportedToken(address(0));
    }

    /**
     * @notice Test removeSupportedToken function
     */
    function testRemoveSupportedToken() public setOwner {
        // First add the token
        s_cryptcordDistributorV1.addSupportedToken(address(s_erc20MockUSDT));
        bool isTokenAdded = s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isTokenAdded, "Token not added");

        // Then remove the token
        s_cryptcordDistributorV1.removeSupportedToken(address(s_erc20MockUSDT));
        bool isTokenRemoved = !s_cryptcordDistributorV1.isTokenSupported(address(s_erc20MockUSDT));
        vm.assertEq(true, isTokenRemoved, "Token not removed");
    }

    // ================================================================
    // │                    distributeTokens() Tests                  │
    // ================================================================

    struct TransferResult {
        uint256 transferAmount;
        uint256 fee;
    }

    /**
     * @notice Transfer tokens and test event emission
     * @param erc20Address The address of the ERC20 token
     * @param amount The amount of tokens to transfer
     * @param from The address of the sender
     * @param to The address of the receiver
     * @param paymentId The payment ID
     */
    function transferTokensAndTestEventEmit(
        address erc20Address,
        uint256 amount,
        address from,
        address to,
        bytes16 paymentId
    ) internal returns (TransferResult memory result) {
        // Add erc20Address to supported tokens
        vm.prank(s_owner);
        s_cryptcordDistributorV1.addSupportedToken(erc20Address);

        // Prank sender and approve tokens to distributor
        vm.prank(from);
        s_erc20MockUSDT.approve(address(s_cryptcordDistributorV1), amount);
        vm.startPrank(s_owner);
        // Calculate fee and amount sent
        uint256 fee = (amount * s_cryptcordDistributorV1.getFeePercentage()) / s_cryptcordDistributorV1.getScaleFactor();
        uint256 transferAmount = amount - fee;

        // Test event emission
        vm.expectEmit(true, true, true, true, address(s_cryptcordDistributorV1));
        emit TokensTransferred(erc20Address, from, to, amount, fee, transferAmount, paymentId);

        // Distribute tokens
        s_cryptcordDistributorV1.distributeTokens(erc20Address, amount, from, to, paymentId);

        return TransferResult(transferAmount, fee);
    }

    /**
     * @notice Test distributeTokens function when the token is not supported
     */
    function testDistributeTokensTokenNotSupported() public {
        (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId) = getDistributeTokensArgs();

        // Expect revert (current supported tokens array is empty)
        vm.expectRevert(abi.encodeWithSelector(CryptcordDistributorV1__TokenNotSupported.selector, erc20Address));

        s_cryptcordDistributorV1.distributeTokens(erc20Address, amount, from, to, paymentId);
    }

    /**
     * @notice Test distributeTokens function and check if fee is sent to owner
     */
    function testDistributeTokensFeeSentToOwner() public {
        (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId) = getDistributeTokensArgs();

        // Get owner balance before transfer
        uint256 ownerBalanceBefore = s_erc20MockUSDT.balanceOf(s_owner);

        // Transfer tokens and calculate fee
        TransferResult memory result = transferTokensAndTestEventEmit(erc20Address, amount, from, to, paymentId);

        // Get owner balance after transfer
        uint256 ownerBalanceAfter = s_erc20MockUSDT.balanceOf(s_owner);

        // Check if fee was sent to owner
        vm.assertEq(ownerBalanceBefore + result.fee, ownerBalanceAfter, "Fee not sent to owner");
    }

    /**
     * @notice Test distributeTokens function and check if amount is sent to receiver
     */
    function testDistributeTokensAmountSentToReceiver() public {
        (address erc20Address, uint256 amount, address from, address to, bytes16 paymentId) = getDistributeTokensArgs();

        // Get receiver balance before transfer
        uint256 receiverBalanceBefore = s_erc20MockUSDT.balanceOf(to);

        // Transfer tokens and calculate fee
        TransferResult memory result = transferTokensAndTestEventEmit(erc20Address, amount, from, to, paymentId);

        // Get receiver balance after transfer
        uint256 receiverBalanceAfter = s_erc20MockUSDT.balanceOf(to);

        // Check if amount was sent to receiver
        vm.assertEq(receiverBalanceBefore + result.transferAmount, receiverBalanceAfter, "Amount not sent to receiver");
    }

    // ================================================================
    // │                     withdrawTokens() Tests                   │
    // ================================================================

    /**
     * @notice Test withdrawTokens function when the caller is not the owner
     */
    function testWithdrawTokensNotOwner() public ownerNotNullAddress {
        vm.prank(address(0));
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0)));
        s_cryptcordDistributorV1.withdrawTokens(address(0), 0);
    }

    /**
     * @notice Test withdrawTokens function
     */
    function testWithdrawTokens() public {
        // Deploy a new ERC20 token and the owner should be the s_cryptcordDistributorV1 contract
        uint256 initialSupply = 1_000_000;
        vm.prank(address(s_cryptcordDistributorV1));
        ERC20MockUSDT erc20MockUSDT = new ERC20MockUSDT(initialSupply);

        // Get the owner balance before withdrawing tokens
        uint256 ownerBalanceBefore = erc20MockUSDT.balanceOf(s_owner);

        // Now owner should withdraw the tokens
        vm.prank(s_owner);
        uint256 amount = 100;
        s_cryptcordDistributorV1.withdrawTokens(address(erc20MockUSDT), amount);

        // Get the owner balance after withdrawing tokens
        uint256 ownerBalanceAfter = erc20MockUSDT.balanceOf(s_owner);

        // Check if the owner received the tokens
        vm.assertEq(ownerBalanceBefore + amount, ownerBalanceAfter, "Amount not withdrawn");
    }

    // ================================================================
    // │                       receive() Tests                        │
    // ================================================================

    uint256 private constant HOAX_AMOUNT = 1 ether;

    /**
     * @notice Test receive function
     */
    function testReceive() public {
        uint256 ownerBalanceBefore = s_owner.balance;

        // Hoax the address(1) to send ether to the contract
        hoax(address(1), HOAX_AMOUNT);
        assertEq(address(1).balance, HOAX_AMOUNT);

        // Send ether to the contract
        (bool success,) = address(s_cryptcordDistributorV1).call{value: HOAX_AMOUNT}("");
        vm.assertTrue(success, "Send failed");

        // Check the owner balance after receiving ether
        uint256 ownerBalanceAfter = address(s_owner).balance;
        vm.assertEq(ownerBalanceBefore + HOAX_AMOUNT, ownerBalanceAfter, "Amount not received");
    }
}
