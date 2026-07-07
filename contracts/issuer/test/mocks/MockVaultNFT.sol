// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Minimal mock for testing issuer contracts
contract MockVaultNFT is ERC721 {
    uint256 private _nextTokenId;

    struct VaultData {
        address treasure;
        uint256 treasureTokenId;
        address collateralToken;
        uint256 collateralAmount;
        uint256 strippedReserve;
        uint256 mintTimestamp;
        uint256 lastWithdrawal;
        uint256 lastActivity;
    }

    mapping(uint256 => VaultData) public vaults;
    mapping(uint256 => bool) private _isVested;

    constructor() ERC721("Mock Vault", "MVAULT") {}

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId) {
        // Transfer treasure NFT from caller
        IERC721(treasureContract).transferFrom(msg.sender, address(this), treasureTokenId);

        // Transfer collateral from caller
        IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        vaults[tokenId] = VaultData({
            treasure: treasureContract,
            treasureTokenId: treasureTokenId,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            strippedReserve: 0,
            mintTimestamp: block.timestamp,
            lastWithdrawal: 0,
            lastActivity: block.timestamp
        });
    }

    function treasureContract(uint256 tokenId) external view returns (address) {
        return vaults[tokenId].treasure;
    }

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContractAddr,
            uint256 treasureTokenId,
            address collateralTokenAddr,
            uint256 collateralAmount,
            uint256 strippedReserve,
            uint256 mintTimestamp,
            uint256 lastWithdrawal,
            uint256 lastActivity
        )
    {
        VaultData storage v = vaults[tokenId];
        return (
            v.treasure,
            v.treasureTokenId,
            v.collateralToken,
            v.collateralAmount,
            v.strippedReserve,
            v.mintTimestamp,
            v.lastWithdrawal,
            v.lastActivity
        );
    }

    function mintTimestamp(uint256 tokenId) external view returns (uint256) {
        return vaults[tokenId].mintTimestamp;
    }

    function isVested(uint256 tokenId) external view returns (bool) {
        return _isVested[tokenId];
    }

    /// @notice Test helper to set vesting status
    function setVested(uint256 tokenId, bool vested) external {
        _isVested[tokenId] = vested;
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Test helper to directly mint a vault without transfers
    /// @param to Owner of the vault
    /// @param treasure Treasure contract address
    /// @param timestamp Mint timestamp
    /// @return tokenId The minted token ID
    function mockMint(address to, address treasure, uint256 timestamp) external returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);

        vaults[tokenId] = VaultData({
            treasure: treasure,
            treasureTokenId: 0,
            collateralToken: address(0),
            collateralAmount: 0,
            strippedReserve: 0,
            mintTimestamp: timestamp,
            lastWithdrawal: 0,
            lastActivity: timestamp
        });
    }
}
