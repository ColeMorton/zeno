// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ChapterRegistry} from "../src/ChapterRegistry.sol";
import {ChapterMinter} from "../src/ChapterMinter.sol";
import {ChapterAchievementNFT} from "../src/ChapterAchievementNFT.sol";
import {ProfileRegistry} from "../src/ProfileRegistry.sol";
import {ProfileVerifier} from "../src/verifiers/ProfileVerifier.sol";
import {PresenceVerifier} from "../src/verifiers/PresenceVerifier.sol";
import {AggregateVerifier} from "../src/verifiers/AggregateVerifier.sol";
import {InteractionVerifier} from "../src/verifiers/InteractionVerifier.sol";
import {ReferralVerifier} from "../src/verifiers/ReferralVerifier.sol";
import {ApprovalVerifier} from "../src/verifiers/ApprovalVerifier.sol";
import {SignatureVerifier} from "../src/verifiers/SignatureVerifier.sol";
import {IdentityVerifier} from "../src/verifiers/IdentityVerifier.sol";

/// @notice Deployment script for Chapter 1 verifier system
/// @dev Deploys all verifiers and registers Chapter 1 achievements
contract DeployChapter1 is Script {
    // Chapter 1 config
    uint8 constant CHAPTER_NUMBER = 1;
    uint16 constant YEAR = 2025;
    uint8 constant QUARTER = 1;
    uint48 constant START_TIMESTAMP = 1735689600; // Jan 1, 2025 00:00:00 UTC
    uint48 constant END_TIMESTAMP = 1743552000;   // Apr 1, 2025 00:00:00 UTC
    uint256 constant MIN_DAYS_HELD = 0;
    uint256 constant MAX_DAYS_HELD = 90;

    // Deployed verifiers (stored to avoid stack too deep)
    address public profileRegistryAddr;
    address public profileVerifierAddr;
    address public presenceVerifierAddr;
    address public aggregateVerifierAddr;
    address public interactionVerifierAddr;
    address public referralVerifierAddr;
    address public approvalVerifierAddr;
    address public signatureVerifierAddr;
    address public identityVerifierAddr;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("Deploying Chapter 1 verifiers...");

        vm.startBroadcast(deployerPrivateKey);

        _deployVerifiers();
        _registerAchievements();

        vm.stopBroadcast();

        _logAddresses();
    }

    function _deployVerifiers() internal {
        address chapterAchievementNFT = vm.envAddress("CHAPTER_ACHIEVEMENT_NFT");
        address wbtc = vm.envAddress("WBTC");
        address vaultNFT = vm.envAddress("VAULT_NFT");

        // Deploy ProfileRegistry
        ProfileRegistry profileRegistry = new ProfileRegistry();
        profileRegistryAddr = address(profileRegistry);

        // Deploy Verifiers
        profileVerifierAddr = address(new ProfileVerifier(profileRegistryAddr));
        presenceVerifierAddr = address(new PresenceVerifier(profileRegistryAddr));
        aggregateVerifierAddr = address(new AggregateVerifier(chapterAchievementNFT));
        interactionVerifierAddr = address(new InteractionVerifier());
        referralVerifierAddr = address(new ReferralVerifier());
        approvalVerifierAddr = address(new ApprovalVerifier(wbtc, vaultNFT, 0));
        signatureVerifierAddr = address(new SignatureVerifier());
        identityVerifierAddr = address(new IdentityVerifier());
    }

    function _registerAchievements() internal {
        address chapterRegistry = vm.envAddress("CHAPTER_REGISTRY");
        ChapterRegistry registry = ChapterRegistry(chapterRegistry);

        // Create Chapter 1
        bytes32 chapterId = registry.createChapter(
            CHAPTER_NUMBER,
            YEAR,
            QUARTER,
            START_TIMESTAMP,
            END_TIMESTAMP,
            MIN_DAYS_HELD,
            MAX_DAYS_HELD,
            "ipfs://chapter1/"
        );

        bytes32[] memory noPrereqs = new bytes32[](0);

        // Week 1: TRAILHEAD
        registry.addAchievementWithVerifier(chapterId, "TRAILHEAD", noPrereqs, profileVerifierAddr);

        // Week 2: FIRST_STEPS (15 days)
        bytes32 firstSteps = registry.addAchievementWithVerifier(
            chapterId, "FIRST_STEPS", noPrereqs, presenceVerifierAddr
        );
        PresenceVerifier(presenceVerifierAddr).setRequiredDays(firstSteps, 15);

        // Week 3: WALLET_WARMED (1 interaction)
        bytes32 walletWarmed = registry.addAchievementWithVerifier(
            chapterId, "WALLET_WARMED", noPrereqs, interactionVerifierAddr
        );
        InteractionVerifier(interactionVerifierAddr).setRequirements(walletWarmed, 1, 0);

        // Week 4: IDENTIFIED
        registry.addAchievementWithVerifier(chapterId, "IDENTIFIED", noPrereqs, identityVerifierAddr);

        // Week 5: STEADY_PACE (30 days)
        bytes32 steadyPace = registry.addAchievementWithVerifier(
            chapterId, "STEADY_PACE", noPrereqs, presenceVerifierAddr
        );
        PresenceVerifier(presenceVerifierAddr).setRequiredDays(steadyPace, 30);

        // Week 6: EXPLORER (3 interactions)
        bytes32 explorer = registry.addAchievementWithVerifier(
            chapterId, "EXPLORER", noPrereqs, interactionVerifierAddr
        );
        InteractionVerifier(interactionVerifierAddr).setRequirements(explorer, 3, 0);

        // Week 7: GUIDE
        registry.addAchievementWithVerifier(chapterId, "GUIDE", noPrereqs, referralVerifierAddr);

        // Week 8: PREPARED
        registry.addAchievementWithVerifier(chapterId, "PREPARED", noPrereqs, approvalVerifierAddr);

        // Week 9: REGULAR (3 interactions across 3 days)
        bytes32 regular = registry.addAchievementWithVerifier(
            chapterId, "REGULAR", noPrereqs, interactionVerifierAddr
        );
        InteractionVerifier(interactionVerifierAddr).setRequirements(regular, 3, 3);

        // Week 10: COMMITTED (60 days)
        bytes32 committed = registry.addAchievementWithVerifier(
            chapterId, "COMMITTED", noPrereqs, presenceVerifierAddr
        );
        PresenceVerifier(presenceVerifierAddr).setRequiredDays(committed, 60);

        // Week 11: RESOLUTE
        registry.addAchievementWithVerifier(chapterId, "RESOLUTE", noPrereqs, signatureVerifierAddr);

        // Week 12: STUDENT (1 prior achievement)
        bytes32 student = registry.addAchievementWithVerifier(
            chapterId, "STUDENT", noPrereqs, aggregateVerifierAddr
        );
        AggregateVerifier(aggregateVerifierAddr).setRequiredCount(student, 1);

        // Week 13: CHAPTER_COMPLETE (10 achievements)
        bytes32 chapterComplete = registry.addAchievementWithVerifier(
            chapterId, "CHAPTER_COMPLETE", noPrereqs, aggregateVerifierAddr
        );
        AggregateVerifier(aggregateVerifierAddr).setRequiredCount(chapterComplete, 10);
    }

    function _logAddresses() internal view {
        console.log("\n=== Chapter 1 Deployment Complete ===");
        console.log("ProfileRegistry:", profileRegistryAddr);
        console.log("ProfileVerifier:", profileVerifierAddr);
        console.log("PresenceVerifier:", presenceVerifierAddr);
        console.log("AggregateVerifier:", aggregateVerifierAddr);
        console.log("InteractionVerifier:", interactionVerifierAddr);
        console.log("ReferralVerifier:", referralVerifierAddr);
        console.log("ApprovalVerifier:", approvalVerifierAddr);
        console.log("SignatureVerifier:", signatureVerifierAddr);
        console.log("IdentityVerifier:", identityVerifierAddr);
    }
}
