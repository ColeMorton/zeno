// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal mock for testing issuer contracts
contract MockVaultNFT is ERC721 {
    uint256 private _nextTokenId;

    struct VaultData {
        address treasureContract;
        uint256 treasureTokenId;
        address collateralToken;
        uint256 collateralAmount;
        uint256 mintTimestamp;
        uint8 tier;
    }

    mapping(uint256 => VaultData) public vaults;
    mapping(uint256 => bool) public matchClaimed;
    mapping(uint256 => bool) private _isVested;

    constructor() ERC721("Mock Vault", "MVAULT") {}

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount,
        uint8 tier
    ) external returns (uint256 tokenId) {
        // Transfer treasure NFT from caller
        IERC721(treasureContract).transferFrom(msg.sender, address(this), treasureTokenId);

        // Transfer collateral from caller
        IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        vaults[tokenId] = VaultData({
            treasureContract: treasureContract,
            treasureTokenId: treasureTokenId,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            mintTimestamp: block.timestamp,
            tier: tier
        });
    }

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract,
            uint256 treasureTokenId,
            address collateralToken,
            uint256 collateralAmount,
            uint256 mintTimestamp,
            uint8 tier,
            uint256 lastWithdrawal,
            uint256 lastActivity,
            uint256 btcTokenAmount,
            uint256 originalMintedAmount
        )
    {
        VaultData storage vault = vaults[tokenId];
        return (
            vault.treasureContract,
            vault.treasureTokenId,
            vault.collateralToken,
            vault.collateralAmount,
            vault.mintTimestamp,
            vault.tier,
            0, // lastWithdrawal
            0, // lastActivity
            0, // btcTokenAmount
            vault.collateralAmount // originalMintedAmount
        );
    }

    function isVested(uint256 tokenId) external view returns (bool) {
        return _isVested[tokenId];
    }

    /// @notice Test helper to set vesting status
    function setVested(uint256 tokenId, bool vested) external {
        _isVested[tokenId] = vested;
    }

    /// @notice Test helper to set match claimed status
    function setMatchClaimed(uint256 tokenId, bool claimed) external {
        matchClaimed[tokenId] = claimed;
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }
}
