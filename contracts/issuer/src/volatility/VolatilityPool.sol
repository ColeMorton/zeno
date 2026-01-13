// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVolatilityPool} from "./interfaces/IVolatilityPool.sol";
import {IVarianceOracle} from "./interfaces/IVarianceOracle.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VolatilityPool
/// @notice Perpetual volatility pool with socialized P&L for vBTC
/// @dev Enables long/short volatility exposure via pool-based model:
///      - Long vol depositors share one pool
///      - Short vol depositors share one pool
///      - Variance P&L continuously transfers between pools
///      - Users hold proportional shares and can enter/exit anytime
contract VolatilityPool is IVolatilityPool, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Precision for fixed-point math (18 decimals)
    uint256 private constant PRECISION = 1e18;

    /// @dev Days per year for annualization
    uint256 private constant DAYS_PER_YEAR = 365;

    /// @dev Maximum observations to iterate (prevents gas exhaustion)
    uint256 private constant MAX_VARIANCE_OBSERVATIONS = 168;

    /// @dev Virtual shares offset to prevent first-depositor inflation attack
    uint256 private constant VIRTUAL_SHARES = 1e3;

    /// @dev Virtual assets offset to prevent first-depositor inflation attack
    uint256 private constant VIRTUAL_ASSETS = 1e3;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    address public immutable override vBTC;

    /// @inheritdoc IVolatilityPool
    address public immutable override varianceOracle;

    /// @inheritdoc IVolatilityPool
    uint256 public immutable override strikeVariance;

    /// @inheritdoc IVolatilityPool
    uint256 public immutable override settlementInterval;

    /// @inheritdoc IVolatilityPool
    uint256 public immutable override varianceWindow;

    /// @inheritdoc IVolatilityPool
    uint256 public immutable override minDeposit;

    /*//////////////////////////////////////////////////////////////
                             MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    uint256 public override longPoolAssets;

    /// @inheritdoc IVolatilityPool
    uint256 public override shortPoolAssets;

    /// @inheritdoc IVolatilityPool
    uint256 public override longPoolShares;

    /// @inheritdoc IVolatilityPool
    uint256 public override shortPoolShares;

    /// @inheritdoc IVolatilityPool
    uint256 public override lastSettlementTime;

    /// @inheritdoc IVolatilityPool
    uint256 public override lastSettlementVariance;

    /// @dev User long share balances
    mapping(address => uint256) private _longShares;

    /// @dev User short share balances
    mapping(address => uint256) private _shortShares;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _vBTC vestedBTC token address
    /// @param _varianceOracle Variance oracle address
    /// @param _strikeVariance Strike variance (18 decimals, e.g., 4e16 = 4%)
    /// @param _settlementInterval Settlement interval in seconds (e.g., 1 days)
    /// @param _varianceWindow Rolling variance window in seconds (e.g., 7 days)
    /// @param _minDeposit Minimum deposit amount (e.g., 1e6 = 0.01 vBTC)
    constructor(
        address _vBTC,
        address _varianceOracle,
        uint256 _strikeVariance,
        uint256 _settlementInterval,
        uint256 _varianceWindow,
        uint256 _minDeposit
    ) {
        if (_vBTC == address(0)) revert ZeroAddress();
        if (_varianceOracle == address(0)) revert ZeroAddress();
        if (_strikeVariance == 0) revert ZeroAmount();
        if (_settlementInterval == 0) revert ZeroAmount();
        if (_varianceWindow == 0) revert ZeroAmount();
        if (_minDeposit == 0) revert ZeroAmount();

        vBTC = _vBTC;
        varianceOracle = _varianceOracle;
        strikeVariance = _strikeVariance;
        settlementInterval = _settlementInterval;
        varianceWindow = _varianceWindow;
        minDeposit = _minDeposit;

        lastSettlementTime = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    function depositLong(uint256 assets) external override nonReentrant returns (uint256 shares) {
        if (assets < minDeposit) revert ZeroAmount();

        // Settle pending P&L to ensure fair share pricing
        _settleIfDue();

        // Calculate shares using virtual offset to prevent inflation attack
        shares = (assets * (longPoolShares + VIRTUAL_SHARES)) / (longPoolAssets + VIRTUAL_ASSETS);

        // Update state
        longPoolAssets += assets;
        longPoolShares += shares;
        _longShares[msg.sender] += shares;

        // Transfer vBTC from user
        IERC20(vBTC).safeTransferFrom(msg.sender, address(this), assets);

        emit DepositedLong(msg.sender, assets, shares);
    }

    /// @inheritdoc IVolatilityPool
    function depositShort(uint256 assets) external override nonReentrant returns (uint256 shares) {
        if (assets < minDeposit) revert ZeroAmount();

        // Settle pending P&L to ensure fair share pricing
        _settleIfDue();

        // Calculate shares using virtual offset to prevent inflation attack
        shares = (assets * (shortPoolShares + VIRTUAL_SHARES)) / (shortPoolAssets + VIRTUAL_ASSETS);

        // Update state
        shortPoolAssets += assets;
        shortPoolShares += shares;
        _shortShares[msg.sender] += shares;

        // Transfer vBTC from user
        IERC20(vBTC).safeTransferFrom(msg.sender, address(this), assets);

        emit DepositedShort(msg.sender, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                         WITHDRAW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    function withdrawLong(uint256 shares) external override nonReentrant returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (_longShares[msg.sender] < shares) {
            revert InsufficientShares(shares, _longShares[msg.sender]);
        }

        // Settle pending P&L
        _settleIfDue();

        // Calculate assets using virtual offset for consistent pricing
        assets = (shares * (longPoolAssets + VIRTUAL_ASSETS)) / (longPoolShares + VIRTUAL_SHARES);

        // Update state
        longPoolAssets -= assets;
        longPoolShares -= shares;
        _longShares[msg.sender] -= shares;

        // Transfer vBTC to user
        IERC20(vBTC).safeTransfer(msg.sender, assets);

        emit WithdrawnLong(msg.sender, assets, shares);
    }

    /// @inheritdoc IVolatilityPool
    function withdrawShort(uint256 shares) external override nonReentrant returns (uint256 assets) {
        if (shares == 0) revert ZeroAmount();
        if (_shortShares[msg.sender] < shares) {
            revert InsufficientShares(shares, _shortShares[msg.sender]);
        }

        // Settle pending P&L
        _settleIfDue();

        // Calculate assets using virtual offset for consistent pricing
        assets = (shares * (shortPoolAssets + VIRTUAL_ASSETS)) / (shortPoolShares + VIRTUAL_SHARES);

        // Update state
        shortPoolAssets -= assets;
        shortPoolShares -= shares;
        _shortShares[msg.sender] -= shares;

        // Transfer vBTC to user
        IERC20(vBTC).safeTransfer(msg.sender, assets);

        emit WithdrawnShort(msg.sender, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                         SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    function settle() external override {
        _settle();
    }

    /// @dev Internal settlement logic
    function _settle() internal {
        // Check if settlement is due
        if (block.timestamp < lastSettlementTime + settlementInterval) {
            revert SettlementNotDue(lastSettlementTime + settlementInterval);
        }

        // Get rolling variance from oracle
        uint256 currentVariance = _getRollingVariance();

        // Calculate variance delta from strike
        int256 varianceDelta = int256(currentVariance) - int256(strikeVariance);

        // Calculate matched amount (P&L only applies to matched portion)
        uint256 matchedAmount = _min(longPoolAssets, shortPoolAssets);

        // Calculate time fraction for annualization
        uint256 elapsed = block.timestamp - lastSettlementTime;
        uint256 timeFraction = (elapsed * PRECISION) / (DAYS_PER_YEAR * 1 days);

        // Calculate P&L to transfer
        // pnl = matchedAmount × varianceDelta × timeFraction / PRECISION²
        // Reordered to prevent overflow: divide intermediately
        int256 pnlToTransfer;
        if (matchedAmount > 0 && timeFraction > 0) {
            pnlToTransfer = (int256(matchedAmount) * varianceDelta / int256(PRECISION))
                * int256(timeFraction) / int256(PRECISION);
        }

        // Transfer between pools
        if (pnlToTransfer > 0) {
            // Long vol wins: realized > strike, transfer from short to long
            uint256 transfer = _min(uint256(pnlToTransfer), shortPoolAssets);
            shortPoolAssets -= transfer;
            longPoolAssets += transfer;
        } else if (pnlToTransfer < 0) {
            // Short vol wins: realized < strike, transfer from long to short
            uint256 transfer = _min(uint256(-pnlToTransfer), longPoolAssets);
            longPoolAssets -= transfer;
            shortPoolAssets += transfer;
        }

        // Update state
        lastSettlementTime = block.timestamp;
        lastSettlementVariance = currentVariance;

        emit Settled(block.timestamp, currentVariance, pnlToTransfer);
    }

    /// @dev Settle if settlement interval has passed
    function _settleIfDue() internal {
        if (block.timestamp >= lastSettlementTime + settlementInterval) {
            _settle();
        }
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVolatilityPool
    function previewWithdrawLong(uint256 shares) external view override returns (uint256 assets) {
        return (shares * (longPoolAssets + VIRTUAL_ASSETS)) / (longPoolShares + VIRTUAL_SHARES);
    }

    /// @inheritdoc IVolatilityPool
    function previewWithdrawShort(uint256 shares) external view override returns (uint256 assets) {
        return (shares * (shortPoolAssets + VIRTUAL_ASSETS)) / (shortPoolShares + VIRTUAL_SHARES);
    }

    /// @inheritdoc IVolatilityPool
    function getCurrentVariance() external view override returns (uint256 variance) {
        return _getRollingVariance();
    }

    /// @inheritdoc IVolatilityPool
    function longSharesOf(address user) external view override returns (uint256 shares) {
        return _longShares[user];
    }

    /// @inheritdoc IVolatilityPool
    function shortSharesOf(address user) external view override returns (uint256 shares) {
        return _shortShares[user];
    }

    /// @inheritdoc IVolatilityPool
    function isSettlementDue() external view override returns (bool) {
        return block.timestamp >= lastSettlementTime + settlementInterval;
    }

    /// @inheritdoc IVolatilityPool
    function nextSettlementTime() external view override returns (uint256) {
        return lastSettlementTime + settlementInterval;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Get rolling variance from oracle observations
    /// @dev Limited to MAX_VARIANCE_OBSERVATIONS to prevent gas exhaustion
    function _getRollingVariance() internal view returns (uint256 variance) {
        IVarianceOracle oracle = IVarianceOracle(varianceOracle);

        uint256 totalObservations = oracle.observationCount();
        if (totalObservations == 0) return 0;

        // Find observations within variance window
        uint256 windowStart = block.timestamp - varianceWindow;
        uint256 sumSquared = 0;
        uint256 obsCount = 0;

        // Iterate backwards from most recent, limited to MAX_VARIANCE_OBSERVATIONS
        uint256 startIdx = totalObservations;
        uint256 endIdx = totalObservations > MAX_VARIANCE_OBSERVATIONS
            ? totalObservations - MAX_VARIANCE_OBSERVATIONS
            : 0;

        for (uint256 i = startIdx; i > endIdx; i--) {
            IVarianceOracle.Observation memory obs = oracle.getObservation(i - 1);

            if (obs.timestamp < windowStart) {
                break;
            }

            // Add squared log return (squaring always yields positive result)
            int256 r = obs.logReturn;
            uint256 squared = uint256(r * r);
            sumSquared += squared / PRECISION;
            obsCount++;
        }

        if (obsCount == 0) return 0;

        // Annualize: variance = (252 / obsCount) * sumSquared
        // Using 252 trading days as annualization factor
        variance = (sumSquared * 252) / obsCount;
    }

    /// @dev Return minimum of two values
    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
