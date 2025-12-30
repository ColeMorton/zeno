// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ISablierStreamWrapper} from "./interfaces/ISablierStreamWrapper.sol";
import {ISablierV2LockupLinear} from "./interfaces/ISablierV2LockupLinear.sol";

/// @notice Minimal interface for VaultNFT delegation
interface IVaultDelegation {
    function ownerOf(uint256 tokenId) external view returns (address);
    function collateralToken() external view returns (address);
    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount);
    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);
}

/// @title SablierStreamWrapper
/// @notice Converts discrete monthly VaultNFT withdrawals into continuous Sablier streams
/// @dev Vault owners delegate to this contract, which creates 30-day linear streams on withdrawal
contract SablierStreamWrapper is ISablierStreamWrapper, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISablierStreamWrapper
    uint40 public constant STREAM_DURATION = 30 days;

    /// @notice The VaultNFT delegation contract
    IVaultDelegation internal immutable _vaultNFT;

    /// @notice The Sablier LockupLinear contract
    ISablierV2LockupLinear internal immutable _sablier;

    /// @notice The collateral token (WBTC/cbBTC)
    IERC20 public immutable collateralToken;

    /// @notice Vault token ID => stream configuration
    mapping(uint256 => VaultStreamConfig) private _vaultConfigs;

    /// @notice Vault token ID => array of created stream IDs
    mapping(uint256 => uint256[]) private _vaultStreams;

    constructor(address vaultNFT_, address sablier_) {
        if (vaultNFT_ == address(0)) revert ZeroAddress();
        if (sablier_ == address(0)) revert ZeroAddress();

        _vaultNFT = IVaultDelegation(vaultNFT_);
        _sablier = ISablierV2LockupLinear(sablier_);
        collateralToken = IERC20(_vaultNFT.collateralToken());
    }

    /// @inheritdoc ISablierStreamWrapper
    function configureVault(
        uint256 vaultTokenId,
        address recipient,
        bool enabled
    ) external {
        if (_vaultNFT.ownerOf(vaultTokenId) != msg.sender) {
            revert NotVaultOwner(vaultTokenId);
        }
        if (recipient == address(0)) revert ZeroAddress();

        _vaultConfigs[vaultTokenId] = VaultStreamConfig({
            recipient: recipient,
            streamEnabled: enabled,
            lastStreamId: _vaultConfigs[vaultTokenId].lastStreamId
        });

        emit VaultConfigured(vaultTokenId, recipient, enabled);
    }

    /// @inheritdoc ISablierStreamWrapper
    function createStreamFromVault(uint256 vaultTokenId)
        external
        nonReentrant
        returns (uint256 streamId)
    {
        VaultStreamConfig storage config = _vaultConfigs[vaultTokenId];

        if (config.recipient == address(0)) {
            revert VaultNotConfigured(vaultTokenId);
        }
        if (!config.streamEnabled) {
            revert StreamingDisabled(vaultTokenId);
        }

        // Withdraw from VaultNFT as delegate
        uint256 withdrawnAmount = _vaultNFT.withdrawAsDelegate(vaultTokenId);
        if (withdrawnAmount == 0) revert ZeroAmount();

        // Approve Sablier to spend collateral
        collateralToken.forceApprove(address(_sablier), withdrawnAmount);

        // Create 30-day linear stream
        streamId = _sablier.createWithDurations(
            ISablierV2LockupLinear.CreateWithDurations({
                sender: address(this),
                recipient: config.recipient,
                totalAmount: uint128(withdrawnAmount),
                asset: collateralToken,
                cancelable: false,
                transferable: true,
                durations: ISablierV2LockupLinear.Durations({
                    cliff: 0,
                    total: STREAM_DURATION
                }),
                broker: ISablierV2LockupLinear.Broker({
                    account: address(0),
                    fee: 0
                })
            })
        );

        // Track stream
        config.lastStreamId = streamId;
        _vaultStreams[vaultTokenId].push(streamId);

        emit StreamCreated(
            vaultTokenId,
            streamId,
            config.recipient,
            withdrawnAmount,
            STREAM_DURATION
        );
    }

    /// @inheritdoc ISablierStreamWrapper
    function batchCreateStreams(uint256[] calldata vaultTokenIds)
        external
        nonReentrant
        returns (uint256[] memory streamIds)
    {
        streamIds = new uint256[](vaultTokenIds.length);

        for (uint256 i = 0; i < vaultTokenIds.length; i++) {
            uint256 vaultTokenId = vaultTokenIds[i];
            VaultStreamConfig storage config = _vaultConfigs[vaultTokenId];

            // Skip unconfigured or disabled vaults
            if (config.recipient == address(0) || !config.streamEnabled) {
                continue;
            }

            // Check if withdrawal is possible
            (bool canWithdraw, uint256 amount) = _vaultNFT.canDelegateWithdraw(
                vaultTokenId,
                address(this)
            );
            if (!canWithdraw || amount == 0) {
                continue;
            }

            // Withdraw and create stream
            uint256 withdrawnAmount = _vaultNFT.withdrawAsDelegate(vaultTokenId);
            if (withdrawnAmount == 0) continue;

            collateralToken.forceApprove(address(_sablier), withdrawnAmount);

            uint256 streamId = _sablier.createWithDurations(
                ISablierV2LockupLinear.CreateWithDurations({
                    sender: address(this),
                    recipient: config.recipient,
                    totalAmount: uint128(withdrawnAmount),
                    asset: collateralToken,
                    cancelable: false,
                    transferable: true,
                    durations: ISablierV2LockupLinear.Durations({
                        cliff: 0,
                        total: STREAM_DURATION
                    }),
                    broker: ISablierV2LockupLinear.Broker({
                        account: address(0),
                        fee: 0
                    })
                })
            );

            config.lastStreamId = streamId;
            _vaultStreams[vaultTokenId].push(streamId);
            streamIds[i] = streamId;

            emit StreamCreated(
                vaultTokenId,
                streamId,
                config.recipient,
                withdrawnAmount,
                STREAM_DURATION
            );
        }
    }

    /// @inheritdoc ISablierStreamWrapper
    function canCreateStream(uint256 vaultTokenId)
        external
        view
        returns (bool canCreate, uint256 amount)
    {
        VaultStreamConfig storage config = _vaultConfigs[vaultTokenId];

        if (config.recipient == address(0) || !config.streamEnabled) {
            return (false, 0);
        }

        return _vaultNFT.canDelegateWithdraw(vaultTokenId, address(this));
    }

    /// @inheritdoc ISablierStreamWrapper
    function getVaultConfig(uint256 vaultTokenId)
        external
        view
        returns (VaultStreamConfig memory config)
    {
        return _vaultConfigs[vaultTokenId];
    }

    /// @inheritdoc ISablierStreamWrapper
    function getVaultStreams(uint256 vaultTokenId)
        external
        view
        returns (uint256[] memory streamIds)
    {
        return _vaultStreams[vaultTokenId];
    }

    /// @inheritdoc ISablierStreamWrapper
    function vaultNFT() external view override returns (address) {
        return address(_vaultNFT);
    }

    /// @inheritdoc ISablierStreamWrapper
    function sablier() external view override returns (address) {
        return address(_sablier);
    }
}
