// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Mock Protocol HybridVaultNFT for HybridMintController testing
contract MockProtocolHybridVaultNFT is ERC721 {
    uint256 private _nextTokenId;

    struct VaultData {
        address treasureContract;
        uint256 treasureTokenId;
        uint256 primaryAmount;
        uint256 secondaryAmount;
        uint256 mintTimestamp;
    }

    mapping(uint256 => VaultData) public vaults;

    IERC20 public immutable primaryToken;
    IERC20 public immutable secondaryToken;

    constructor(address primaryToken_, address secondaryToken_) ERC721("Mock Hybrid Vault", "MHVAULT") {
        primaryToken = IERC20(primaryToken_);
        secondaryToken = IERC20(secondaryToken_);
    }

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        uint256 primaryAmount,
        uint256 secondaryAmount
    ) external returns (uint256 tokenId) {
        // Transfer treasure NFT from caller
        IERC721(treasureContract).transferFrom(msg.sender, address(this), treasureTokenId);

        // Transfer collateral from caller
        primaryToken.transferFrom(msg.sender, address(this), primaryAmount);
        secondaryToken.transferFrom(msg.sender, address(this), secondaryAmount);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        vaults[tokenId] = VaultData({
            treasureContract: treasureContract,
            treasureTokenId: treasureTokenId,
            primaryAmount: primaryAmount,
            secondaryAmount: secondaryAmount,
            mintTimestamp: block.timestamp
        });
    }

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract_,
            uint256 treasureTokenId_,
            uint256 primaryAmount_,
            uint256 secondaryAmount_,
            uint256 mintTimestamp_
        )
    {
        VaultData storage vault = vaults[tokenId];
        return (
            vault.treasureContract,
            vault.treasureTokenId,
            vault.primaryAmount,
            vault.secondaryAmount,
            vault.mintTimestamp
        );
    }
}
