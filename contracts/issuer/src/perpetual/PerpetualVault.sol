// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPerpetualVault} from "./interfaces/IPerpetualVault.sol";
import {PerpetualMath} from "./PerpetualMath.sol";
import {ICurveCryptoSwap} from "../interfaces/ICurveCryptoSwap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PerpetualVault
/// @notice Unified perpetual leverage vault for long/short vBTC positions
/// @dev Features:
///      - Enter/exit anytime (no epochs)
///      - OI-based funding rate (oracle-free for funding)
///      - Curve EMA oracle for direction P&L
///      - Capped payoffs (0.01% - 200%) eliminate liquidations
contract PerpetualVault is IPerpetualVault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant PRECISION = 1e18;
    uint256 public constant BPS = 10000;

    /// @dev Minimum leverage: 1x
    uint256 public constant MIN_LEVERAGE_X100 = 100;

    /// @dev Maximum leverage: 5x
    uint256 public constant MAX_LEVERAGE_X100 = 500;

    /// @dev Minimum collateral: 0.01 vBTC (8 decimals)
    uint256 public constant MIN_COLLATERAL = 1e6;

    /// @dev Funding accrual interval: 1 hour
    uint256 public constant FUNDING_INTERVAL = 1 hours;

    /// @dev Minimum price ratio: 0.50 vBTC/wBTC
    uint256 public constant MIN_PRICE = 5e17;

    /// @dev Maximum price ratio: 1.00 vBTC/wBTC
    uint256 public constant MAX_PRICE = 1e18;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPerpetualVault
    address public immutable override vBTC;

    /// @inheritdoc IPerpetualVault
    address public immutable override curvePool;

    /*//////////////////////////////////////////////////////////////
                             MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @dev Global vault state
    GlobalState private _globalState;

    /// @dev Next position ID counter
    uint256 private _nextPositionId;

    /// @dev Position ID to position data
    mapping(uint256 => Position) private _positions;

    /// @dev Position ID to owner address
    mapping(uint256 => address) private _positionOwners;

    /// @dev User address to array of their position IDs
    mapping(address => uint256[]) private _userPositions;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _vBTC vestedBTC token address
    /// @param _curvePool Curve CryptoSwap V2 pool address
    constructor(address _vBTC, address _curvePool) {
        if (_vBTC == address(0)) revert ZeroAddress();
        if (_curvePool == address(0)) revert ZeroAddress();

        vBTC = _vBTC;
        curvePool = _curvePool;

        _globalState.lastFundingUpdate = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                          POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPerpetualVault
    function openPosition(
        uint256 collateral,
        uint256 leverageX100,
        Side side
    ) external override nonReentrant returns (uint256 positionId) {
        // Validate inputs
        if (collateral < MIN_COLLATERAL) {
            revert CollateralBelowMinimum(collateral);
        }
        if (leverageX100 < MIN_LEVERAGE_X100 || leverageX100 > MAX_LEVERAGE_X100) {
            revert InvalidLeverage(leverageX100);
        }

        // Accrue pending funding before state changes
        _accrueFunding();

        // Get current price from Curve EMA oracle
        uint256 entryPrice = getCurrentPrice();

        // Calculate notional
        uint256 notional = PerpetualMath.calculateNotional(collateral, leverageX100);

        // Get current funding accumulator for position side
        int256 entryFundingAccumulator = side == Side.LONG
            ? _globalState.fundingAccumulatorLong
            : _globalState.fundingAccumulatorShort;

        // Create position
        positionId = ++_nextPositionId;

        _positions[positionId] = Position({
            collateral: collateral,
            notional: notional,
            leverageX100: leverageX100,
            entryPrice: entryPrice,
            entryFundingAccumulator: entryFundingAccumulator,
            openTimestamp: block.timestamp,
            side: side
        });

        _positionOwners[positionId] = msg.sender;
        _userPositions[msg.sender].push(positionId);

        // Update global OI
        if (side == Side.LONG) {
            _globalState.longOI += notional;
            _globalState.longCollateral += collateral;
        } else {
            _globalState.shortOI += notional;
            _globalState.shortCollateral += collateral;
        }

        // Transfer collateral from user
        IERC20(vBTC).safeTransferFrom(msg.sender, address(this), collateral);

        emit PositionOpened(positionId, msg.sender, side, collateral, leverageX100, entryPrice);
    }

    /// @inheritdoc IPerpetualVault
    function closePosition(uint256 positionId) external override nonReentrant returns (uint256 payout) {
        address owner = _positionOwners[positionId];
        if (owner == address(0)) revert PositionNotFound(positionId);
        if (owner != msg.sender) revert NotPositionOwner(positionId, msg.sender);

        Position storage pos = _positions[positionId];
        if (pos.collateral == 0) revert PositionAlreadyClosed(positionId);

        // Accrue pending funding
        _accrueFunding();

        // Calculate total P&L
        (int256 totalPnL, uint256 cappedPayout) = _calculatePositionPnL(positionId);
        payout = cappedPayout;

        // Update global state before clearing position
        if (pos.side == Side.LONG) {
            _globalState.longOI -= pos.notional;
            _globalState.longCollateral -= pos.collateral;
        } else {
            _globalState.shortOI -= pos.notional;
            _globalState.shortCollateral -= pos.collateral;
        }

        // Clear position
        delete _positions[positionId];
        delete _positionOwners[positionId];

        // Transfer payout to user
        if (payout > 0) {
            IERC20(vBTC).safeTransfer(msg.sender, payout);
        }

        emit PositionClosed(positionId, msg.sender, totalPnL, payout);
    }

    /// @inheritdoc IPerpetualVault
    function addCollateral(uint256 positionId, uint256 amount) external override nonReentrant {
        address owner = _positionOwners[positionId];
        if (owner == address(0)) revert PositionNotFound(positionId);
        if (owner != msg.sender) revert NotPositionOwner(positionId, msg.sender);

        Position storage pos = _positions[positionId];
        if (pos.collateral == 0) revert PositionAlreadyClosed(positionId);
        if (amount == 0) revert ZeroCollateral();

        // Accrue funding first
        _accrueFunding();

        // Update position collateral (notional stays same, effective leverage decreases)
        pos.collateral += amount;

        // Update global collateral
        if (pos.side == Side.LONG) {
            _globalState.longCollateral += amount;
        } else {
            _globalState.shortCollateral += amount;
        }

        // Transfer collateral from user
        IERC20(vBTC).safeTransferFrom(msg.sender, address(this), amount);

        emit CollateralAdded(positionId, amount, pos.collateral);
    }

    /*//////////////////////////////////////////////////////////////
                           FUNDING ACCRUAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Accrue funding based on OI imbalance
    function _accrueFunding() internal {
        uint256 elapsed = block.timestamp - _globalState.lastFundingUpdate;
        if (elapsed < FUNDING_INTERVAL) return;

        uint256 periods = elapsed / FUNDING_INTERVAL;

        // Skip if no OI
        if (_globalState.longOI == 0 && _globalState.shortOI == 0) {
            _globalState.lastFundingUpdate = block.timestamp;
            return;
        }

        // Calculate funding rate from OI imbalance
        int256 fundingRateBPS = PerpetualMath.calculateFundingRate(
            _globalState.longOI,
            _globalState.shortOI
        );

        // Calculate per-notional funding delta
        int256 fundingDelta = PerpetualMath.calculateFundingDelta(fundingRateBPS, periods);

        // Longs pay when positive, shorts pay when negative
        // So longs subtract funding, shorts add funding
        _globalState.fundingAccumulatorLong -= fundingDelta;
        _globalState.fundingAccumulatorShort += fundingDelta;

        _globalState.lastFundingUpdate = block.timestamp;

        emit FundingAccrued(fundingRateBPS, periods);
    }

    /*//////////////////////////////////////////////////////////////
                          P&L CALCULATIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculate position P&L and capped payout
    function _calculatePositionPnL(uint256 positionId)
        internal
        view
        returns (int256 totalPnL, uint256 payout)
    {
        Position storage pos = _positions[positionId];

        // Get current price
        uint256 currentPrice = getCurrentPrice();

        // Calculate direction P&L
        int256 directionPnL = PerpetualMath.calculateDirectionPnL(
            pos.notional,
            pos.entryPrice,
            currentPrice,
            pos.side == Side.LONG
        );

        // Get current funding accumulator for position side
        int256 currentFundingAccumulator = pos.side == Side.LONG
            ? _globalState.fundingAccumulatorLong
            : _globalState.fundingAccumulatorShort;

        // Calculate funding P&L
        int256 fundingPnL = PerpetualMath.calculateFundingPnL(
            pos.notional,
            pos.entryFundingAccumulator,
            currentFundingAccumulator
        );

        // Total P&L
        totalPnL = PerpetualMath.calculateTotalPnL(directionPnL, fundingPnL);

        // Apply capped payout
        payout = PerpetualMath.calculateCappedPayout(pos.collateral, totalPnL);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IPerpetualVault
    function previewClose(uint256 positionId)
        external
        view
        override
        returns (int256 pnl, uint256 payout)
    {
        if (_positionOwners[positionId] == address(0)) revert PositionNotFound(positionId);
        if (_positions[positionId].collateral == 0) revert PositionAlreadyClosed(positionId);

        return _calculatePositionPnL(positionId);
    }

    /// @inheritdoc IPerpetualVault
    function getPosition(uint256 positionId)
        external
        view
        override
        returns (Position memory position)
    {
        if (_positionOwners[positionId] == address(0)) revert PositionNotFound(positionId);
        return _positions[positionId];
    }

    /// @inheritdoc IPerpetualVault
    function getPositionOwner(uint256 positionId) external view override returns (address owner) {
        return _positionOwners[positionId];
    }

    /// @inheritdoc IPerpetualVault
    function getCurrentFundingRate() external view override returns (int256 rate) {
        return PerpetualMath.calculateFundingRate(_globalState.longOI, _globalState.shortOI);
    }

    /// @inheritdoc IPerpetualVault
    function getGlobalState() external view override returns (GlobalState memory state) {
        return _globalState;
    }

    /// @inheritdoc IPerpetualVault
    function getCurrentPrice() public view override returns (uint256 price) {
        price = ICurveCryptoSwap(curvePool).price_oracle();

        // Fail-fast bounds check
        if (price < MIN_PRICE || price > MAX_PRICE) {
            revert PriceOutOfBounds(price);
        }
    }

    /// @notice Get all position IDs for a user
    /// @param user User address
    /// @return positionIds Array of position IDs
    function getUserPositions(address user) external view returns (uint256[] memory positionIds) {
        return _userPositions[user];
    }

    /// @notice Get total vBTC held by vault
    /// @return balance Total vBTC balance
    function totalAssets() external view returns (uint256 balance) {
        return IERC20(vBTC).balanceOf(address(this));
    }
}
