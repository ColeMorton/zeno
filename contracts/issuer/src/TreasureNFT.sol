// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";
import {IVaultNFT} from "@protocol/interfaces/IVaultNFT.sol";

/// @title TreasureNFT - Issuer-branded NFT for vault storage
/// @notice ERC-721 with tier-based visuals derived from vault collateral percentile
/// @dev Treasure NFTs are stored inside Vault NFTs as the "collectible" component
///      Tier is computed dynamically from vault collateral vs distribution thresholds
contract TreasureNFT is ERC721, Ownable, ITreasureNFT {
    using Strings for uint256;

    // ==================== Constants ====================

    /// @notice ERC-4906 interface ID
    bytes4 private constant ERC4906_INTERFACE_ID = 0x49064906;

    // ==================== State Variables ====================

    uint256 private _nextTokenId;
    string private _baseTokenURI;

    /// @notice Protocol VaultNFT for collateral queries
    IVaultNFT public protocol;

    /// @notice Keeper address for threshold updates
    address public keeper;

    /// @notice Percentile thresholds for tier computation
    Thresholds public thresholds;

    /// @notice Maps treasure tokenId to vault tokenId
    mapping(uint256 => uint256) public treasureVault;

    /// @notice Addresses authorized to mint
    mapping(address => bool) public authorizedMinters;

    /// @notice Achievement type for each token (bytes32(0) = generic treasure)
    mapping(uint256 => bytes32) public achievementType;

    /// @notice CIDs for pre-composed tier images: [achievementType][tier] => CID
    mapping(bytes32 => mapping(Tier => string)) public imageCIDs;

    // ==================== Structs ====================

    struct Thresholds {
        uint256 silver;    // 50th percentile collateral
        uint256 gold;      // 75th percentile
        uint256 platinum;  // 90th percentile
        uint256 diamond;   // 99th percentile
    }

    // ==================== Events ====================

    event MinterAuthorized(address indexed minter);
    event MinterRevoked(address indexed minter);
    event KeeperUpdated(address indexed oldKeeper, address indexed newKeeper);
    event ProtocolUpdated(address indexed protocol);
    event ImageCIDSet(bytes32 indexed achievementType, Tier indexed tier, string cid);

    // ==================== Modifiers ====================

    modifier onlyAuthorizedMinter() {
        if (!authorizedMinters[msg.sender] && msg.sender != owner()) {
            revert NotAuthorizedMinter(msg.sender);
        }
        _;
    }

    modifier onlyKeeper() {
        if (msg.sender != keeper && msg.sender != owner()) {
            revert NotKeeper(msg.sender);
        }
        _;
    }

    // ==================== Constructor ====================

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address protocol_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = baseURI_;
        protocol = IVaultNFT(protocol_);
        keeper = msg.sender;
    }

    // ==================== Admin Functions ====================

    /// @inheritdoc ITreasureNFT
    function authorizeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;
        emit MinterAuthorized(minter);
    }

    /// @inheritdoc ITreasureNFT
    function revokeMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = false;
        emit MinterRevoked(minter);
    }

    /// @notice Set the keeper address for threshold updates
    /// @param newKeeper The new keeper address
    function setKeeper(address newKeeper) external onlyOwner {
        emit KeeperUpdated(keeper, newKeeper);
        keeper = newKeeper;
    }

    /// @notice Set the protocol VaultNFT address
    /// @param protocol_ The protocol VaultNFT address
    function setProtocol(address protocol_) external onlyOwner {
        protocol = IVaultNFT(protocol_);
        emit ProtocolUpdated(protocol_);
    }

    /// @inheritdoc ITreasureNFT
    function updateThresholds(
        uint256 silver,
        uint256 gold,
        uint256 platinum,
        uint256 diamond
    ) external onlyKeeper {
        thresholds = Thresholds(silver, gold, platinum, diamond);
        emit ThresholdsUpdated(silver, gold, platinum, diamond);
        emit BatchMetadataUpdate(0, type(uint256).max);
    }

    /// @notice Set the image CID for a specific achievement type and tier
    /// @param achievementType_ The achievement type
    /// @param tier The tier level
    /// @param cid The IPFS CID for the pre-composed image
    function setImageCID(bytes32 achievementType_, Tier tier, string calldata cid) external onlyOwner {
        imageCIDs[achievementType_][tier] = cid;
        emit ImageCIDSet(achievementType_, tier, cid);
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI_ New base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    // ==================== Core Functions ====================

    /// @inheritdoc ITreasureNFT
    function mint(address to) external onlyAuthorizedMinter returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    /// @notice Mint a new Treasure NFT with a specific achievement type
    /// @param to Recipient address
    /// @param achievementType_ The achievement type to associate with this treasure
    /// @return tokenId The minted token ID
    function mintWithAchievement(address to, bytes32 achievementType_) external onlyAuthorizedMinter returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        achievementType[tokenId] = achievementType_;
        _mint(to, tokenId);
    }

    /// @inheritdoc ITreasureNFT
    function mintBatch(address to, uint256 count) external onlyAuthorizedMinter returns (uint256[] memory tokenIds) {
        tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = _nextTokenId++;
            _mint(to, tokenIds[i]);
        }
    }

    /// @inheritdoc ITreasureNFT
    function linkToVault(uint256 treasureTokenId, uint256 vaultId) external onlyAuthorizedMinter {
        if (treasureVault[treasureTokenId] != 0) {
            revert AlreadyLinkedToVault(treasureTokenId);
        }
        treasureVault[treasureTokenId] = vaultId;
        emit VaultLinked(treasureTokenId, vaultId);
        emit MetadataUpdate(treasureTokenId);
    }

    // ==================== View Functions ====================

    /// @inheritdoc ITreasureNFT
    function computeTier(uint256 collateral) public view returns (Tier) {
        if (collateral >= thresholds.diamond) return Tier.Diamond;
        if (collateral >= thresholds.platinum) return Tier.Platinum;
        if (collateral >= thresholds.gold) return Tier.Gold;
        if (collateral >= thresholds.silver) return Tier.Silver;
        return Tier.Bronze;
    }

    /// @inheritdoc ITreasureNFT
    function getTier(uint256 treasureTokenId) public view returns (Tier) {
        uint256 vaultId = treasureVault[treasureTokenId];
        if (vaultId == 0) return Tier.Bronze;

        (,,, uint256 collateral,,,,,) = protocol.getVaultInfo(vaultId);
        return computeTier(collateral);
    }

    /// @notice Get the total number of Treasure NFTs minted
    /// @return Total supply
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    /// @notice Override tokenURI to return tier-based metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);

        Tier tier = getTier(tokenId);
        bytes32 achType = achievementType[tokenId];
        string memory imageCID = imageCIDs[achType][tier];

        // If no CID set, fall back to base URI
        if (bytes(imageCID).length == 0) {
            return super.tokenURI(tokenId);
        }

        // Build on-chain JSON metadata
        return string(
            abi.encodePacked(
                "data:application/json;base64,",
                Base64.encode(bytes(_buildJSON(tokenId, achType, tier, imageCID)))
            )
        );
    }

    /// @notice Build JSON metadata string
    function _buildJSON(
        uint256 tokenId,
        bytes32 achType,
        Tier tier,
        string memory imageCID
    ) internal view returns (string memory) {
        string memory tierName = _tierName(tier);
        uint256 vaultId = treasureVault[tokenId];

        return string(
            abi.encodePacked(
                '{"name":"Treasure #',
                tokenId.toString(),
                ' - ',
                tierName,
                '","description":"Treasure NFT with tier-based visual derived from vault collateral percentile","image":"ipfs://',
                imageCID,
                '","attributes":[{"trait_type":"Tier","value":"',
                tierName,
                '"},{"trait_type":"Vault ID","display_type":"number","value":',
                vaultId.toString(),
                '},{"trait_type":"Achievement Type","value":"',
                _bytes32ToString(achType),
                '"}]}'
            )
        );
    }

    /// @notice Convert tier enum to string
    function _tierName(Tier tier) internal pure returns (string memory) {
        if (tier == Tier.Diamond) return "Diamond";
        if (tier == Tier.Platinum) return "Platinum";
        if (tier == Tier.Gold) return "Gold";
        if (tier == Tier.Silver) return "Silver";
        return "Bronze";
    }

    /// @notice Convert bytes32 to string (for achievement type display)
    function _bytes32ToString(bytes32 value) internal pure returns (string memory) {
        if (value == bytes32(0)) return "GENERIC";
        bytes memory result = new bytes(32);
        uint256 len = 0;
        for (uint256 i = 0; i < 32; i++) {
            if (value[i] != 0) {
                result[len++] = value[i];
            }
        }
        bytes memory trimmed = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            trimmed[i] = result[i];
        }
        return string(trimmed);
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /// @notice ERC-165 interface support including ERC-4906
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, IERC165) returns (bool) {
        return interfaceId == ERC4906_INTERFACE_ID || super.supportsInterface(interfaceId);
    }
}
