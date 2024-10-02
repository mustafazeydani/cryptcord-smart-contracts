// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptcordDistributorV1 is Ownable {
    constructor() Ownable(msg.sender) {}

    uint256 scaleFactor = 1000;
    uint256 feePercentage = 75;

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        feePercentage = _feePercentage;
    }

    // Errors
    error InsufficientBalance(uint256 balance, uint256 withdrawAmount);
    error TransferFailed(
        address tokenAddress,
        address from,
        address to,
        uint256 value
    );

    // Events
    event Transfer(
        address indexed erc20,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 fee,
        uint256 transferAmount,
        bytes16 paymentId
    );

    function transferTokens(
        address erc20,
        uint256 amount,
        address from,
        address to,
        bytes16 paymentId
    ) public {
        IERC20 token = IERC20(erc20);
        uint256 fromBalance = token.balanceOf(from);

        // Check if sender has enough balance
        if (fromBalance < amount) {
            revert InsufficientBalance({
                balance: fromBalance,
                withdrawAmount: amount
            });
        }

        // Calculate the amounts
        uint256 fee = (amount * feePercentage) / scaleFactor;
        uint256 transferAmount = amount - fee;

        // Transfer the fee to the owner
        if (!token.transferFrom(from, owner(), fee)) {
            revert TransferFailed({
                tokenAddress: erc20,
                from: from,
                to: owner(),
                value: fee
            });
        }

        // Transfer the remaining amount to the destination address
        if (!token.transferFrom(from, to, transferAmount)) {
            revert TransferFailed({
                tokenAddress: erc20,
                from: from,
                to: to,
                value: transferAmount
            });
        }

        // Event
        emit Transfer(erc20, from, to, amount, fee, transferAmount, paymentId);
    }
}
