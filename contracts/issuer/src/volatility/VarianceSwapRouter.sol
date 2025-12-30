// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVarianceVault} from "./interfaces/IVarianceVault.sol";
import {IVarianceSwap} from "./interfaces/IVarianceSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title VarianceSwapRouter
/// @notice Manages epoch creation and matching between long/short variance vaults
/// @dev Permissionless epoch initialization and matching based on deposit thresholds
contract VarianceSwapRouter is ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Long volatility vault
    IVarianceVault public immutable longVault;

    /// @notice Short volatility vault
    IVarianceVault public immutable shortVault;

    /// @notice Variance swap contract
    IVarianceSwap public immutable varianceSwap;

    /// @notice Collateral token
    IERC20 public immutable collateralToken;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Standard observation periods
    uint256 public constant PERIOD_7_DAYS = 7 days;
    uint256 public constant PERIOD_30_DAYS = 30 days;
    uint256 public constant PERIOD_90_DAYS = 90 days;

    /// @notice Default strike variance (4% annualized)
    uint256 public constant DEFAULT_STRIKE_VARIANCE = 4e16;

    /// @notice Minimum deposit per epoch
    uint256 public constant MIN_DEPOSIT = 0.01e8; // 0.01 BTC (8 decimals)

    /// @notice Maximum total deposits per epoch
    uint256 public constant MAX_TOTAL_DEPOSITS = 100e8; // 100 BTC

    /// @notice Deposit window duration
    uint256 public constant DEPOSIT_WINDOW = 7 days;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Current epoch configurations per period
    mapping(uint256 => CurrentEpochState) public periodEpochs;

    /// @dev Track epoch state per period
    struct CurrentEpochState {
        uint256 longEpochId;
        uint256 shortEpochId;
        uint256 strikeVariance;
        uint256 depositDeadline;
        bool matched;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new epoch pair is created
    event EpochPairCreated(
        uint256 indexed period,
        uint256 longEpochId,
        uint256 shortEpochId,
        uint256 strikeVariance,
        uint256 depositDeadline
    );

    /// @notice Emitted when epochs are matched
    event EpochsMatched(
        uint256 indexed period,
        uint256 longEpochId,
        uint256 shortEpochId,
        uint256 longDeposits,
        uint256 shortDeposits
    );

    /// @notice Emitted when epochs are settled
    event EpochsSettled(
        uint256 indexed period,
        uint256 longEpochId,
        uint256 shortEpochId
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error InvalidPeriod(uint256 period);
    error EpochAlreadyActive(uint256 period);
    error EpochNotActive(uint256 period);
    error EpochAlreadyMatched(uint256 period);
    error InsufficientDeposits();
    error DepositWindowOpen();
    error EpochNotMatured();
    error ZeroAddress();

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _longVault Long variance vault
    /// @param _shortVault Short variance vault
    /// @param _varianceSwap Variance swap contract
    /// @param _collateralToken Collateral token (e.g., wBTC)
    constructor(
        address _longVault,
        address _shortVault,
        address _varianceSwap,
        address _collateralToken
    ) {
        if (_longVault == address(0)) revert ZeroAddress();
        if (_shortVault == address(0)) revert ZeroAddress();
        if (_varianceSwap == address(0)) revert ZeroAddress();
        if (_collateralToken == address(0)) revert ZeroAddress();

        longVault = IVarianceVault(_longVault);
        shortVault = IVarianceVault(_shortVault);
        varianceSwap = IVarianceSwap(_varianceSwap);
        collateralToken = IERC20(_collateralToken);
    }

    /*//////////////////////////////////////////////////////////////
                          EPOCH MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Initialize a new epoch pair for a given period
    /// @param period Observation period (7d, 30d, or 90d)
    /// @param strikeVariance Strike variance for this epoch (18 decimals)
    /// @return longEpochId Long vault epoch ID
    /// @return shortEpochId Short vault epoch ID
    function initializeEpochPair(
        uint256 period,
        uint256 strikeVariance
    ) external returns (uint256 longEpochId, uint256 shortEpochId) {
        _validatePeriod(period);

        CurrentEpochState storage state = periodEpochs[period];

        // Check if previous epoch is still active (not matched)
        if (state.longEpochId != 0 && !state.matched) {
            revert EpochAlreadyActive(period);
        }

        // Use default strike if not specified
        if (strikeVariance == 0) {
            strikeVariance = DEFAULT_STRIKE_VARIANCE;
        }

        uint256 deadline = block.timestamp + DEPOSIT_WINDOW;

        // Create epoch config
        IVarianceVault.EpochConfig memory config = IVarianceVault.EpochConfig({
            strikeVariance: strikeVariance,
            observationPeriod: period,
            depositDeadline: deadline,
            minDeposit: MIN_DEPOSIT,
            maxTotalDeposits: MAX_TOTAL_DEPOSITS
        });

        // Initialize epochs in both vaults
        longEpochId = longVault.initializeEpoch(config);
        shortEpochId = shortVault.initializeEpoch(config);

        // Update state
        state.longEpochId = longEpochId;
        state.shortEpochId = shortEpochId;
        state.strikeVariance = strikeVariance;
        state.depositDeadline = deadline;
        state.matched = false;

        emit EpochPairCreated(period, longEpochId, shortEpochId, strikeVariance, deadline);
    }

    /// @notice Match epochs after deposit window closes
    /// @param period Observation period
    /// @dev Matches minimum of long/short deposits
    function matchEpochs(uint256 period) external nonReentrant {
        _validatePeriod(period);

        CurrentEpochState storage state = periodEpochs[period];

        if (state.longEpochId == 0) {
            revert EpochNotActive(period);
        }

        if (state.matched) {
            revert EpochAlreadyMatched(period);
        }

        if (block.timestamp < state.depositDeadline) {
            revert DepositWindowOpen();
        }

        // Get deposits from both vaults
        IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);
        IVarianceVault.EpochInfo memory shortEpoch = shortVault.getEpoch(state.shortEpochId);

        if (longEpoch.totalDeposits == 0 || shortEpoch.totalDeposits == 0) {
            revert InsufficientDeposits();
        }

        // Match the smaller of the two deposits
        uint256 matchedAmount = longEpoch.totalDeposits < shortEpoch.totalDeposits
            ? longEpoch.totalDeposits
            : shortEpoch.totalDeposits;

        // Trigger matching in both vaults
        longVault.matchEpoch(state.longEpochId);
        shortVault.matchEpoch(state.shortEpochId);

        state.matched = true;

        emit EpochsMatched(
            period,
            state.longEpochId,
            state.shortEpochId,
            longEpoch.totalDeposits,
            shortEpoch.totalDeposits
        );
    }

    /// @notice Settle matured epochs
    /// @param period Observation period
    function settleEpochs(uint256 period) external nonReentrant {
        _validatePeriod(period);

        CurrentEpochState storage state = periodEpochs[period];

        if (!state.matched) {
            revert EpochNotActive(period);
        }

        // Get epoch info to check if matured
        IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);

        if (longEpoch.state != IVarianceVault.EpochState.ACTIVE) {
            revert EpochNotMatured();
        }

        // Check if swap is matured
        IVarianceSwap.SwapPosition memory swap = varianceSwap.getSwap(longEpoch.swapId);
        if (swap.state != IVarianceSwap.SwapState.MATURED) {
            revert EpochNotMatured();
        }

        // Settle both vaults
        longVault.settleEpoch(state.longEpochId);
        shortVault.settleEpoch(state.shortEpochId);

        emit EpochsSettled(period, state.longEpochId, state.shortEpochId);
    }

    /// @notice Record observation for active epochs (permissionless)
    /// @param period Observation period
    function recordObservation(uint256 period) external {
        _validatePeriod(period);

        CurrentEpochState storage state = periodEpochs[period];

        if (!state.matched) {
            revert EpochNotActive(period);
        }

        IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);

        if (longEpoch.swapId != 0) {
            varianceSwap.recordObservation(longEpoch.swapId);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Get current epoch state for a period
    function getCurrentEpochState(
        uint256 period
    ) external view returns (CurrentEpochState memory) {
        return periodEpochs[period];
    }

    /// @notice Get deposits for current epoch
    function getCurrentDeposits(
        uint256 period
    ) external view returns (uint256 longDeposits, uint256 shortDeposits) {
        CurrentEpochState storage state = periodEpochs[period];

        if (state.longEpochId != 0) {
            IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);
            longDeposits = longEpoch.totalDeposits;
        }

        if (state.shortEpochId != 0) {
            IVarianceVault.EpochInfo memory shortEpoch = shortVault.getEpoch(state.shortEpochId);
            shortDeposits = shortEpoch.totalDeposits;
        }
    }

    /// @notice Check if period is valid
    function isValidPeriod(uint256 period) public pure returns (bool) {
        return period == PERIOD_7_DAYS ||
               period == PERIOD_30_DAYS ||
               period == PERIOD_90_DAYS;
    }

    /// @notice Get time until deposit deadline
    function timeUntilDeadline(uint256 period) external view returns (uint256) {
        CurrentEpochState storage state = periodEpochs[period];

        if (state.depositDeadline == 0 || block.timestamp >= state.depositDeadline) {
            return 0;
        }

        return state.depositDeadline - block.timestamp;
    }

    /// @notice Check if epoch can be matched
    function canMatch(uint256 period) external view returns (bool) {
        CurrentEpochState storage state = periodEpochs[period];

        if (state.matched || state.longEpochId == 0) {
            return false;
        }

        if (block.timestamp < state.depositDeadline) {
            return false;
        }

        IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);
        IVarianceVault.EpochInfo memory shortEpoch = shortVault.getEpoch(state.shortEpochId);

        return longEpoch.totalDeposits > 0 && shortEpoch.totalDeposits > 0;
    }

    /// @notice Check if epoch can be settled
    function canSettle(uint256 period) external view returns (bool) {
        CurrentEpochState storage state = periodEpochs[period];

        if (!state.matched) {
            return false;
        }

        IVarianceVault.EpochInfo memory longEpoch = longVault.getEpoch(state.longEpochId);

        if (longEpoch.state != IVarianceVault.EpochState.ACTIVE) {
            return false;
        }

        IVarianceSwap.SwapPosition memory swap = varianceSwap.getSwap(longEpoch.swapId);
        return swap.state == IVarianceSwap.SwapState.MATURED;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Validate observation period
    function _validatePeriod(uint256 period) internal pure {
        if (!isValidPeriod(period)) {
            revert InvalidPeriod(period);
        }
    }
}
