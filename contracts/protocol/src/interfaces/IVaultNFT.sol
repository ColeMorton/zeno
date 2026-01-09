// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IVaultNFTDormancy} from "./IVaultNFTDormancy.sol";
import {IVaultNFTDelegation} from "./IVaultNFTDelegation.sol";

/// @title IVaultNFT
/// @notice Main interface for VaultNFT, inheriting dormancy and delegation concerns
interface IVaultNFT is IERC721, IVaultNFTDormancy, IVaultNFTDelegation {
    // Re-export types from inherited interfaces for backwards compatibility
    // These are aliases to the types defined in IVaultNFTDormancy and IVaultNFTDelegation

    // ========== Core Vault Events ==========

    event VaultMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address treasureContract,
        uint256 treasureTokenId,
        uint256 collateral
    );
    event Withdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);
    event EarlyRedemption(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 returned,
        uint256 forfeited
    );
    event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount);
    event MatchClaimed(uint256 indexed tokenId, uint256 amount);
    event MatchPoolFunded(uint256 amount, uint256 newBalance);

    // ========== Core Vault Errors ==========

    error NotTokenOwner(uint256 tokenId);
    error StillVesting(uint256 tokenId);
    error WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);
    error ZeroCollateral();
    error BtcTokenAlreadyMinted(uint256 tokenId);
    error BtcTokenRequired(uint256 tokenId);
    error InsufficientBtcToken(uint256 required, uint256 available);
    error NotVested(uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error NoPoolAvailable();
    error InvalidCollateralToken(address token);
    error TokenDoesNotExist(uint256 tokenId);

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);

    function withdraw(uint256 tokenId) external returns (uint256 amount);

    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited);

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount);

    function returnBtcToken(uint256 tokenId) external;

    function claimMatch(uint256 tokenId) external returns (uint256 amount);

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract,
            uint256 treasureTokenId,
            address collateralToken,
            uint256 collateralAmount,
            uint256 mintTimestamp,
            uint256 lastWithdrawal,
            uint256 lastActivity,
            uint256 btcTokenAmount,
            uint256 originalMintedAmount
        );

    function isVested(uint256 tokenId) external view returns (bool);

    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256);

    function getCollateralClaim(uint256 tokenId) external view returns (uint256);

    function getClaimValue(address holder, uint256 tokenId) external view returns (uint256);

    function collateralToken() external view returns (address);
}
