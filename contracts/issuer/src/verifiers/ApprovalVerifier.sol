// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title ApprovalVerifier
/// @notice Verifies token approval for minting (PREPARED achievement)
contract ApprovalVerifier is IAchievementVerifier, Ownable {
    /// @notice Collateral token to check approval for
    IERC20 public immutable COLLATERAL_TOKEN;

    /// @notice Spender to check approval for (typically VaultNFT)
    address public immutable SPENDER;

    /// @notice Minimum approval amount required
    uint256 public minApprovalAmount;

    event MinApprovalAmountSet(uint256 amount);

    constructor(address collateralToken, address spender, uint256 minAmount) Ownable(msg.sender) {
        if (collateralToken == address(0)) revert ZeroAddress();
        if (spender == address(0)) revert ZeroAddress();
        COLLATERAL_TOKEN = IERC20(collateralToken);
        SPENDER = spender;
        minApprovalAmount = minAmount;
    }

    /// @notice Set minimum approval amount
    /// @param amount New minimum amount (0 = any approval counts)
    function setMinApprovalAmount(uint256 amount) external onlyOwner {
        minApprovalAmount = amount;
        emit MinApprovalAmountSet(amount);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32,
        bytes calldata
    ) external view returns (bool verified) {
        uint256 allowance = COLLATERAL_TOKEN.allowance(wallet, SPENDER);
        if (minApprovalAmount == 0) {
            return allowance > 0;
        }
        return allowance >= minApprovalAmount;
    }

    error ZeroAddress();
}
