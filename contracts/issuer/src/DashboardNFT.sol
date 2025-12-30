// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title DashboardNFT - Revenue-generating UI unlock NFTs
/// @notice ERC-721 + ERC-2981 with paid minting for dashboard feature unlocks
/// @dev One-time mint fee model with secondary market royalties
contract DashboardNFT is ERC721Royalty, Ownable {
    using Strings for uint256;

    // ═══════════════════════════════════════════════════════════════════════════════
    // STATE
    // ═══════════════════════════════════════════════════════════════════════════════

    uint256 private _nextTokenId;
    string private _baseTokenURI;
    address public revenueReceiver;

    /// @notice Token ID → feature type
    mapping(uint256 => bytes32) public featureType;

    /// @notice Feature type → mint price in wei
    mapping(bytes32 => uint256) public mintPrice;

    /// @notice Feature type → active for minting
    mapping(bytes32 => bool) public featureActive;

    /// @notice Wallet → feature type → ownership count (for accurate tracking across transfers)
    mapping(address => mapping(bytes32 => uint256)) private _featureOwnershipCount;

    // ═══════════════════════════════════════════════════════════════════════════════
    // FEATURE TYPE CONSTANTS
    // ═══════════════════════════════════════════════════════════════════════════════

    // Cosmetic features
    bytes32 public constant THEME_DARK = keccak256("THEME_DARK");
    bytes32 public constant THEME_NEON = keccak256("THEME_NEON");
    bytes32 public constant FRAME_ANIMATED = keccak256("FRAME_ANIMATED");
    bytes32 public constant AVATAR_CUSTOM = keccak256("AVATAR_CUSTOM");

    // Functional features
    bytes32 public constant ANALYTICS_PRO = keccak256("ANALYTICS_PRO");
    bytes32 public constant EXPORT_CSV = keccak256("EXPORT_CSV");
    bytes32 public constant ALERTS_ADVANCED = keccak256("ALERTS_ADVANCED");
    bytes32 public constant PORTFOLIO_MULTI = keccak256("PORTFOLIO_MULTI");

    // Bundle
    bytes32 public constant FOUNDERS_BUNDLE = keccak256("FOUNDERS_BUNDLE");

    // ═══════════════════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════════════════

    event FeatureMinted(
        address indexed wallet,
        uint256 indexed tokenId,
        bytes32 indexed featureType,
        uint256 price
    );
    event FeaturePriceSet(bytes32 indexed featureType, uint256 price);
    event FeatureActiveSet(bytes32 indexed featureType, bool active);
    event RevenueReceiverUpdated(address indexed oldReceiver, address indexed newReceiver);
    event FundsWithdrawn(address indexed receiver, uint256 amount);

    // ═══════════════════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════════════════

    error FeatureNotActive(bytes32 featureType);
    error FeatureNotConfigured(bytes32 featureType);
    error InsufficientPayment(uint256 required, uint256 provided);
    error NoFundsToWithdraw();
    error WithdrawFailed();
    error ZeroAddress();

    // ═══════════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param baseURI_ Base URI for token metadata
    /// @param revenueReceiver_ Address to receive mint fees and royalties
    /// @param royaltyBps_ Royalty in basis points (e.g., 500 = 5%)
    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address revenueReceiver_,
        uint96 royaltyBps_
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        if (revenueReceiver_ == address(0)) revert ZeroAddress();

        _baseTokenURI = baseURI_;
        revenueReceiver = revenueReceiver_;
        _setDefaultRoyalty(revenueReceiver_, royaltyBps_);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // MINT
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Mint a feature NFT with payment
    /// @param featureType_ The feature type to mint
    /// @return tokenId The minted token ID
    function mint(bytes32 featureType_) external payable returns (uint256 tokenId) {
        if (!featureActive[featureType_]) revert FeatureNotActive(featureType_);

        uint256 price = mintPrice[featureType_];
        if (price == 0) revert FeatureNotConfigured(featureType_);
        if (msg.value < price) revert InsufficientPayment(price, msg.value);

        tokenId = _nextTokenId++;
        featureType[tokenId] = featureType_;

        // Note: _mint triggers _update which handles _featureOwnershipCount
        _mint(msg.sender, tokenId);

        // Refund excess payment
        if (msg.value > price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - price}("");
            if (!success) revert WithdrawFailed();
        }

        emit FeatureMinted(msg.sender, tokenId, featureType_, price);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Check if a wallet owns any token of a specific feature type
    /// @param wallet Address to check
    /// @param featureType_ Feature type to query
    /// @return Whether the wallet has this feature
    function hasFeature(address wallet, bytes32 featureType_) external view returns (bool) {
        return _featureOwnershipCount[wallet][featureType_] > 0;
    }

    /// @notice Get the number of tokens of a feature type owned by a wallet
    /// @param wallet Address to check
    /// @param featureType_ Feature type to query
    /// @return Number of tokens owned
    function featureOwnershipCount(address wallet, bytes32 featureType_) external view returns (uint256) {
        return _featureOwnershipCount[wallet][featureType_];
    }

    /// @notice Get total supply of Dashboard NFTs
    /// @return Total number minted
    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // TRANSFER HOOKS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @dev Update feature ownership counts on transfer
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);

        bytes32 ft = featureType[tokenId];

        // Decrement sender's count
        if (from != address(0)) {
            _featureOwnershipCount[from][ft]--;
        }

        // Increment receiver's count
        if (to != address(0)) {
            _featureOwnershipCount[to][ft]++;
        }

        return from;
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // ADMIN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════════════════

    /// @notice Set the mint price for a feature type
    /// @param featureType_ Feature type to configure
    /// @param price Price in wei
    function setMintPrice(bytes32 featureType_, uint256 price) external onlyOwner {
        mintPrice[featureType_] = price;
        emit FeaturePriceSet(featureType_, price);
    }

    /// @notice Activate or deactivate a feature for minting
    /// @param featureType_ Feature type to configure
    /// @param active Whether minting is enabled
    function setFeatureActive(bytes32 featureType_, bool active) external onlyOwner {
        featureActive[featureType_] = active;
        emit FeatureActiveSet(featureType_, active);
    }

    /// @notice Update the base URI for token metadata
    /// @param baseURI_ New base URI
    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
    }

    /// @notice Update the revenue receiver address
    /// @param receiver New receiver address
    function setRevenueReceiver(address receiver) external onlyOwner {
        if (receiver == address(0)) revert ZeroAddress();
        address old = revenueReceiver;
        revenueReceiver = receiver;
        _setDefaultRoyalty(receiver, 500); // Maintain 5% royalty
        emit RevenueReceiverUpdated(old, receiver);
    }

    /// @notice Withdraw accumulated funds to revenue receiver
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();

        (bool success, ) = payable(revenueReceiver).call{value: balance}("");
        if (!success) revert WithdrawFailed();

        emit FundsWithdrawn(revenueReceiver, balance);
    }

    // ═══════════════════════════════════════════════════════════════════════════════
    // REQUIRED OVERRIDES
    // ═══════════════════════════════════════════════════════════════════════════════

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
