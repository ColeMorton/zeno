// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IProfileRegistry} from "./interfaces/IProfileRegistry.sol";

/// @title ProfileRegistry
/// @notice On-chain profile storage for TRAILHEAD achievement verification
/// @dev Stores registration timestamp per wallet for presence-based achievements
contract ProfileRegistry is IProfileRegistry {
    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    /// @notice Wallet address to registration timestamp (0 = not registered)
    mapping(address => uint256) private _registeredAt;

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc IProfileRegistry
    function createProfile() external {
        if (_registeredAt[msg.sender] != 0) revert AlreadyRegistered();
        _registeredAt[msg.sender] = block.timestamp;
        emit ProfileCreated(msg.sender, block.timestamp);
    }

    /// @inheritdoc IProfileRegistry
    function hasProfile(address wallet) external view returns (bool) {
        return _registeredAt[wallet] != 0;
    }

    /// @inheritdoc IProfileRegistry
    function registeredAt(address wallet) external view returns (uint256) {
        return _registeredAt[wallet];
    }

    /// @inheritdoc IProfileRegistry
    function getDaysRegistered(address wallet) external view returns (uint256) {
        uint256 regTime = _registeredAt[wallet];
        if (regTime == 0) return 0;
        return (block.timestamp - regTime) / 1 days;
    }
}
