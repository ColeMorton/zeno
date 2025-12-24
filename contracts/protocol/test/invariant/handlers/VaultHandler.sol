// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VaultNFT} from "../../../src/VaultNFT.sol";
import {BtcToken} from "../../../src/BtcToken.sol";
import {MockTreasure} from "../../mocks/MockTreasure.sol";
import {MockWBTC} from "../../mocks/MockWBTC.sol";

contract VaultHandler is Test {
    VaultNFT public vault;
    BtcToken public btcToken;
    MockTreasure public treasure;
    MockWBTC public wbtc;

    uint256 internal constant ONE_BTC = 1e8;
    uint256 internal constant VESTING_PERIOD = 1129 days;
    uint256 internal constant WITHDRAWAL_PERIOD = 30 days;

    address[] public actors;
    uint256[] public mintedTokenIds;
    mapping(address => uint256[]) public userTokenIds;
    mapping(address => uint256) public userTreasureOffset;

    // Ghost variables for tracking invariants
    uint256 public ghost_totalDeposited;
    uint256 public ghost_totalWithdrawn;
    uint256 public ghost_totalForfeited;
    uint256 public ghost_totalMatchClaimed;

    // Call counters for debugging
    uint256 public calls_mint;
    uint256 public calls_withdraw;
    uint256 public calls_earlyRedeem;
    uint256 public calls_claimMatch;
    uint256 public calls_warp;

    constructor(
        VaultNFT _vault,
        BtcToken _btcToken,
        MockTreasure _treasure,
        MockWBTC _wbtc,
        address[] memory _actors
    ) {
        vault = _vault;
        btcToken = _btcToken;
        treasure = _treasure;
        wbtc = _wbtc;
        actors = _actors;

        for (uint256 i = 0; i < _actors.length; i++) {
            userTreasureOffset[_actors[i]] = i * 100;
        }
    }

    modifier useActor(uint256 actorSeed) {
        address actor = actors[actorSeed % actors.length];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    function mint(uint256 actorSeed, uint256 collateral) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        collateral = bound(collateral, ONE_BTC / 100, 10 * ONE_BTC);

        uint256 treasureId = userTreasureOffset[actor] + userTokenIds[actor].length;

        if (wbtc.balanceOf(actor) < collateral) return;
        if (treasure.ownerOf(treasureId) != actor) return;

        uint256 tokenId = vault.mint(address(treasure), treasureId, address(wbtc), collateral);

        mintedTokenIds.push(tokenId);
        userTokenIds[actor].push(tokenId);
        ghost_totalDeposited += collateral;
        calls_mint++;
    }

    function withdraw(uint256 actorSeed, uint256 tokenSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userTokenIds[actor].length == 0) return;

        uint256 tokenId = userTokenIds[actor][tokenSeed % userTokenIds[actor].length];

        if (vault.ownerOf(tokenId) != actor) return;
        if (vault.collateralAmount(tokenId) == 0) return;

        try vault.withdraw(tokenId) returns (uint256 amount) {
            ghost_totalWithdrawn += amount;
            calls_withdraw++;
        } catch {}
    }

    function earlyRedeem(uint256 actorSeed, uint256 tokenSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userTokenIds[actor].length == 0) return;

        uint256 tokenIdx = tokenSeed % userTokenIds[actor].length;
        uint256 tokenId = userTokenIds[actor][tokenIdx];

        if (vault.ownerOf(tokenId) != actor) return;

        try vault.earlyRedeem(tokenId) returns (uint256 returned, uint256 forfeited) {
            ghost_totalWithdrawn += returned;
            ghost_totalForfeited += forfeited;

            _removeTokenFromUser(actor, tokenIdx);
            calls_earlyRedeem++;
        } catch {}
    }

    function claimMatch(uint256 actorSeed, uint256 tokenSeed) external useActor(actorSeed) {
        address actor = actors[actorSeed % actors.length];

        if (userTokenIds[actor].length == 0) return;

        uint256 tokenId = userTokenIds[actor][tokenSeed % userTokenIds[actor].length];

        if (vault.ownerOf(tokenId) != actor) return;

        try vault.claimMatch(tokenId) returns (uint256 amount) {
            ghost_totalMatchClaimed += amount;
            calls_claimMatch++;
        } catch {}
    }

    function warpTime(uint256 timeSeed) external {
        uint256 timeToWarp = bound(timeSeed, 1 days, 100 days);
        vm.warp(block.timestamp + timeToWarp);
        calls_warp++;
    }

    function warpPastVesting() external {
        vm.warp(block.timestamp + VESTING_PERIOD + 1);
        calls_warp++;
    }

    function _removeTokenFromUser(address user, uint256 idx) internal {
        uint256 lastIdx = userTokenIds[user].length - 1;
        if (idx != lastIdx) {
            userTokenIds[user][idx] = userTokenIds[user][lastIdx];
        }
        userTokenIds[user].pop();
    }

    // View functions for invariant checks
    function getMintedTokenCount() external view returns (uint256) {
        return mintedTokenIds.length;
    }

    function getActorCount() external view returns (uint256) {
        return actors.length;
    }

    function getCallSummary() external view returns (
        uint256 mints,
        uint256 withdraws,
        uint256 redeems,
        uint256 claims,
        uint256 warps
    ) {
        return (calls_mint, calls_withdraw, calls_earlyRedeem, calls_claimMatch, calls_warp);
    }
}
