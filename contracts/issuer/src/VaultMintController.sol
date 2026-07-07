// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IVaultMint} from "./interfaces/IVaultState.sol";

/// @notice Minimal interface for TreasureNFT with achievement support
interface ITreasureNFTWithAchievement {
    function mintWithAchievement(address to, bytes32 achievementType) external returns (uint256);
}

/// @title VaultMintController - Atomic vault minting with achievement treasures
/// @notice Mints treasure + vault in a single transaction
/// @dev Pattern based on AchievementMinter.mintHodlerSupremeVault()
contract VaultMintController {
    using SafeERC20 for IERC20;

    /// @notice Emitted when a vault is atomically minted
    event VaultMinted(
        address indexed owner,
        uint256 indexed vaultId,
        uint256 treasureId,
        bytes32 achievementType,
        uint256 collateralAmount
    );

    error ZeroCollateral();
    error ZeroAddress();

    address public immutable treasureNFT;
    address public immutable vaultNFT;
    address public immutable collateralToken;

    constructor(
        address treasureNFT_,
        address vaultNFT_,
        address collateralToken_
    ) {
        if (treasureNFT_ == address(0)) revert ZeroAddress();
        if (vaultNFT_ == address(0)) revert ZeroAddress();
        if (collateralToken_ == address(0)) revert ZeroAddress();
        treasureNFT = treasureNFT_;
        vaultNFT = vaultNFT_;
        collateralToken = collateralToken_;
    }

    /// @notice Atomically mint treasure with achievement and wrap into vault
    /// @param achievementType The achievement type for the treasure
    /// @param collateralAmount Amount of collateral to deposit
    /// @return vaultId The minted vault token ID
    function mintVault(
        bytes32 achievementType,
        uint256 collateralAmount
    ) external returns (uint256 vaultId) {
        if (collateralAmount == 0) revert ZeroCollateral();

        // 1. Mint treasure to this contract (not user)
        uint256 treasureId = ITreasureNFTWithAchievement(treasureNFT).mintWithAchievement(
            address(this),
            achievementType
        );

        // 2. Transfer collateral from caller
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        // 3. Approve VaultNFT to take both assets
        IERC721(treasureNFT).approve(vaultNFT, treasureId);
        IERC20(collateralToken).approve(vaultNFT, collateralAmount);

        // 4. Mint vault (this contract owns treasure, so VaultNFT.transferFrom succeeds)
        vaultId = IVaultMint(vaultNFT).mint(
            treasureNFT,
            treasureId,
            collateralToken,
            collateralAmount
        );

        // 5. Transfer vault to caller
        IERC721(vaultNFT).transferFrom(address(this), msg.sender, vaultId);

        emit VaultMinted(msg.sender, vaultId, treasureId, achievementType, collateralAmount);
    }
}
