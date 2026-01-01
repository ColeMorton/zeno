// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVarianceVault} from "./interfaces/IVarianceVault.sol";
import {IVarianceSwap} from "./interfaces/IVarianceSwap.sol";

/// @title VarianceVaultShort
/// @notice ERC-4626 vault providing short volatility exposure via variance swaps
/// @dev Users deposit collateral, receive shares, auto-matched with long vault
contract VarianceVaultShort is ERC4626, IVarianceVault {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            IMMUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceVault
    address public immutable varianceSwap;

    /// @inheritdoc IVarianceVault
    address public immutable counterpartyVault;

    /// @inheritdoc IVarianceVault
    address public immutable router;

    /// @inheritdoc IVarianceVault
    uint256 public immutable standardObservationPeriod;

    /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceVault
    uint256 public currentEpochId;

    /// @inheritdoc IVarianceVault
    uint256 public totalEpochs;

    /// @dev Epoch ID to epoch info
    mapping(uint256 => EpochInfo) private _epochs;

    /// @dev Epoch ID to epoch config
    mapping(uint256 => EpochConfig) private _epochConfigs;

    /// @dev User address to epoch ID to shares
    mapping(address => mapping(uint256 => uint256)) private _userEpochShares;

    /// @dev Total shares per epoch
    mapping(uint256 => uint256) private _epochTotalShares;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @param _asset Collateral token (e.g., wBTC)
    /// @param _varianceSwap VarianceSwap contract address
    /// @param _counterpartyVault VarianceVaultLong address
    /// @param _router VarianceSwapRouter address
    /// @param _standardPeriod Standard observation period (7d, 30d, or 90d)
    constructor(
        IERC20 _asset,
        address _varianceSwap,
        address _counterpartyVault,
        address _router,
        uint256 _standardPeriod
    )
        ERC4626(_asset)
        ERC20("Variance Vault Short vBTC", "vvShortVBTC")
    {
        if (_varianceSwap == address(0)) revert ZeroAddress();
        if (_router == address(0)) revert ZeroAddress();

        varianceSwap = _varianceSwap;
        counterpartyVault = _counterpartyVault;
        router = _router;
        standardObservationPeriod = _standardPeriod;

        // Approve variance swap to pull collateral
        _asset.approve(_varianceSwap, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                          EPOCH MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceVault
    function initializeEpoch(
        EpochConfig calldata config
    ) external returns (uint256 epochId) {
        if (msg.sender != router) revert Unauthorized();

        epochId = ++totalEpochs;
        currentEpochId = epochId;

        _epochConfigs[epochId] = config;
        _epochs[epochId] = EpochInfo({
            epochId: epochId,
            totalDeposits: 0,
            swapId: 0,
            startTime: 0,
            endTime: 0,
            realizedVariance: 0,
            pnl: 0,
            state: EpochState.DEPOSITING
        });

        emit EpochInitialized(epochId, config);
    }

    /// @inheritdoc IVarianceVault
    function matchEpoch(uint256 epochId) external {
        if (msg.sender != router) revert Unauthorized();

        EpochInfo storage epoch = _epochs[epochId];
        EpochConfig storage config = _epochConfigs[epochId];

        if (epoch.state != EpochState.DEPOSITING) {
            revert EpochNotInDepositing(epochId);
        }

        // Create variance swap with counterparty
        IVarianceSwap.SwapTerms memory terms = IVarianceSwap.SwapTerms({
            strikeVariance: config.strikeVariance,
            notionalAmount: epoch.totalDeposits,
            observationPeriod: config.observationPeriod,
            observationFrequency: 1 days, // Daily observations
            collateralToken: asset()
        });

        uint256 collateralRequired = IVarianceSwap(varianceSwap).calculateShortCollateral(terms);

        uint256 swapId = IVarianceSwap(varianceSwap).createShortSwap(terms, collateralRequired);

        epoch.swapId = swapId;
        epoch.state = EpochState.ACTIVE;

        emit EpochMatched(epochId, swapId, counterpartyVault);
    }

    /// @inheritdoc IVarianceVault
    function settleEpoch(uint256 epochId) external {
        EpochInfo storage epoch = _epochs[epochId];

        if (epoch.state != EpochState.ACTIVE) {
            revert EpochNotSettled(epochId);
        }

        // Settle the underlying swap
        IVarianceSwap.SettlementResult memory result = IVarianceSwap(varianceSwap).settle(epoch.swapId);

        epoch.realizedVariance = result.realizedVariance;
        // PnL is inverted for short vault
        epoch.pnl = -result.pnl;
        epoch.state = EpochState.WITHDRAWING;

        emit EpochSettled(epochId, result.realizedVariance, epoch.pnl);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAW
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceVault
    function deposit(
        uint256 assets,
        address receiver
    ) public override(ERC4626, IVarianceVault) returns (uint256 shares) {
        EpochInfo storage epoch = _epochs[currentEpochId];
        EpochConfig storage config = _epochConfigs[currentEpochId];

        if (epoch.state != EpochState.DEPOSITING) {
            revert EpochNotInDepositing(currentEpochId);
        }

        if (block.timestamp > config.depositDeadline) {
            revert DepositDeadlinePassed(config.depositDeadline);
        }

        if (assets < config.minDeposit) {
            revert DepositBelowMinimum(assets, config.minDeposit);
        }

        uint256 remaining = config.maxTotalDeposits - epoch.totalDeposits;
        if (assets > remaining) {
            revert DepositExceedsMax(assets, remaining);
        }

        // Calculate shares (1:1 for deposits)
        shares = assets;

        // Update epoch state
        epoch.totalDeposits += assets;
        _userEpochShares[receiver][currentEpochId] += shares;
        _epochTotalShares[currentEpochId] += shares;

        // Transfer assets
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), assets);

        // Mint vault shares
        _mint(receiver, shares);

        emit DepositToEpoch(currentEpochId, receiver, assets, shares);
    }

    /// @inheritdoc IVarianceVault
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override(ERC4626, IVarianceVault) returns (uint256 shares) {
        // Find settled epoch with user shares
        uint256 epochToWithdraw = _findSettledEpochWithShares(owner);
        if (epochToWithdraw == 0) {
            revert NoActiveEpoch();
        }

        shares = previewEpochRedeem(epochToWithdraw, assets);

        if (shares > _userEpochShares[owner][epochToWithdraw]) {
            revert InsufficientShares(shares, _userEpochShares[owner][epochToWithdraw]);
        }

        // Update user shares
        _userEpochShares[owner][epochToWithdraw] -= shares;

        // Burn vault shares
        _burn(owner, shares);

        // Transfer assets
        IERC20(asset()).safeTransfer(receiver, assets);

        emit WithdrawFromEpoch(epochToWithdraw, receiver, shares, assets);
    }

    /*//////////////////////////////////////////////////////////////
                           VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IVarianceVault
    function getEpoch(uint256 epochId) external view returns (EpochInfo memory) {
        return _epochs[epochId];
    }

    /// @inheritdoc IVarianceVault
    function getEpochConfig(uint256 epochId) external view returns (EpochConfig memory) {
        return _epochConfigs[epochId];
    }

    /// @inheritdoc IVarianceVault
    function userEpochShares(address user, uint256 epochId) external view returns (uint256) {
        return _userEpochShares[user][epochId];
    }

    /// @inheritdoc IVarianceVault
    function isLongVault() external pure returns (bool) {
        return false;
    }

    /// @inheritdoc IVarianceVault
    function previewEpochWithdraw(
        uint256 epochId,
        uint256 shares
    ) public view returns (uint256 assets) {
        EpochInfo storage epoch = _epochs[epochId];

        if (epoch.state != EpochState.WITHDRAWING) {
            return 0;
        }

        // Calculate proportional share of final assets
        uint256 totalShares = _epochTotalShares[epochId];
        if (totalShares == 0) return 0;

        // Get final balance after settlement
        uint256 finalBalance = _getEpochFinalBalance(epochId);

        assets = (shares * finalBalance) / totalShares;
    }

    /// @inheritdoc IVarianceVault
    function previewEpochRedeem(
        uint256 epochId,
        uint256 assets
    ) public view returns (uint256 shares) {
        EpochInfo storage epoch = _epochs[epochId];

        if (epoch.state != EpochState.WITHDRAWING) {
            return type(uint256).max;
        }

        uint256 totalShares = _epochTotalShares[epochId];
        if (totalShares == 0) return type(uint256).max;

        uint256 finalBalance = _getEpochFinalBalance(epochId);
        if (finalBalance == 0) return type(uint256).max;

        shares = (assets * totalShares) / finalBalance;
    }

    /// @inheritdoc ERC4626
    function totalAssets() public view override(ERC4626, IERC4626) returns (uint256) {
        // Sum of all epoch deposits + settlements
        uint256 total = 0;
        for (uint256 i = 1; i <= totalEpochs; i++) {
            total += _getEpochCurrentValue(i);
        }
        return total;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Find first settled epoch where user has shares
    function _findSettledEpochWithShares(address user) internal view returns (uint256) {
        for (uint256 i = 1; i <= totalEpochs; i++) {
            if (_epochs[i].state == EpochState.WITHDRAWING &&
                _userEpochShares[user][i] > 0) {
                return i;
            }
        }
        return 0;
    }

    /// @dev Get final balance for a settled epoch
    function _getEpochFinalBalance(uint256 epochId) internal view returns (uint256) {
        EpochInfo storage epoch = _epochs[epochId];

        if (epoch.state != EpochState.WITHDRAWING) {
            return epoch.totalDeposits;
        }

        // Calculate based on PnL (inverted for short vault)
        if (epoch.pnl >= 0) {
            return epoch.totalDeposits + uint256(epoch.pnl);
        } else {
            uint256 loss = uint256(-epoch.pnl);
            if (loss >= epoch.totalDeposits) {
                return 0;
            }
            return epoch.totalDeposits - loss;
        }
    }

    /// @dev Get current value of epoch assets
    function _getEpochCurrentValue(uint256 epochId) internal view returns (uint256) {
        EpochInfo storage epoch = _epochs[epochId];

        if (epoch.state == EpochState.DEPOSITING) {
            return epoch.totalDeposits;
        } else if (epoch.state == EpochState.ACTIVE) {
            return epoch.totalDeposits;
        } else if (epoch.state == EpochState.WITHDRAWING) {
            return _getEpochFinalBalance(epochId);
        }

        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized();
    error ZeroAddress();
}
