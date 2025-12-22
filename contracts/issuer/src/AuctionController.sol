// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {IAuctionController} from "./interfaces/IAuctionController.sol";
import {ITreasureNFT} from "./interfaces/ITreasureNFT.sol";

/// @notice Minimal interface for protocol vault minting
interface IVaultMint {
    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount,
        uint8 tier
    ) external returns (uint256 tokenId);
}

/// @title AuctionController - Manages Dutch and English auctions for vault minting
/// @notice Issuer-layer contract for auction-based vault creation
/// @dev Calls protocol mint() to create vaults with auction proceeds as collateral
contract AuctionController is IAuctionController, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ==================== Immutables ====================

    ITreasureNFT public immutable treasureNFT;
    IVaultMint public immutable protocol;

    // ==================== State ====================

    uint256 private _nextAuctionId;

    mapping(uint256 => Auction) private _auctions;
    mapping(uint256 => DutchAuctionConfig) private _dutchConfigs;
    mapping(uint256 => EnglishAuctionConfig) private _englishConfigs;

    // English auction bids: auctionId => slot => Bid
    mapping(uint256 => mapping(uint256 => Bid)) private _highestBids;
    mapping(uint256 => mapping(uint256 => bool)) private _slotSettled;

    // ==================== Constructor ====================

    constructor(
        address treasureNFT_,
        address protocol_
    ) Ownable(msg.sender) {
        treasureNFT = ITreasureNFT(treasureNFT_);
        protocol = IVaultMint(protocol_);
    }

    // ==================== Dutch Auction Functions ====================

    /// @inheritdoc IAuctionController
    function createDutchAuction(
        uint256 maxSupply,
        address collateralToken,
        uint8 tier,
        DutchAuctionConfig calldata config
    ) external onlyOwner returns (uint256 auctionId) {
        if (maxSupply == 0) revert ZeroMaxSupply();
        if (config.startTime >= config.endTime) revert InvalidTimeWindow();
        if (config.startPrice <= config.floorPrice) revert InvalidPriceConfig();

        auctionId = _nextAuctionId++;

        _auctions[auctionId] = Auction({
            auctionType: AuctionType.DUTCH,
            state: AuctionState.PENDING,
            maxSupply: maxSupply,
            mintedCount: 0,
            collateralToken: collateralToken,
            tier: tier
        });

        _dutchConfigs[auctionId] = config;

        emit DutchAuctionCreated(
            auctionId,
            maxSupply,
            config.startPrice,
            config.floorPrice,
            config.startTime,
            config.endTime
        );
    }

    /// @inheritdoc IAuctionController
    function getCurrentPrice(uint256 auctionId) external view returns (uint256 price) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.DUTCH) revert InvalidAuctionType(auctionId);

        DutchAuctionConfig storage config = _dutchConfigs[auctionId];

        if (block.timestamp < config.startTime) {
            return config.startPrice;
        }

        if (block.timestamp >= config.endTime) {
            return config.floorPrice;
        }

        return _calculateDutchPrice(config);
    }

    /// @inheritdoc IAuctionController
    function purchaseDutch(uint256 auctionId) external nonReentrant returns (uint256 vaultId) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.DUTCH) revert InvalidAuctionType(auctionId);

        DutchAuctionConfig storage config = _dutchConfigs[auctionId];

        if (block.timestamp < config.startTime) revert AuctionNotActive(auctionId);
        if (block.timestamp > config.endTime) {
            auction.state = AuctionState.ENDED;
            revert AuctionNotActive(auctionId);
        }

        if (auction.mintedCount >= auction.maxSupply) revert AuctionSoldOut(auctionId);

        // Update state to ACTIVE if first purchase
        if (auction.state == AuctionState.PENDING) {
            auction.state = AuctionState.ACTIVE;
        }

        uint256 price = _calculateDutchPrice(config);

        // Transfer payment from buyer
        IERC20(auction.collateralToken).safeTransferFrom(msg.sender, address(this), price);

        // Mint treasure
        uint256 treasureId = treasureNFT.mint(address(this));

        // Approve protocol
        IERC721(address(treasureNFT)).approve(address(protocol), treasureId);
        IERC20(auction.collateralToken).approve(address(protocol), price);

        // Mint vault (price becomes collateral)
        vaultId = protocol.mint(
            address(treasureNFT),
            treasureId,
            auction.collateralToken,
            price,
            auction.tier
        );

        // Transfer vault to buyer
        IERC721(address(protocol)).transferFrom(address(this), msg.sender, vaultId);

        auction.mintedCount++;

        // Check if sold out
        if (auction.mintedCount >= auction.maxSupply) {
            auction.state = AuctionState.ENDED;
        }

        emit DutchPurchase(auctionId, msg.sender, price, vaultId, treasureId);
    }

    function _calculateDutchPrice(DutchAuctionConfig storage config) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - config.startTime;
        uint256 decay = elapsed * config.decayRate;

        if (config.startPrice <= decay + config.floorPrice) {
            return config.floorPrice;
        }

        return config.startPrice - decay;
    }

    // ==================== English Auction Functions ====================

    /// @inheritdoc IAuctionController
    function createEnglishAuction(
        uint256 maxSupply,
        address collateralToken,
        uint8 tier,
        EnglishAuctionConfig calldata config
    ) external onlyOwner returns (uint256 auctionId) {
        if (maxSupply == 0) revert ZeroMaxSupply();
        if (config.startTime >= config.endTime) revert InvalidTimeWindow();

        auctionId = _nextAuctionId++;

        _auctions[auctionId] = Auction({
            auctionType: AuctionType.ENGLISH,
            state: AuctionState.PENDING,
            maxSupply: maxSupply,
            mintedCount: 0,
            collateralToken: collateralToken,
            tier: tier
        });

        _englishConfigs[auctionId] = config;

        emit EnglishAuctionCreated(
            auctionId,
            maxSupply,
            config.reservePrice,
            config.startTime,
            config.endTime
        );
    }

    /// @inheritdoc IAuctionController
    function placeBid(uint256 auctionId, uint256 slot, uint256 amount) external nonReentrant {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.ENGLISH) revert InvalidAuctionType(auctionId);
        if (slot >= auction.maxSupply) revert SlotNotFound(auctionId, slot);

        EnglishAuctionConfig storage config = _englishConfigs[auctionId];

        if (block.timestamp < config.startTime) revert AuctionNotActive(auctionId);
        if (block.timestamp > config.endTime) {
            auction.state = AuctionState.ENDED;
            revert AuctionNotActive(auctionId);
        }

        // Update state to ACTIVE if first bid
        if (auction.state == AuctionState.PENDING) {
            auction.state = AuctionState.ACTIVE;
        }

        Bid storage currentBid = _highestBids[auctionId][slot];

        // Calculate minimum required bid
        uint256 minRequired;
        if (currentBid.bidder == address(0)) {
            minRequired = config.reservePrice;
        } else {
            minRequired = currentBid.amount + (currentBid.amount * config.minBidIncrement / 10000);
        }

        if (amount < minRequired) revert BidTooLow(amount, minRequired);

        // Transfer new bid
        IERC20(auction.collateralToken).safeTransferFrom(msg.sender, address(this), amount);

        // Refund previous bidder
        if (currentBid.bidder != address(0)) {
            IERC20(auction.collateralToken).safeTransfer(currentBid.bidder, currentBid.amount);
            emit BidRefunded(auctionId, slot, currentBid.bidder, currentBid.amount);
        }

        // Record new highest bid
        _highestBids[auctionId][slot] = Bid({
            bidder: msg.sender,
            amount: amount,
            timestamp: block.timestamp
        });

        // Extend auction if bid in extension window
        if (config.endTime - block.timestamp < config.extensionWindow) {
            config.endTime = block.timestamp + config.extensionDuration;
        }

        emit BidPlaced(auctionId, slot, msg.sender, amount);
    }

    /// @inheritdoc IAuctionController
    function getHighestBid(uint256 auctionId, uint256 slot) external view returns (Bid memory bid) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (slot >= auction.maxSupply) revert SlotNotFound(auctionId, slot);

        return _highestBids[auctionId][slot];
    }

    /// @inheritdoc IAuctionController
    function settleSlot(uint256 auctionId, uint256 slot) external nonReentrant returns (uint256 vaultId) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.ENGLISH) revert InvalidAuctionType(auctionId);
        if (slot >= auction.maxSupply) revert SlotNotFound(auctionId, slot);

        EnglishAuctionConfig storage config = _englishConfigs[auctionId];

        if (block.timestamp < config.endTime) revert AuctionNotEnded(auctionId);
        if (_slotSettled[auctionId][slot]) revert AlreadySettled(auctionId, slot);

        Bid storage winningBid = _highestBids[auctionId][slot];
        if (winningBid.bidder == address(0)) revert NoBidsOnSlot(auctionId, slot);

        // Mark as settled before external calls
        _slotSettled[auctionId][slot] = true;
        auction.state = AuctionState.ENDED;

        // Mint treasure
        uint256 treasureId = treasureNFT.mint(address(this));

        // Approve protocol
        IERC721(address(treasureNFT)).approve(address(protocol), treasureId);
        IERC20(auction.collateralToken).approve(address(protocol), winningBid.amount);

        // Mint vault (winning bid becomes collateral)
        vaultId = protocol.mint(
            address(treasureNFT),
            treasureId,
            auction.collateralToken,
            winningBid.amount,
            auction.tier
        );

        // Transfer vault to winner
        IERC721(address(protocol)).transferFrom(address(this), winningBid.bidder, vaultId);

        auction.mintedCount++;

        emit SlotSettled(auctionId, slot, winningBid.bidder, vaultId, treasureId, winningBid.amount);
    }

    // ==================== Common Functions ====================

    /// @inheritdoc IAuctionController
    function finalizeAuction(uint256 auctionId) external {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.state == AuctionState.FINALIZED) revert AuctionAlreadyFinalized(auctionId);

        // For Dutch: finalized when sold out or ended
        // For English: finalized when all slots are settled or explicitly finalized
        auction.state = AuctionState.FINALIZED;

        emit AuctionFinalized(auctionId);
    }

    /// @inheritdoc IAuctionController
    function getAuction(uint256 auctionId) external view returns (Auction memory auction) {
        auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
    }

    /// @inheritdoc IAuctionController
    function getAuctionState(uint256 auctionId) external view returns (AuctionState state) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);

        // Update state based on time if not already finalized
        if (auction.state == AuctionState.FINALIZED) {
            return AuctionState.FINALIZED;
        }

        if (auction.auctionType == AuctionType.DUTCH) {
            DutchAuctionConfig storage config = _dutchConfigs[auctionId];
            if (block.timestamp < config.startTime) return AuctionState.PENDING;
            if (block.timestamp >= config.endTime || auction.mintedCount >= auction.maxSupply) {
                return AuctionState.ENDED;
            }
            return AuctionState.ACTIVE;
        } else {
            EnglishAuctionConfig storage config = _englishConfigs[auctionId];
            if (block.timestamp < config.startTime) return AuctionState.PENDING;
            if (block.timestamp >= config.endTime) return AuctionState.ENDED;
            return AuctionState.ACTIVE;
        }
    }

    /// @inheritdoc IAuctionController
    function getDutchConfig(uint256 auctionId) external view returns (DutchAuctionConfig memory config) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.DUTCH) revert InvalidAuctionType(auctionId);

        return _dutchConfigs[auctionId];
    }

    /// @inheritdoc IAuctionController
    function getEnglishConfig(uint256 auctionId) external view returns (EnglishAuctionConfig memory config) {
        Auction storage auction = _auctions[auctionId];
        if (auction.maxSupply == 0) revert AuctionNotFound(auctionId);
        if (auction.auctionType != AuctionType.ENGLISH) revert InvalidAuctionType(auctionId);

        return _englishConfigs[auctionId];
    }

    /// @notice Check if a slot has been settled
    /// @param auctionId The auction ID
    /// @param slot The slot
    /// @return settled Whether the slot is settled
    function isSlotSettled(uint256 auctionId, uint256 slot) external view returns (bool settled) {
        return _slotSettled[auctionId][slot];
    }
}
