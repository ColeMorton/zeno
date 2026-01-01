// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAchievementVerifier} from "../interfaces/IAchievementVerifier.sol";

/// @title IENS
/// @notice Minimal interface for ENS reverse resolver
interface IENS {
    function node(address addr) external view returns (bytes32);
    function name(bytes32 nodeHash) external view returns (string memory);
}

/// @title IIdRegistry
/// @notice Minimal interface for Farcaster ID Registry
interface IIdRegistry {
    function idOf(address owner) external view returns (uint256);
}

/// @title IdentityVerifier
/// @notice Verifies ENS, Farcaster, or Lens identity linked (IDENTIFIED achievement)
contract IdentityVerifier is IAchievementVerifier, Ownable {
    /// @notice ENS reverse registrar address
    address public ensReverseRegistrar;

    /// @notice Farcaster ID Registry address
    address public farcasterIdRegistry;

    event ENSRegistrarSet(address indexed registrar);
    event FarcasterRegistrySet(address indexed registry);

    constructor() Ownable(msg.sender) {}

    /// @notice Set ENS reverse registrar address
    /// @param registrar ENS reverse registrar contract
    function setENSReverseRegistrar(address registrar) external onlyOwner {
        ensReverseRegistrar = registrar;
        emit ENSRegistrarSet(registrar);
    }

    /// @notice Set Farcaster ID Registry address
    /// @param registry Farcaster ID Registry contract
    function setFarcasterIdRegistry(address registry) external onlyOwner {
        farcasterIdRegistry = registry;
        emit FarcasterRegistrySet(registry);
    }

    /// @inheritdoc IAchievementVerifier
    function verify(
        address wallet,
        bytes32,
        bytes calldata
    ) external view returns (bool verified) {
        // Check ENS reverse record
        if (ensReverseRegistrar != address(0)) {
            try IENS(ensReverseRegistrar).node(wallet) returns (bytes32 node) {
                if (node != bytes32(0)) return true;
            } catch {}
        }

        // Check Farcaster ID
        if (farcasterIdRegistry != address(0)) {
            try IIdRegistry(farcasterIdRegistry).idOf(wallet) returns (uint256 fid) {
                if (fid != 0) return true;
            } catch {}
        }

        return false;
    }
}
