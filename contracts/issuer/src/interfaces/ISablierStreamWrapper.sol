// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ISablierStreamWrapper - Interface for VaultNFT to Sablier stream conversion
/// @notice Converts discrete monthly VaultNFT withdrawals into continuous Sablier streams
interface ISablierStreamWrapper {
    /// @notice Configuration for a vault's streaming setup
    struct VaultStreamConfig {
        address recipient;       // Who receives the stream
        bool streamEnabled;      // Whether streaming is active
        uint256 lastStreamId;    // Most recent stream created for this vault
    }

    /// @notice Emitted when a new stream is created from a vault withdrawal
    event StreamCreated(
        uint256 indexed vaultTokenId,
        uint256 indexed streamId,
        address indexed recipient,
        uint256 amount,
        uint40 duration
    );

    /// @notice Emitted when vault streaming configuration is updated
    event VaultConfigured(
        uint256 indexed vaultTokenId,
        address indexed recipient,
        bool enabled
    );

    error VaultNotConfigured(uint256 vaultTokenId);
    error NotVaultOwner(uint256 vaultTokenId);
    error StreamingDisabled(uint256 vaultTokenId);
    error WithdrawalFailed(uint256 vaultTokenId);
    error ZeroAmount();
    error ZeroAddress();

    /// @notice Configure streaming for a vault
    /// @param vaultTokenId The vault to configure
    /// @param recipient Address to receive streams
    /// @param enabled Whether streaming is active
    function configureVault(
        uint256 vaultTokenId,
        address recipient,
        bool enabled
    ) external;

    /// @notice Create a stream from a vault's available withdrawal
    /// @param vaultTokenId The vault to withdraw from
    /// @return streamId The Sablier stream ID created
    function createStreamFromVault(uint256 vaultTokenId) external returns (uint256 streamId);

    /// @notice Batch create streams from multiple vaults
    /// @param vaultTokenIds Array of vault token IDs
    /// @return streamIds Array of created stream IDs (0 if skipped)
    function batchCreateStreams(uint256[] calldata vaultTokenIds)
        external
        returns (uint256[] memory streamIds);

    /// @notice Check if a vault can create a stream now
    /// @param vaultTokenId The vault to check
    /// @return canCreate Whether stream creation is possible
    /// @return amount The amount that would be streamed
    function canCreateStream(uint256 vaultTokenId)
        external
        view
        returns (bool canCreate, uint256 amount);

    /// @notice Get the stream configuration for a vault
    /// @param vaultTokenId The vault to query
    /// @return config The vault's stream configuration
    function getVaultConfig(uint256 vaultTokenId)
        external
        view
        returns (VaultStreamConfig memory config);

    /// @notice Get all stream IDs created for a vault
    /// @param vaultTokenId The vault to query
    /// @return streamIds Array of stream IDs
    function getVaultStreams(uint256 vaultTokenId)
        external
        view
        returns (uint256[] memory streamIds);

    /// @notice Get the VaultNFT contract address
    /// @return The VaultNFT address
    function vaultNFT() external view returns (address);

    /// @notice Get the Sablier LockupLinear contract address
    /// @return The Sablier address
    function sablier() external view returns (address);

    /// @notice Get the stream duration (30 days)
    /// @return Duration in seconds
    function STREAM_DURATION() external view returns (uint40);
}
