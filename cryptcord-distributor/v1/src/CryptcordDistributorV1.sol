// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Errors
error InsufficientBalance(uint256 balance, uint256 withdrawAmount);

// Events
event TokensTransferred(
    address indexed erc20,
    address indexed from,
    address indexed to,
    uint256 amount,
    uint256 fee,
    uint256 transferAmount,
    bytes16 paymentId
);

contract CryptcordDistributorV1 is Ownable {
    constructor() Ownable(msg.sender) {}

    using SafeERC20 for IERC20;

    uint256 constant SCALE_FACTOR = 1000;
    uint256 s_feePercentage = 75;

    function setFeePercentage(uint256 feePercentage) external onlyOwner {
        s_feePercentage = feePercentage;
    }

    function transferTokens(address erc20, uint256 amount, address from, address to, bytes16 paymentId) public {
        IERC20 token = IERC20(erc20);
        uint256 senderBalance = token.balanceOf(from);

        // Check if sender has enough balance
        if (senderBalance < amount) {
            revert InsufficientBalance({balance: senderBalance, withdrawAmount: amount});
        }

        // Calculate the amounts
        uint256 fee = (amount * s_feePercentage) / SCALE_FACTOR;
        uint256 transferAmount = amount - fee;

        // Transfer the fee to the owner
        token.safeTransferFrom(from, owner(), fee);

        // Transfer the remaining amount to the destination address
        token.safeTransferFrom(from, to, transferAmount);

        // Event
        emit TokensTransferred(erc20, from, to, amount, fee, transferAmount, paymentId);
    }
}
