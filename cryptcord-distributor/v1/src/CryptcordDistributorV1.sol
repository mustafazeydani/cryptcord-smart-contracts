// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Errors
error InvalidFeePercentage(uint256 feePercentage);
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
    using SafeERC20 for IERC20;

    // ================================================================
    // │                       Variables & Constants                  │
    // ================================================================

    uint256 constant SCALE_FACTOR = 1000;
    uint256 private s_feePercentage = 75;
    address[] private s_supportedTokens;

    // ================================================================
    // │                         Constructor                          │
    // ================================================================
    /**
     * Constructor
     * @param supportedTokens Array of supported tokens' addresses
     */
    constructor(address[] memory supportedTokens) Ownable(msg.sender) {
        s_supportedTokens = supportedTokens;
    }

    // ================================================================
    // │                         Owner Functions                      │
    // ================================================================

    /**
     * Function to set fee percentage
     * @param feePercentage New fee percentage
     */
    function setFeePercentage(uint256 feePercentage) external onlyOwner {
        // Ensure feePercentage does not exceed SCALE_FACTOR (100%)
        if (feePercentage > SCALE_FACTOR) {
            revert InvalidFeePercentage(feePercentage);
        }
        s_feePercentage = feePercentage;
    }

    /**
     * Function to add supported token
     * @param erc20Address Token's address
     */
    function addSupportedToken(address erc20Address) external onlyOwner {
        s_supportedTokens.push(erc20Address);
    }

    /**
     * Function to remove supported token
     * @param index Token's index
     */
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

    // ================================================================
    // │                        Token Transfers                       │
    // ================================================================

    /**
     * Function to check if token is supported
     * @param erc20Address Token's address
     */
    function isTokenSupported(address erc20Address) public view returns (bool) {
        uint256 length = s_supportedTokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (s_supportedTokens[i] == erc20Address) {
                return true;
            }
        }
        return false;
    }

    /**
     * Function to distribute tokens and deduct fees
     * @param erc20Address Token's address
     * @param amount Amount to distribute
     * @param from Sender's address
     * @param to Receiver's address
     * @param paymentId Payment ID
     */
    function distributeTokens(address erc20Address, uint256 amount, address from, address to, bytes16 paymentId)
        external
    {
        if (!isTokenSupported(erc20Address)) {
            revert TokenNotSupported(erc20Address);
        }

        IERC20 token = IERC20(erc20Address);

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

    // ================================================================
    // │                      Getter Functions                        │
    // ================================================================

    function getFeePercentage() public view returns (uint256) {
        return s_feePercentage;
    }

    function getSupportedTokens() public view returns (address[] memory) {
        return s_supportedTokens;
    }

    // ================================================================
    // │                     Emergency Functions                      │
    // ================================================================

    /**
     * Function to withdraw stuck ERC20 tokens
     * @param erc20Address Token's address
     * @param amount Amount to withdraw
     */
    function withdrawTokens(address erc20Address, uint256 amount) external onlyOwner {
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
}
