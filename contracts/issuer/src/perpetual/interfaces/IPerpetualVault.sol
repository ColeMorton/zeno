// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPerpetualVault
/// @notice Interface for perpetual capped leverage vault
/// @dev Unified vault for long/short positions with OI-based funding
interface IPerpetualVault {
    /*//////////////////////////////////////////////////////////////
                                 ENUMS
    //////////////////////////////////////////////////////////////*/

    enum Side {
        LONG,
        SHORT
    }

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Individual position data
    struct Position {
        uint256 collateral; // vBTC deposited
        uint256 notional; // collateral × leverage
        uint256 leverageX100; // 100-500 (1x-5x)
        uint256 entryPrice; // Curve EMA at open (18 decimals)
        int256 entryFundingAccumulator; // Funding accumulator at entry
        uint256 openTimestamp; // Block timestamp at open
        Side side;
    }

    /// @notice Global vault state
    struct GlobalState {
        uint256 longOI; // Total long open interest (notional)
        uint256 shortOI; // Total short open interest (notional)
        uint256 longCollateral; // Total long collateral
        uint256 shortCollateral; // Total short collateral
        int256 fundingAccumulatorLong; // Per-notional funding for longs (18 decimals)
        int256 fundingAccumulatorShort; // Per-notional funding for shorts (18 decimals)
        uint256 lastFundingUpdate; // Timestamp of last funding accrual
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error ZeroAddress();
    error ZeroCollateral();
    error InvalidLeverage(uint256 leverage);
    error CollateralBelowMinimum(uint256 collateral);
    error PositionNotFound(uint256 positionId);
    error NotPositionOwner(uint256 positionId, address caller);
    error PositionAlreadyClosed(uint256 positionId);
    error PriceOutOfBounds(uint256 price);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionOpened(
        uint256 indexed positionId,
        address indexed owner,
        Side side,
        uint256 collateral,
        uint256 leverageX100,
        uint256 entryPrice
    );

    event PositionClosed(
        uint256 indexed positionId,
        address indexed owner,
        int256 totalPnL,
        uint256 payout
    );

    event CollateralAdded(
        uint256 indexed positionId,
        uint256 amount,
        uint256 newCollateral
    );

    event FundingAccrued(int256 fundingRateBPS, uint256 periods);

    /*//////////////////////////////////////////////////////////////
                          POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @notice Open a new leveraged position
    /// @param collateral vBTC amount to deposit
    /// @param leverageX100 Leverage multiplied by 100 (100-500)
    /// @param side LONG or SHORT
    /// @return positionId Unique position identifier
    function openPosition(
        uint256 collateral,
        uint256 leverageX100,
        Side side
    ) external returns (uint256 positionId);

    /// @notice Close an existing position
    /// @param positionId Position to close
    /// @return payout vBTC amount returned to user
    function closePosition(uint256 positionId) external returns (uint256 payout);

    /// @notice Add collateral to existing position (reduces effective leverage)
    /// @param positionId Position to add collateral to
    /// @param amount vBTC amount to add
    function addCollateral(uint256 positionId, uint256 amount) external;

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Preview payout if position were closed now
    /// @param positionId Position to preview
    /// @return pnl Total P&L (direction + funding)
    /// @return payout Capped payout amount
    function previewClose(uint256 positionId) external view returns (int256 pnl, uint256 payout);

    /// @notice Get position data
    /// @param positionId Position ID
    /// @return position Position struct
    function getPosition(uint256 positionId) external view returns (Position memory position);

    /// @notice Get position owner
    /// @param positionId Position ID
    /// @return owner Address of position owner
    function getPositionOwner(uint256 positionId) external view returns (address owner);

    /// @notice Get current funding rate in BPS
    /// @return rate Positive = longs pay shorts, negative = shorts pay longs
    function getCurrentFundingRate() external view returns (int256 rate);

    /// @notice Get global vault state
    /// @return state GlobalState struct
    function getGlobalState() external view returns (GlobalState memory state);

    /// @notice Get current vBTC/wBTC price from Curve oracle
    /// @return price Price with 18 decimals
    function getCurrentPrice() external view returns (uint256 price);

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice vestedBTC token address
    function vBTC() external view returns (address);

    /// @notice Curve CryptoSwap pool address
    function curvePool() external view returns (address);
}
