// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {VaultNFT} from "../../src/VaultNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Malicious delegate contract that attempts reentrancy during withdrawal
contract MaliciousDelegate {
    VaultNFT public vault;
    IERC20 public wbtc;

    uint256 public attackTokenId;
    uint256 public attackCount;
    uint256 public maxAttacks;
    bool public attacking;

    event AttackAttempted(uint256 count, uint256 balance);

    constructor(VaultNFT _vault, IERC20 _wbtc) {
        vault = _vault;
        wbtc = _wbtc;
        maxAttacks = 3;
    }

    function attemptWithdrawal(uint256 tokenId) external {
        attackTokenId = tokenId;
        attackCount = 0;
        attacking = true;

        vault.withdrawAsDelegate(tokenId);

        attacking = false;
    }

    /// @notice Fallback that attempts reentrancy when receiving WBTC
    /// Note: This won't actually work with ERC20 transfers since they don't trigger receive()
    /// But this tests the contract's resilience to such attacks if it were vulnerable
    receive() external payable {
        if (attacking && attackCount < maxAttacks) {
            attackCount++;
            emit AttackAttempted(attackCount, wbtc.balanceOf(address(this)));

            // Attempt reentrant withdrawal
            try vault.withdrawAsDelegate(attackTokenId) {
                // If this succeeds, we've found a reentrancy vulnerability
            } catch {
                // Expected: should revert due to period check or state update
            }
        }
    }

    /// @notice Allow withdrawal of funds for testing
    function withdrawFunds(address to) external {
        uint256 balance = wbtc.balanceOf(address(this));
        if (balance > 0) {
            wbtc.transfer(to, balance);
        }
    }
}
