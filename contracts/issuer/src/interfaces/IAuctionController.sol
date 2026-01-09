// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IAuctionController - Interface for issuer auction functionality
/// @notice Manages Dutch and English auctions for issuer-layer vault minting
interface IAuctionController {
    // ==================== Enums ====================

    enum AuctionType {
        DUTCH,
        ENGLISH
    }

    enum AuctionState {
        PENDING,
        ACTIVE,
        ENDED,
        FINALIZED
    }

    // ==================== Structs ====================

    struct DutchAuctionConfig {
        uint256 startPrice;
        uint256 floorPrice;
        uint256 decayRate; // Price decrease per second
        uint256 startTime;
        uint256 endTime;
    }

    struct EnglishAuctionConfig {
        uint256 reservePrice;
        uint256 minBidIncrement; // Basis points (100 = 1%)
        uint256 startTime;
        uint256 endTime;
        uint256 extensionWindow; // Seconds before end to trigger extension
        uint256 extensionDuration; // Seconds to extend on late bid
    }

    struct Auction {
        AuctionType auctionType;
        AuctionState state;
        uint256 maxSupply;
        uint256 mintedCount;
        address collateralToken;
    }

    struct Bid {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }

    // ==================== Events ====================

    event DutchAuctionCreated(
        uint256 indexed auctionId,
        uint256 maxSupply,
        uint256 startPrice,
        uint256 floorPrice,
        uint256 startTime,
        uint256 endTime
    );

    event EnglishAuctionCreated(
        uint256 indexed auctionId,
        uint256 maxSupply,
        uint256 reservePrice,
        uint256 startTime,
        uint256 endTime
    );

    event DutchPurchase(
        uint256 indexed auctionId,
        address indexed buyer,
        uint256 price,
        uint256 vaultId,
        uint256 treasureId
    );

    event BidPlaced(
        uint256 indexed auctionId,
        uint256 indexed slot,
        address indexed bidder,
        uint256 amount
    );

    event BidRefunded(
        uint256 indexed auctionId,
        uint256 indexed slot,
        address indexed bidder,
        uint256 amount
    );

    event SlotSettled(
        uint256 indexed auctionId,
        uint256 indexed slot,
        address indexed winner,
        uint256 vaultId,
        uint256 treasureId,
        uint256 winningBid
    );

    event AuctionFinalized(uint256 indexed auctionId);

    // ==================== Errors ====================

    error AuctionNotFound(uint256 auctionId);
    error AuctionNotActive(uint256 auctionId);
    error AuctionNotEnded(uint256 auctionId);
    error AuctionAlreadyFinalized(uint256 auctionId);
    error AuctionSoldOut(uint256 auctionId);
    error InvalidAuctionType(uint256 auctionId);
    error InvalidTimeWindow();
    error InvalidPriceConfig();
    error BidTooLow(uint256 bid, uint256 required);
    error SlotNotFound(uint256 auctionId, uint256 slot);
    error AlreadySettled(uint256 auctionId, uint256 slot);
    error NoBidsOnSlot(uint256 auctionId, uint256 slot);
    error ZeroMaxSupply();
    error ZeroAddress();
    error UnsupportedCollateral(address collateralToken);

    // ==================== Dutch Auction Functions ====================

    /// @notice Create a new Dutch (descending price) auction
    /// @param maxSupply Maximum number of vaults to mint
    /// @param collateralToken ERC-20 token for payments
    /// @param config Dutch auction configuration
    /// @return auctionId The created auction ID
    function createDutchAuction(
        uint256 maxSupply,
        address collateralToken,
        DutchAuctionConfig calldata config
    ) external returns (uint256 auctionId);

    /// @notice Get the current price of a Dutch auction
    /// @param auctionId The auction ID
    /// @return price Current price based on decay
    function getCurrentPrice(uint256 auctionId) external view returns (uint256 price);

    /// @notice Purchase from a Dutch auction at current price
    /// @param auctionId The auction ID
    /// @return vaultId The minted vault token ID
    function purchaseDutch(uint256 auctionId) external returns (uint256 vaultId);

    // ==================== English Auction Functions ====================

    /// @notice Create a new English (ascending bid) auction
    /// @param maxSupply Maximum number of vaults (each is a slot)
    /// @param collateralToken ERC-20 token for bids
    /// @param config English auction configuration
    /// @return auctionId The created auction ID
    function createEnglishAuction(
        uint256 maxSupply,
        address collateralToken,
        EnglishAuctionConfig calldata config
    ) external returns (uint256 auctionId);

    /// @notice Place a bid on an English auction slot
    /// @param auctionId The auction ID
    /// @param slot The slot to bid on (0 to maxSupply-1)
    /// @param amount Bid amount
    function placeBid(uint256 auctionId, uint256 slot, uint256 amount) external;

    /// @notice Get the highest bid on a slot
    /// @param auctionId The auction ID
    /// @param slot The slot
    /// @return bid The highest bid
    function getHighestBid(uint256 auctionId, uint256 slot) external view returns (Bid memory bid);

    /// @notice Settle a slot after auction ends (mint vault to winner)
    /// @param auctionId The auction ID
    /// @param slot The slot to settle
    /// @return vaultId The minted vault token ID
    function settleSlot(uint256 auctionId, uint256 slot) external returns (uint256 vaultId);

    // ==================== Common Functions ====================

    /// @notice Finalize an auction after all slots are settled
    /// @param auctionId The auction ID
    function finalizeAuction(uint256 auctionId) external;

    /// @notice Get auction details
    /// @param auctionId The auction ID
    /// @return auction The auction struct
    function getAuction(uint256 auctionId) external view returns (Auction memory auction);

    /// @notice Get the current state of an auction
    /// @param auctionId The auction ID
    /// @return state The auction state
    function getAuctionState(uint256 auctionId) external view returns (AuctionState state);

    /// @notice Get Dutch auction configuration
    /// @param auctionId The auction ID
    /// @return config The Dutch config
    function getDutchConfig(uint256 auctionId) external view returns (DutchAuctionConfig memory config);

    /// @notice Get English auction configuration
    /// @param auctionId The auction ID
    /// @return config The English config
    function getEnglishConfig(uint256 auctionId) external view returns (EnglishAuctionConfig memory config);
}
