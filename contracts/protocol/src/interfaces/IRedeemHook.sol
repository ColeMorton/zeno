// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IRedeemHook
/// @notice Callback interface for contracts bound to a vault via `VaultNFT.setRedeemHook`.
interface IRedeemHook {
    /// @notice Called by the vault contract at the end of a successful early redemption.
    /// @param tokenId The vault token ID that was redeemed and burned.
    /// @param redeemer The address that redeemed the vault.
    function onEarlyRedeem(uint256 tokenId, address redeemer) external;
}
