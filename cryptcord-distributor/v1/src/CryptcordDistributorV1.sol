// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// ================================================================
// │                             Errors                           │
// ================================================================
error CryptcordDistributorV1__InvalidFeePercentage(uint256 feePercentage);
error CryptcordDistributorV1__TokenNotSupported(address erc20Address);

// ================================================================
// │                             Events                           │
// ================================================================
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
    uint256 private s_feePercentage = 75; // 7.5% is the default fee percentage
    address[] private s_supportedTokens;

    // ================================================================
    // │                         Constructor                          │
    // ================================================================
    /**
     * Constructor
     * @param _supportedTokens Array of supported tokens' addresses
     */
    constructor(address[] memory _supportedTokens) Ownable(msg.sender) {
        s_supportedTokens = _supportedTokens;
    }

    // ================================================================
    // │                         Owner Functions                      │
    // ================================================================

    /**
     * Function to set fee percentage
     * @param _feePercentage New fee percentage
     */
    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        // Ensure feePercentage does not exceed SCALE_FACTOR (100%)
        if (_feePercentage > SCALE_FACTOR) {
            revert CryptcordDistributorV1__InvalidFeePercentage(_feePercentage);
        }
        s_feePercentage = _feePercentage;
    }

    /**
     * Function to add supported token
     * @param _erc20Address Token's address
     */
    function addSupportedToken(address _erc20Address) external onlyOwner {
        s_supportedTokens.push(_erc20Address);
    }

    /**
     * Function to remove supported token
     * @param _erc20Address Token's address
     */
    function removeSupportedToken(address _erc20Address) external onlyOwner {
        uint256 length = s_supportedTokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (s_supportedTokens[i] == _erc20Address) {
                if (i != length - 1) {
                    s_supportedTokens[i] = s_supportedTokens[length - 1];
                }
                s_supportedTokens.pop();
                return;
            }
        }
    }

    // ================================================================
    // │                        Token Transfers                       │
    // ================================================================

    /**
     * Function to check if token is supported
     * @param _erc20Address Token's address
     */
    function isTokenSupported(address _erc20Address) public view returns (bool) {
        uint256 length = s_supportedTokens.length;
        for (uint256 i = 0; i < length; i++) {
            if (s_supportedTokens[i] == _erc20Address) {
                return true;
            }
        }
        return false;
    }

    /**
     * Function to distribute tokens and deduct fees
     * @param _erc20Address Token's address
     * @param _amount Amount to distribute
     * @param _from Sender's address
     * @param _to Receiver's address
     * @param _paymentId Payment ID
     */
    function distributeTokens(address _erc20Address, uint256 _amount, address _from, address _to, bytes16 _paymentId)
        external
    {
        if (!isTokenSupported(_erc20Address)) {
            revert CryptcordDistributorV1__TokenNotSupported(_erc20Address);
        }

        IERC20 token = IERC20(_erc20Address);

        // Calculate the amounts
        uint256 fee = (_amount * s_feePercentage) / SCALE_FACTOR;
        uint256 transferAmount = _amount - fee;

        // Transfer the fee to the owner
        token.safeTransferFrom(_from, owner(), fee);

        // Transfer the remaining amount to the destination address
        token.safeTransferFrom(_from, _to, transferAmount);

        // Event
        emit TokensTransferred(_erc20Address, _from, _to, _amount, fee, transferAmount, _paymentId);
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
     * @param _erc20Address Token's address
     * @param _amount Amount to withdraw
     */
    function withdrawTokens(address _erc20Address, uint256 _amount) external onlyOwner {
        IERC20 token = IERC20(_erc20Address);
        token.safeTransfer(owner(), _amount);
    }

    /**
     * Automatically forward received native currency to the owner
     */
    receive() external payable {
        (bool s,) = payable(owner()).call{value: msg.value}(new bytes(0));
        require(s);
    }
}
