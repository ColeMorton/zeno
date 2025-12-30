// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISablierV2LockupLinear} from "../../src/interfaces/ISablierV2LockupLinear.sol";

/// @notice Mock Sablier V2 LockupLinear for testing
contract MockSablierV2LockupLinear is ERC721, ISablierV2LockupLinear {
    using SafeERC20 for IERC20;

    struct Stream {
        address sender;
        address recipient;
        uint128 totalAmount;
        uint128 withdrawnAmount;
        IERC20 asset;
        uint40 startTime;
        uint40 endTime;
        bool cancelable;
        bool transferable;
    }

    uint256 private _nextStreamId;
    mapping(uint256 => Stream) public streams;

    constructor() ERC721("Mock Sablier Stream", "MSTREAM") {}

    /// @inheritdoc ISablierV2LockupLinear
    function createWithDurations(CreateWithDurations calldata params)
        external
        override
        returns (uint256 streamId)
    {
        // Transfer tokens from sender
        params.asset.safeTransferFrom(msg.sender, address(this), params.totalAmount);

        streamId = _nextStreamId++;

        streams[streamId] = Stream({
            sender: params.sender,
            recipient: params.recipient,
            totalAmount: params.totalAmount,
            withdrawnAmount: 0,
            asset: params.asset,
            startTime: uint40(block.timestamp) + params.durations.cliff,
            endTime: uint40(block.timestamp) + params.durations.total,
            cancelable: params.cancelable,
            transferable: params.transferable
        });

        _mint(params.recipient, streamId);
    }

    /// @inheritdoc ISablierV2LockupLinear
    function withdrawMax(uint256 streamId, address to)
        external
        override
        returns (uint128 withdrawnAmount)
    {
        Stream storage stream = streams[streamId];

        if (msg.sender != stream.recipient && msg.sender != ownerOf(streamId)) {
            revert("Not authorized");
        }

        withdrawnAmount = withdrawableAmountOf(streamId);
        if (withdrawnAmount == 0) return 0;

        stream.withdrawnAmount += withdrawnAmount;
        stream.asset.safeTransfer(to, withdrawnAmount);
    }

    /// @inheritdoc ISablierV2LockupLinear
    function withdrawableAmountOf(uint256 streamId)
        public
        view
        override
        returns (uint128 withdrawableAmount)
    {
        Stream storage stream = streams[streamId];

        if (block.timestamp < stream.startTime) {
            return 0;
        }

        uint128 streamedAmount;
        if (block.timestamp >= stream.endTime) {
            streamedAmount = stream.totalAmount;
        } else {
            uint256 elapsed = block.timestamp - stream.startTime;
            uint256 duration = stream.endTime - stream.startTime;
            streamedAmount = uint128((uint256(stream.totalAmount) * elapsed) / duration);
        }

        withdrawableAmount = streamedAmount - stream.withdrawnAmount;
    }

    /// @inheritdoc ISablierV2LockupLinear
    function isDepleted(uint256 streamId)
        external
        view
        override
        returns (bool)
    {
        return streams[streamId].withdrawnAmount >= streams[streamId].totalAmount;
    }

    /// @inheritdoc ISablierV2LockupLinear
    function getRecipient(uint256 streamId)
        external
        view
        override
        returns (address recipient)
    {
        return streams[streamId].recipient;
    }

    /// @inheritdoc ISablierV2LockupLinear
    function getDepositedAmount(uint256 streamId)
        external
        view
        override
        returns (uint128 depositedAmount)
    {
        return streams[streamId].totalAmount;
    }

    /// @notice Test helper to get stream details
    function getStream(uint256 streamId) external view returns (Stream memory) {
        return streams[streamId];
    }

    /// @notice Test helper to warp time for stream testing
    function totalSupply() external view returns (uint256) {
        return _nextStreamId;
    }
}
