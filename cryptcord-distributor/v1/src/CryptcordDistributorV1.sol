// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Errors
error InsufficientAllowance(uint256 allowance, uint256 amount);
error InsufficientBalance(uint256 balance, uint256 withdrawAmount);
error TokenNotSupported(address erc20Address);
error IndexOutOfBounds(uint256 index);

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

    uint256 private s_feePercentage = 75;

    function setFeePercentage(uint256 feePercentage) external onlyOwner {
        s_feePercentage = feePercentage;
    }

    address[] private s_supportedTokens;

    function addSupportedToken(address erc20Address) external onlyOwner {
        s_supportedTokens.push(erc20Address);
    }

    function removeSupportedToken(uint256 index) external onlyOwner {
        uint256 length = s_supportedTokens.length;
        if (index >= length) {
            revert IndexOutOfBounds(index);
        }
        for (uint256 i = index; i < length - 1; i++) {
            s_supportedTokens[i] = s_supportedTokens[i + 1];
        }
        s_supportedTokens.pop();
    }

    function checkIfTokenIsSupported(address erc20Address) public view returns (bool) {
        uint256 length = s_supportedTokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (s_supportedTokens[i] == erc20Address) {
                return true;
            }
        }
        return false;
    }

    function transferTokens(address erc20Address, uint256 amount, address from, address to, bytes16 paymentId)
        external
    {
        if (!checkIfTokenIsSupported(erc20Address)) {
            revert TokenNotSupported(erc20Address);
        }

        IERC20 token = IERC20(erc20Address);
        // Check if contract has enough approved balance
        uint256 allowance = token.allowance(from, address(this));
        if (allowance < amount) {
            revert InsufficientAllowance(allowance, amount);
        }

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
        emit TokensTransferred(erc20Address, from, to, amount, fee, transferAmount, paymentId);
    }

    /**
     * Function to withdraw stuck ERC20 tokens
     */
    function withdrawTokens(address erc20Address, uint256 amount) external {
        IERC20 token = IERC20(erc20Address);
        token.safeTransfer(owner(), amount);
    }

    /**
     * Automatically forward received native currency to the owner
     */
    receive() external payable {
        (bool s,) = payable(owner()).call{value: msg.value}(new bytes(0));
        require(s);
    }

    // ================================================================
    // │                      Getter Functions                        │
    // ================================================================
    function getFeePercentage() public view returns (uint256) {
        return s_feePercentage;
    }

    function getSupportedTokens() public view returns (address[] memory) {
        return s_supportedTokens;
    }
}
