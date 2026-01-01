// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVarianceSwap} from "./interfaces/IVarianceSwap.sol";
import {IVarianceOracle} from "./interfaces/IVarianceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VarianceSwap
/// @notice Two-party variance swap contract for vBTC/BTC volatility exposure
/// @dev Enables long/short volatility positions with full upfront collateralization
contract VarianceSwap is IVarianceSwap, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    uint256 public constant MAX_VARIANCE = 1e18; // 100% annualized variance

    /// @inheritdoc IVarianceSwap
    uint256 public constant MIN_OBSERVATION_PERIOD = 7 days;

    /// @inheritdoc IVarianceSwap
    uint256 public constant MAX_OBSERVATION_PERIOD = 365 days;

    /// @inheritdoc IVarianceSwap
    uint256 public constant ANNUALIZATION_FACTOR = 252;

    /// @dev Precision for fixed-point math
    uint256 private constant PRECISION = 1e18;

    /// @dev Minimum observation frequency (1 hour)
    uint256 private constant MIN_OBSERVATION_FREQUENCY = 1 hours;

    /// @inheritdoc IVarianceSwap
    address public immutable oracle;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    uint256 public totalSwaps;

    /// @dev Mapping of swap ID to terms
    mapping(uint256 => SwapTerms) private _terms;

    /// @dev Mapping of swap ID to position
    mapping(uint256 => SwapPosition) private _positions;

    /// @dev Mapping of swap ID to observation data
    mapping(uint256 => SwapObservationData) private _observationData;

    /// @dev Observation data for variance calculation
    struct SwapObservationData {
        uint256 lastObservationTime;    // Timestamp of last observation
        uint256 sumSquaredLogReturns;   // Running sum of squared log returns
        int256 lastLogReturn;           // Most recent log return
        uint256 lastPriceRatio;         // Most recent price ratio
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _oracle Address of variance oracle
    constructor(address _oracle) {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = _oracle;
    }

    /*//////////////////////////////////////////////////////////////
                          CREATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    function createLongSwap(
        SwapTerms calldata terms,
        uint256 collateralAmount
    ) external nonReentrant returns (uint256 swapId) {
        _validateTerms(terms);

        uint256 requiredCollateral = calculateLongCollateral(terms);
        if (collateralAmount < requiredCollateral) {
            revert InsufficientCollateral(requiredCollateral, collateralAmount);
        }

        swapId = ++totalSwaps;

        _terms[swapId] = terms;
        _positions[swapId] = SwapPosition({
            longParty: msg.sender,
            shortParty: address(0),
            longCollateral: collateralAmount,
            shortCollateral: 0,
            startTime: 0,
            endTime: 0,
            observationCount: 0,
            state: SwapState.OPEN
        });

        // Transfer collateral
        IERC20(terms.collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        emit SwapCreated(swapId, msg.sender, true, terms);
    }

    /// @inheritdoc IVarianceSwap
    function createShortSwap(
        SwapTerms calldata terms,
        uint256 collateralAmount
    ) external nonReentrant returns (uint256 swapId) {
        _validateTerms(terms);

        uint256 requiredCollateral = calculateShortCollateral(terms);
        if (collateralAmount < requiredCollateral) {
            revert InsufficientCollateral(requiredCollateral, collateralAmount);
        }

        swapId = ++totalSwaps;

        _terms[swapId] = terms;
        _positions[swapId] = SwapPosition({
            longParty: address(0),
            shortParty: msg.sender,
            longCollateral: 0,
            shortCollateral: collateralAmount,
            startTime: 0,
            endTime: 0,
            observationCount: 0,
            state: SwapState.OPEN
        });

        // Transfer collateral
        IERC20(terms.collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        emit SwapCreated(swapId, msg.sender, false, terms);
    }

    /// @inheritdoc IVarianceSwap
    function matchSwap(
        uint256 swapId,
        uint256 collateralAmount
    ) external nonReentrant {
        SwapPosition storage position = _positions[swapId];
        SwapTerms memory terms = _terms[swapId];

        if (position.state != SwapState.OPEN) {
            revert SwapNotOpen(swapId);
        }

        bool creatorIsLong = position.longParty != address(0);

        if (creatorIsLong) {
            // Creator is long, matcher becomes short
            if (msg.sender == position.longParty) revert CannotMatchOwnSwap();

            uint256 requiredCollateral = calculateShortCollateral(terms);
            if (collateralAmount < requiredCollateral) {
                revert InsufficientCollateral(requiredCollateral, collateralAmount);
            }

            position.shortParty = msg.sender;
            position.shortCollateral = collateralAmount;
        } else {
            // Creator is short, matcher becomes long
            if (msg.sender == position.shortParty) revert CannotMatchOwnSwap();

            uint256 requiredCollateral = calculateLongCollateral(terms);
            if (collateralAmount < requiredCollateral) {
                revert InsufficientCollateral(requiredCollateral, collateralAmount);
            }

            position.longParty = msg.sender;
            position.longCollateral = collateralAmount;
        }

        // Start observation period
        position.startTime = block.timestamp;
        position.endTime = block.timestamp + terms.observationPeriod;
        position.state = SwapState.ACTIVE;

        // Initialize observation data with current price
        uint256 currentRatio = IVarianceOracle(oracle).getCurrentPriceRatio();
        _observationData[swapId] = SwapObservationData({
            lastObservationTime: block.timestamp,
            sumSquaredLogReturns: 0,
            lastLogReturn: 0,
            lastPriceRatio: currentRatio
        });

        // Transfer collateral from matcher
        IERC20(terms.collateralToken).safeTransferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        emit SwapMatched(
            swapId,
            position.longParty,
            position.shortParty,
            position.startTime,
            position.endTime
        );
    }

    /// @inheritdoc IVarianceSwap
    function cancelSwap(uint256 swapId) external nonReentrant {
        SwapPosition storage position = _positions[swapId];
        SwapTerms storage terms = _terms[swapId];

        if (position.state != SwapState.OPEN) {
            revert SwapNotOpen(swapId);
        }

        // Only creator can cancel
        bool creatorIsLong = position.longParty != address(0);
        address creator = creatorIsLong ? position.longParty : position.shortParty;

        if (msg.sender != creator) {
            revert NotSwapCreator(swapId);
        }

        uint256 collateralToReturn = creatorIsLong
            ? position.longCollateral
            : position.shortCollateral;

        position.state = SwapState.CANCELLED;

        // Return collateral
        IERC20(terms.collateralToken).safeTransfer(creator, collateralToReturn);

        emit SwapCancelled(swapId, creator);
    }

    /*//////////////////////////////////////////////////////////////
                        OBSERVATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    function recordObservation(uint256 swapId) external {
        SwapPosition storage position = _positions[swapId];
        SwapTerms storage terms = _terms[swapId];
        SwapObservationData storage obsData = _observationData[swapId];

        if (position.state != SwapState.ACTIVE) {
            revert SwapNotActive(swapId);
        }

        // Check if observation is due
        uint256 nextObservation = obsData.lastObservationTime + terms.observationFrequency;
        if (block.timestamp < nextObservation) {
            revert ObservationNotDue(nextObservation);
        }

        // Get current price ratio
        uint256 currentRatio = IVarianceOracle(oracle).getCurrentPriceRatio();

        // Calculate log return
        int256 logReturn = IVarianceOracle(oracle).calculateLogReturn(
            currentRatio,
            obsData.lastPriceRatio
        );

        // Add squared log return to sum
        uint256 squaredReturn = uint256(logReturn >= 0 ? logReturn * logReturn : (-logReturn) * (-logReturn));
        obsData.sumSquaredLogReturns += squaredReturn / PRECISION; // Adjust for double precision

        // Update observation data
        obsData.lastObservationTime = block.timestamp;
        obsData.lastLogReturn = logReturn;
        obsData.lastPriceRatio = currentRatio;

        position.observationCount++;

        emit ObservationRecorded(swapId, position.observationCount, currentRatio, logReturn);

        // Check if observation period ended
        if (block.timestamp >= position.endTime) {
            position.state = SwapState.MATURED;
        }
    }

    /// @inheritdoc IVarianceSwap
    function batchRecordObservations(uint256[] calldata swapIds) external {
        for (uint256 i = 0; i < swapIds.length; i++) {
            // Skip if not due or not active (don't revert)
            if (_positions[swapIds[i]].state == SwapState.ACTIVE && isObservationDue(swapIds[i])) {
                this.recordObservation(swapIds[i]);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                        SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    function settle(uint256 swapId) external nonReentrant returns (SettlementResult memory result) {
        SwapPosition storage position = _positions[swapId];
        SwapTerms storage terms = _terms[swapId];
        SwapObservationData storage obsData = _observationData[swapId];

        if (position.state != SwapState.MATURED) {
            revert SwapNotMatured(swapId);
        }

        // Calculate realized variance
        uint256 realizedVariance = _calculateRealizedVariance(swapId);

        // Cap at MAX_VARIANCE
        if (realizedVariance > MAX_VARIANCE) {
            realizedVariance = MAX_VARIANCE;
        }

        // Calculate PnL
        int256 pnl;
        if (realizedVariance >= terms.strikeVariance) {
            // Long wins: realized > strike
            pnl = int256(((realizedVariance - terms.strikeVariance) * terms.notionalAmount) / PRECISION);
        } else {
            // Short wins: strike > realized
            pnl = -int256(((terms.strikeVariance - realizedVariance) * terms.notionalAmount) / PRECISION);
        }

        // Determine payouts
        uint256 totalCollateral = position.longCollateral + position.shortCollateral;
        uint256 longPayout;
        uint256 shortPayout;

        if (pnl >= 0) {
            // Long wins
            uint256 longProfit = uint256(pnl);
            if (longProfit > position.shortCollateral) {
                longProfit = position.shortCollateral; // Cap at short's collateral
            }
            longPayout = position.longCollateral + longProfit;
            shortPayout = position.shortCollateral - longProfit;
            result.winner = position.longParty;
            result.winnerPayout = longPayout;
            result.loserReturn = shortPayout;
        } else {
            // Short wins
            uint256 shortProfit = uint256(-pnl);
            if (shortProfit > position.longCollateral) {
                shortProfit = position.longCollateral; // Cap at long's collateral
            }
            shortPayout = position.shortCollateral + shortProfit;
            longPayout = position.longCollateral - shortProfit;
            result.winner = position.shortParty;
            result.winnerPayout = shortPayout;
            result.loserReturn = longPayout;
        }

        result.realizedVariance = realizedVariance;
        result.pnl = pnl;

        // Update state
        position.state = SwapState.SETTLED;

        // Transfer payouts
        IERC20 collateral = IERC20(terms.collateralToken);
        if (longPayout > 0) {
            collateral.safeTransfer(position.longParty, longPayout);
        }
        if (shortPayout > 0) {
            collateral.safeTransfer(position.shortParty, shortPayout);
        }

        emit SwapSettled(swapId, realizedVariance, pnl, result.winner, result.winnerPayout);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceSwap
    function getSwap(uint256 swapId) external view returns (SwapPosition memory) {
        return _positions[swapId];
    }

    /// @inheritdoc IVarianceSwap
    function getTerms(uint256 swapId) external view returns (SwapTerms memory) {
        return _terms[swapId];
    }

    /// @inheritdoc IVarianceSwap
    function getCurrentRealizedVariance(uint256 swapId) external view returns (uint256) {
        return _calculateRealizedVariance(swapId);
    }

    /// @inheritdoc IVarianceSwap
    function getObservationCount(uint256 swapId) external view returns (uint256) {
        return _positions[swapId].observationCount;
    }

    /// @inheritdoc IVarianceSwap
    function getRequiredObservations(uint256 swapId) external view returns (uint256) {
        SwapTerms storage terms = _terms[swapId];
        return terms.observationPeriod / terms.observationFrequency;
    }

    /// @inheritdoc IVarianceSwap
    function isObservationDue(uint256 swapId) public view returns (bool) {
        SwapPosition storage position = _positions[swapId];
        SwapTerms storage terms = _terms[swapId];
        SwapObservationData storage obsData = _observationData[swapId];

        if (position.state != SwapState.ACTIVE) return false;

        uint256 nextObservation = obsData.lastObservationTime + terms.observationFrequency;
        return block.timestamp >= nextObservation;
    }

    /// @inheritdoc IVarianceSwap
    function getNextObservationTime(uint256 swapId) external view returns (uint256) {
        SwapTerms storage terms = _terms[swapId];
        SwapObservationData storage obsData = _observationData[swapId];
        return obsData.lastObservationTime + terms.observationFrequency;
    }

    /// @inheritdoc IVarianceSwap
    function estimateSettlement(uint256 swapId) external view returns (SettlementResult memory result) {
        SwapPosition storage position = _positions[swapId];
        SwapTerms storage terms = _terms[swapId];

        uint256 realizedVariance = _calculateRealizedVariance(swapId);

        // Cap at MAX_VARIANCE
        if (realizedVariance > MAX_VARIANCE) {
            realizedVariance = MAX_VARIANCE;
        }

        int256 pnl;
        if (realizedVariance >= terms.strikeVariance) {
            pnl = int256(((realizedVariance - terms.strikeVariance) * terms.notionalAmount) / PRECISION);
        } else {
            pnl = -int256(((terms.strikeVariance - realizedVariance) * terms.notionalAmount) / PRECISION);
        }

        if (pnl >= 0) {
            uint256 longProfit = uint256(pnl);
            if (longProfit > position.shortCollateral) {
                longProfit = position.shortCollateral;
            }
            result.winner = position.longParty;
            result.winnerPayout = position.longCollateral + longProfit;
            result.loserReturn = position.shortCollateral - longProfit;
        } else {
            uint256 shortProfit = uint256(-pnl);
            if (shortProfit > position.longCollateral) {
                shortProfit = position.longCollateral;
            }
            result.winner = position.shortParty;
            result.winnerPayout = position.shortCollateral + shortProfit;
            result.loserReturn = position.longCollateral - shortProfit;
        }

        result.realizedVariance = realizedVariance;
        result.pnl = pnl;
    }

    /// @inheritdoc IVarianceSwap
    function calculateLongCollateral(SwapTerms memory terms) public pure returns (uint256) {
        // Long max loss = notional × strike (if realized = 0)
        return (terms.notionalAmount * terms.strikeVariance) / PRECISION;
    }

    /// @inheritdoc IVarianceSwap
    function calculateShortCollateral(SwapTerms memory terms) public pure returns (uint256) {
        // Short max loss = notional × (maxVariance - strike)
        return (terms.notionalAmount * (MAX_VARIANCE - terms.strikeVariance)) / PRECISION;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Validate swap terms
    function _validateTerms(SwapTerms calldata terms) internal pure {
        if (terms.notionalAmount == 0) revert ZeroAmount();
        if (terms.collateralToken == address(0)) revert ZeroAddress();
        if (terms.strikeVariance == 0 || terms.strikeVariance >= MAX_VARIANCE) {
            revert InvalidStrikeVariance(terms.strikeVariance);
        }
        if (terms.observationPeriod < MIN_OBSERVATION_PERIOD ||
            terms.observationPeriod > MAX_OBSERVATION_PERIOD) {
            revert InvalidObservationPeriod(terms.observationPeriod);
        }
        if (terms.observationFrequency < MIN_OBSERVATION_FREQUENCY) {
            revert InvalidObservationFrequency(terms.observationFrequency);
        }
    }

    /// @dev Calculate realized variance from observation data
    function _calculateRealizedVariance(uint256 swapId) internal view returns (uint256) {
        SwapPosition storage position = _positions[swapId];
        SwapObservationData storage obsData = _observationData[swapId];

        if (position.observationCount == 0) return 0;

        // Annualize: variance = (252 / N) * sumSquaredLogReturns
        return (obsData.sumSquaredLogReturns * ANNUALIZATION_FACTOR) / position.observationCount;
    }
}
