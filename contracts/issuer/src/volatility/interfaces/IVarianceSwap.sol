// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IVarianceSwap
/// @notice Interface for two-party variance swap contracts on vBTC/BTC price ratio
/// @dev Enables long/short volatility exposure through realized variance settlement
interface IVarianceSwap {
    /*//////////////////////////////////////////////////////////////
                                ENUMS
    //////////////////////////////////////////////////////////////*/

    /// @notice Swap lifecycle states
    enum SwapState {
        OPEN,       // Awaiting counterparty match
        ACTIVE,     // Observation period running
        MATURED,    // Observations complete, awaiting settlement
        SETTLED,    // Settlement complete
        CANCELLED   // Cancelled before match
    }

    /*//////////////////////////////////////////////////////////////
                               STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Immutable terms of a variance swap
    struct SwapTerms {
        uint256 strikeVariance;         // Annualized variance strike (18 decimals)
        uint256 notionalAmount;         // Settlement notional in collateral token
        uint256 observationPeriod;      // Duration in seconds (7d, 30d, 90d)
        uint256 observationFrequency;   // Seconds between observations (86400 = daily)
        address collateralToken;        // Settlement token (wBTC, cbBTC, tBTC)
    }

    /// @notice Current state of a variance swap position
    struct SwapPosition {
        address longParty;              // Pays strike, receives realized
        address shortParty;             // Receives strike, pays realized
        uint256 longCollateral;         // Collateral posted by long
        uint256 shortCollateral;        // Collateral posted by short
        uint256 startTime;              // Observation period start
        uint256 endTime;                // Observation period end
        uint256 observationCount;       // Number of observations recorded
        SwapState state;
    }

    /// @notice Settlement calculation result
    struct SettlementResult {
        uint256 realizedVariance;       // Annualized realized variance (18 decimals)
        int256 pnl;                     // Settlement PnL (positive = long profits)
        address winner;                 // Party receiving settlement
        uint256 winnerPayout;           // Amount to winner
        uint256 loserReturn;            // Amount returned to loser
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new swap is created
    event SwapCreated(
        uint256 indexed swapId,
        address indexed creator,
        bool creatorIsLong,
        SwapTerms terms
    );

    /// @notice Emitted when a swap is matched by counterparty
    event SwapMatched(
        uint256 indexed swapId,
        address indexed longParty,
        address indexed shortParty,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when a price observation is recorded
    event ObservationRecorded(
        uint256 indexed swapId,
        uint256 indexed observationIndex,
        uint256 priceRatio,
        int256 logReturn
    );

    /// @notice Emitted when a swap is settled
    event SwapSettled(
        uint256 indexed swapId,
        uint256 realizedVariance,
        int256 pnl,
        address winner,
        uint256 payout
    );

    /// @notice Emitted when an unmatched swap is cancelled
    event SwapCancelled(
        uint256 indexed swapId,
        address indexed creator
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error SwapNotFound(uint256 swapId);
    error SwapNotOpen(uint256 swapId);
    error SwapNotActive(uint256 swapId);
    error SwapNotMatured(uint256 swapId);
    error SwapAlreadySettled(uint256 swapId);
    error InsufficientCollateral(uint256 required, uint256 provided);
    error InvalidStrikeVariance(uint256 strike);
    error InvalidObservationPeriod(uint256 period);
    error InvalidObservationFrequency(uint256 frequency);
    error CannotMatchOwnSwap();
    error ObservationNotDue(uint256 nextObservation);
    error ObservationsIncomplete(uint256 current, uint256 required);
    error NotSwapCreator(uint256 swapId);
    error ZeroAddress();
    error ZeroAmount();

    /*//////////////////////////////////////////////////////////////
                          CREATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Create a variance swap as the long volatility party
    /// @param terms Swap terms including strike, notional, period
    /// @param collateralAmount Collateral to post (must cover max loss)
    /// @return swapId Unique swap identifier
    function createLongSwap(
        SwapTerms calldata terms,
        uint256 collateralAmount
    ) external returns (uint256 swapId);

    /// @notice Create a variance swap as the short volatility party
    /// @param terms Swap terms including strike, notional, period
    /// @param collateralAmount Collateral to post (must cover max loss)
    /// @return swapId Unique swap identifier
    function createShortSwap(
        SwapTerms calldata terms,
        uint256 collateralAmount
    ) external returns (uint256 swapId);

    /// @notice Match an existing open swap as counterparty
    /// @param swapId Swap to match
    /// @param collateralAmount Collateral to post
    function matchSwap(uint256 swapId, uint256 collateralAmount) external;

    /// @notice Cancel an unmatched swap and reclaim collateral
    /// @param swapId Swap to cancel
    function cancelSwap(uint256 swapId) external;

    /*//////////////////////////////////////////////////////////////
                        OBSERVATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Record a price observation (permissionless)
    /// @param swapId Active swap
    /// @dev Reads from oracle, calculates log return, stores observation
    function recordObservation(uint256 swapId) external;

    /// @notice Batch record observations for multiple swaps
    /// @param swapIds Array of swap IDs
    function batchRecordObservations(uint256[] calldata swapIds) external;

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Settle a matured variance swap
    /// @param swapId Matured swap
    /// @return result Settlement details
    function settle(uint256 swapId) external returns (SettlementResult memory result);

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get swap position details
    function getSwap(uint256 swapId) external view returns (SwapPosition memory);

    /// @notice Get swap terms
    function getTerms(uint256 swapId) external view returns (SwapTerms memory);

    /// @notice Get current realized variance calculation (in-progress)
    function getCurrentRealizedVariance(uint256 swapId) external view returns (uint256);

    /// @notice Get number of observations recorded
    function getObservationCount(uint256 swapId) external view returns (uint256);

    /// @notice Get required observations for swap
    function getRequiredObservations(uint256 swapId) external view returns (uint256);

    /// @notice Check if observation is currently due
    function isObservationDue(uint256 swapId) external view returns (bool);

    /// @notice Get next observation timestamp
    function getNextObservationTime(uint256 swapId) external view returns (uint256);

    /// @notice Calculate estimated settlement (preview)
    function estimateSettlement(uint256 swapId) external view returns (SettlementResult memory);

    /// @notice Calculate required long collateral for given terms
    function calculateLongCollateral(SwapTerms calldata terms) external view returns (uint256);

    /// @notice Calculate required short collateral for given terms
    function calculateShortCollateral(SwapTerms calldata terms) external view returns (uint256);

    /// @notice Get oracle address
    function oracle() external view returns (address);

    /// @notice Get maximum variance cap
    function MAX_VARIANCE() external view returns (uint256);

    /// @notice Get minimum observation period
    function MIN_OBSERVATION_PERIOD() external view returns (uint256);

    /// @notice Get maximum observation period
    function MAX_OBSERVATION_PERIOD() external view returns (uint256);

    /// @notice Get annualization factor
    function ANNUALIZATION_FACTOR() external view returns (uint256);

    /// @notice Get total number of swaps created
    function totalSwaps() external view returns (uint256);
}
