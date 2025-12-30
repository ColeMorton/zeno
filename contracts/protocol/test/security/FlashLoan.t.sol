// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../src/VaultNFT.sol";
import {BtcToken} from "../../src/BtcToken.sol";
import {IVaultNFT} from "../../src/interfaces/IVaultNFT.sol";
import {MockTreasure} from "../mocks/MockTreasure.sol";
import {MockWBTC} from "../mocks/MockWBTC.sol";

/// @title Flash Loan Security Tests
/// @notice Documents protocol resilience against flash loan attacks
/// @dev The protocol has no oracle dependencies or spot price calculations,
///      making flash loan attacks economically infeasible
contract FlashLoanTest is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    address public alice;
    address public bob;
    address public attacker;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        attacker = makeAddr("attacker");

        treasure = new MockTreasure();
        wbtc = new MockWBTC();

        address vaultAddr = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);
        btcToken = new BtcToken(vaultAddr, "vestedBTC-wBTC", "vWBTC");
        vault = new VaultNFT(address(btcToken), address(wbtc), "Vault NFT-wBTC", "VAULT-W");

        wbtc.mint(alice, 100 * ONE_BTC);
        wbtc.mint(bob, 100 * ONE_BTC);
        wbtc.mint(attacker, 1000 * ONE_BTC);
        treasure.mintBatch(alice, 10);      // alice gets 0-9
        treasure.mintBatch(bob, 10);        // bob gets 10-19
        treasure.mintBatch(attacker, 10);   // attacker gets 20-29

        _approveAll(alice);
        _approveAll(bob);
        _approveAll(attacker);
    }

    function _approveAll(address user) internal {
        vm.startPrank(user);
        wbtc.approve(address(vault), type(uint256).max);
        treasure.setApprovalForAll(address(vault), true);
        vm.stopPrank();
    }

    /// @notice Flash loan cannot manipulate match pool share calculation
    /// @dev Match pool shares are based on deposited collateral, not current balance
    function test_FlashLoan_CannotManipulateMatchPoolShare() public {
        // Alice creates a vault
        vm.prank(alice);
        uint256 aliceToken = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        // Attacker creates vault with large flash-loaned amount
        // (simulating borrowing 1000 BTC via flash loan)
        vm.prank(attacker);
        uint256 attackerToken = vault.mint(address(treasure), 20, address(wbtc), 1000 * ONE_BTC);

        // Simulate early redemption creating match pool
        vm.warp(block.timestamp + 500 days);
        vm.prank(alice);
        vault.earlyRedeem(aliceToken);

        uint256 poolBeforeRepay = vault.matchPool();

        // Flash loan scenario: attacker must return funds in same transaction
        // They cannot claim match pool without waiting for vesting
        // Even with 1000 BTC deposited, they get proportional share only after 1129 days

        // Fast forward to vesting
        vm.warp(block.timestamp + VESTING_PERIOD);

        // Attacker can claim but only their proportional share
        vm.prank(attacker);
        uint256 claimed = vault.claimMatch(attackerToken);

        // The claim is based on their deposited collateral proportion
        // Pool distribution is fair regardless of deposit timing
        assertGt(claimed, 0, "Attacker gets share proportional to deposit");
        assertLt(claimed, poolBeforeRepay, "Attacker cannot drain entire pool");
    }

    /// @notice Flash loan cannot bypass vesting period
    /// @dev Vesting is based on mintTimestamp, not current holdings
    function test_FlashLoan_CannotBypassVesting() public {
        // Attacker flash loans large amount
        vm.prank(attacker);
        uint256 tokenId = vault.mint(address(treasure), 20, address(wbtc), 1000 * ONE_BTC);

        // Cannot withdraw immediately despite large deposit
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.withdraw(tokenId);

        // Cannot mint BTC token immediately
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.StillVesting.selector, tokenId));
        vault.mintBtcToken(tokenId);

        // Only time advances allow withdrawal (1129 days)
        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(attacker);
        uint256 withdrawn = vault.withdraw(tokenId);
        assertGt(withdrawn, 0, "Can withdraw after vesting");
    }

    /// @notice Flash loan cannot manipulate withdrawal amounts
    /// @dev Withdrawals are 1% of current collateral, calculated at withdrawal time
    function test_FlashLoan_NoWithdrawalManipulation() public {
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        // Withdrawal amount is deterministic: 1% of collateral
        uint256 expected = (ONE_BTC * 1000) / 100000; // 1% = 1000/100000

        vm.prank(alice);
        uint256 withdrawn = vault.withdraw(tokenId);

        assertEq(withdrawn, expected, "Withdrawal amount is deterministic");

        // Flash loan held by attacker has no effect on alice's withdrawal
        // There's no price oracle or liquidity pool to manipulate
    }

    /// @notice Flash loan cannot claim dormant collateral without burning BTC token
    /// @dev Dormancy claim requires burning original minted amount of BTC tokens
    function test_FlashLoan_CannotClaimDormantWithoutBtcToken() public {
        // Alice creates vault and mints BTC token
        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        vm.warp(block.timestamp + VESTING_PERIOD);

        vm.prank(alice);
        vault.mintBtcToken(tokenId);

        // Alice transfers BTC token to bob (not attacker)
        vm.prank(alice);
        btcToken.transfer(address(bob), ONE_BTC);

        // Wait for dormancy threshold
        vm.warp(block.timestamp + VESTING_PERIOD + 1);

        // Anyone can poke dormancy
        vm.prank(attacker);
        vault.pokeDormant(tokenId);

        // Wait for grace period to expire
        vm.warp(block.timestamp + 30 days);

        // Attacker cannot claim without BTC tokens
        // Even with flash loan, they cannot acquire the BTC tokens needed
        // Flash loans don't help because BTC tokens are held by bob
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(IVaultNFT.InsufficientBtcToken.selector, ONE_BTC, 0));
        vault.claimDormantCollateral(tokenId);

        // Only bob (who holds the BTC tokens) can claim
        vm.prank(bob);
        btcToken.approve(address(vault), ONE_BTC);
        uint256 bobBalanceBefore = wbtc.balanceOf(bob);
        vm.prank(bob);
        vault.claimDormantCollateral(tokenId);
        uint256 bobBalanceAfter = wbtc.balanceOf(bob);

        assertEq(bobBalanceAfter - bobBalanceBefore, ONE_BTC, "Bob claimed the collateral");
    }

    /// @notice Protocol has no price oracles to manipulate
    /// @dev All values are based on deposited amounts, not external prices
    function test_FlashLoan_NoPriceOracleToManipulate() public {
        // The protocol stores collateral amounts at deposit time
        // There's no oracle that could be manipulated via flash loan

        vm.prank(alice);
        uint256 tokenId = vault.mint(address(treasure), 0, address(wbtc), ONE_BTC);

        // Collateral is fixed at deposit time
        assertEq(vault.collateralAmount(tokenId), ONE_BTC);

        // Early redemption calculation is based on time elapsed, not prices
        vm.warp(block.timestamp + 500 days);

        vm.prank(alice);
        (uint256 returned, uint256 forfeited) = vault.earlyRedeem(tokenId);

        // Amounts are deterministic based on time
        assertEq(returned + forfeited, ONE_BTC, "Total equals original deposit");
    }
}
