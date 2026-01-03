// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";

/// @notice Mock VaultNFT for HybridVaultNFT testing
/// @dev Implements full IVaultNFT interface required by HybridVaultNFT
contract MockVaultNFTForHybrid is ERC721 {
    uint256 private _nextTokenId;
    uint256 public constant WITHDRAWAL_RATE = 100; // 1% in BPS
    uint256 public constant BASIS_POINTS = 10000;

    struct VaultData {
        address treasureContract;
        uint256 treasureTokenId;
        address collateralToken;
        uint256 collateralAmount;
        uint256 mintTimestamp;
        uint256 lastWithdrawal;
        uint256 lastActivity;
        uint256 btcTokenAmount;
        uint256 originalMintedAmount;
    }

    mapping(uint256 => VaultData) public vaults;
    mapping(uint256 => bool) private _isVested;
    address public vestedBTCToken;

    constructor(address vestedBTC_) ERC721("Mock Vault", "MVAULT") {
        vestedBTCToken = vestedBTC_;
    }

    function mint(address treasureContract, uint256 treasureTokenId, address collateralToken, uint256 collateralAmount)
        external
        returns (uint256 tokenId)
    {
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
            lastWithdrawal: 0,
            lastActivity: block.timestamp,
            btcTokenAmount: 0,
            originalMintedAmount: 0
        });
    }

    function withdraw(uint256 tokenId) external returns (uint256 amount) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_isVested[tokenId], "Not vested");

        VaultData storage vault = vaults[tokenId];
        amount = (vault.collateralAmount * WITHDRAWAL_RATE) / BASIS_POINTS;
        vault.collateralAmount -= amount;
        vault.lastWithdrawal = block.timestamp;

        IERC20(vault.collateralToken).transfer(msg.sender, amount);
    }

    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        VaultData storage vault = vaults[tokenId];
        uint256 total = vault.collateralAmount;

        // Simple 50% return for testing
        returned = total / 2;
        forfeited = total - returned;

        vault.collateralAmount = 0;

        IERC20(vault.collateralToken).transfer(msg.sender, returned);

        // Burn treasure
        IERC721(vault.treasureContract).transferFrom(address(this), address(0xdead), vault.treasureTokenId);

        _burn(tokenId);
    }

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount) {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(_isVested[tokenId], "Not vested");

        VaultData storage vault = vaults[tokenId];
        require(vault.btcTokenAmount == 0, "Already minted");

        amount = vault.collateralAmount;
        vault.btcTokenAmount = amount;
        vault.originalMintedAmount = amount;

        // Mock mint vestedBTC to caller
        MockMintable(vestedBTCToken).mint(msg.sender, amount);
    }

    function returnBtcToken(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");

        VaultData storage vault = vaults[tokenId];
        require(vault.originalMintedAmount > 0, "Not separated");

        // Transfer vestedBTC back
        IERC20(vestedBTCToken).transferFrom(msg.sender, address(this), vault.originalMintedAmount);

        vault.btcTokenAmount = 0;
        vault.originalMintedAmount = 0;
    }

    function isVested(uint256 tokenId) external view returns (bool) {
        return _isVested[tokenId];
    }

    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256) {
        if (!_isVested[tokenId]) return 0;
        return (vaults[tokenId].collateralAmount * WITHDRAWAL_RATE) / BASIS_POINTS;
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
            vault.lastWithdrawal,
            vault.lastActivity,
            vault.btcTokenAmount,
            vault.originalMintedAmount
        );
    }

    // ==================== Test Helpers ====================

    function setVested(uint256 tokenId, bool vested) external {
        _isVested[tokenId] = vested;
    }

    function setCollateralAmount(uint256 tokenId, uint256 amount) external {
        vaults[tokenId].collateralAmount = amount;
    }
}

interface MockMintable {
    function mint(address to, uint256 amount) external;
}
