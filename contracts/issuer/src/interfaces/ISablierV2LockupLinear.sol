// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ISablierV2LockupLinear - External Sablier v2 interface
/// @notice Minimal interface for creating linear lockup streams
/// @dev See https://docs.sablier.com for full documentation
interface ISablierV2LockupLinear {
    /// @notice Duration configuration for linear streams
    struct Durations {
        uint40 cliff;   // Cliff duration in seconds (0 for no cliff)
        uint40 total;   // Total stream duration in seconds
    }

    /// @notice Broker fee configuration
    struct Broker {
        address account;    // Fee recipient address
        uint256 fee;        // Fee as UD60x18 (18 decimals, 1e18 = 100%)
    }

    /// @notice Parameters for createWithDurations
    struct CreateWithDurations {
        address sender;             // Stream sender (can cancel if cancelable)
        address recipient;          // Stream recipient
        uint128 totalAmount;        // Total tokens to stream
        IERC20 asset;              // Token being streamed
        bool cancelable;           // Whether stream can be cancelled
        bool transferable;         // Whether stream NFT can be transferred
        Durations durations;       // Cliff and total duration
        Broker broker;             // Optional broker fee
    }

    /// @notice Create a linear lockup stream with duration parameters
    /// @param params The stream creation parameters
    /// @return streamId The ID of the created stream (also an ERC-721 token ID)
    function createWithDurations(CreateWithDurations calldata params)
        external
        returns (uint256 streamId);

    /// @notice Withdraw maximum available amount from a stream
    /// @param streamId The stream to withdraw from
    /// @param to The address to receive withdrawn tokens
    /// @return withdrawnAmount The amount withdrawn
    function withdrawMax(uint256 streamId, address to)
        external
        returns (uint128 withdrawnAmount);

    /// @notice Get the withdrawable amount from a stream
    /// @param streamId The stream to query
    /// @return withdrawableAmount The amount currently withdrawable
    function withdrawableAmountOf(uint256 streamId)
        external
        view
        returns (uint128 withdrawableAmount);

    /// @notice Check if a stream is depleted (fully withdrawn)
    /// @param streamId The stream to check
    /// @return isDepleted True if fully withdrawn
    function isDepleted(uint256 streamId) external view returns (bool isDepleted);

    /// @notice Get the recipient of a stream
    /// @param streamId The stream to query
    /// @return recipient The recipient address
    function getRecipient(uint256 streamId) external view returns (address recipient);

    /// @notice Get the deposited amount for a stream
    /// @param streamId The stream to query
    /// @return depositedAmount The total deposited amount
    function getDepositedAmount(uint256 streamId)
        external
        view
        returns (uint128 depositedAmount);
}
