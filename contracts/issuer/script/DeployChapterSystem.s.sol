// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {ChapterRegistry} from "../src/ChapterRegistry.sol";
import {ChapterMinter} from "../src/ChapterMinter.sol";
import {AchievementNFT} from "../src/AchievementNFT.sol";
import {ProfileRegistry} from "../src/ProfileRegistry.sol";
import {ProfileVerifier} from "../src/verifiers/ProfileVerifier.sol";
import {PresenceVerifier} from "../src/verifiers/PresenceVerifier.sol";
import {AggregateVerifier} from "../src/verifiers/AggregateVerifier.sol";
import {InteractionVerifier} from "../src/verifiers/InteractionVerifier.sol";
import {ReferralVerifier} from "../src/verifiers/ReferralVerifier.sol";
import {ApprovalVerifier} from "../src/verifiers/ApprovalVerifier.sol";
import {SignatureVerifier} from "../src/verifiers/SignatureVerifier.sol";
import {IdentityVerifier} from "../src/verifiers/IdentityVerifier.sol";

/// @notice Combined deployment script for full Chapter system + Chapter 1
/// @dev Deploys base contracts + all verifiers + registers Chapter 1 achievements
contract DeployChapterSystem is Script {
    // Chapter 1 config
    uint8 constant CHAPTER_NUMBER = 1;
    uint16 constant YEAR = 2025;
    uint8 constant QUARTER = 1;
    uint48 constant START_TIMESTAMP = 1735689600; // Jan 1, 2025 00:00:00 UTC
    uint48 constant END_TIMESTAMP = 1743552000;   // Apr 1, 2025 00:00:00 UTC
    uint256 constant MIN_DAYS_HELD = 0;
    uint256 constant MAX_DAYS_HELD = 90;

    // Core chapter contracts
    ChapterRegistry public registry;
    ChapterMinter public minter;
    AchievementNFT public achievementNFT;

    // Verifiers
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
        address vaultNFT = vm.envAddress("VAULT_CBBTC");
        address cbbtc = vm.envAddress("CBBTC");
        address treasureNFT = vm.envAddress("TREASURE");

        console.log("Deploying full Chapter System...");

        vm.startBroadcast(deployerPrivateKey);

        _deployBaseContracts(vaultNFT, cbbtc, treasureNFT);
        _deployVerifiers(cbbtc, vaultNFT);
        _registerChapter1();

        vm.stopBroadcast();

        _logAddresses();
    }

    function _deployBaseContracts(address vaultNFT, address cbbtc, address treasureNFT) internal {
        // Deploy ChapterRegistry
        registry = new ChapterRegistry();
        console.log("ChapterRegistry deployed");

        // Deploy AchievementNFT (unified)
        achievementNFT = new AchievementNFT(
            "The Ascent Achievements",
            "ASCENT",
            "ipfs://achievements/",
            true // useOnChainSVG
        );
        console.log("AchievementNFT deployed");

        // Prepare collateral arrays
        address[] memory collaterals = new address[](1);
        collaterals[0] = cbbtc;
        address[] memory protocols = new address[](1);
        protocols[0] = vaultNFT;

        // Deploy ChapterMinter
        minter = new ChapterMinter(
            address(achievementNFT),
            address(registry),
            treasureNFT,
            collaterals,
            protocols
        );
        console.log("ChapterMinter deployed");

        // Authorize minter
        achievementNFT.authorizeMinter(address(minter));
        console.log("ChapterMinter authorized");
    }

    function _deployVerifiers(address cbbtc, address vaultNFT) internal {
        // Deploy ProfileRegistry
        ProfileRegistry profileRegistry = new ProfileRegistry();
        profileRegistryAddr = address(profileRegistry);

        // Deploy all verifiers
        profileVerifierAddr = address(new ProfileVerifier(profileRegistryAddr));
        presenceVerifierAddr = address(new PresenceVerifier(profileRegistryAddr));
        aggregateVerifierAddr = address(new AggregateVerifier(address(achievementNFT)));
        interactionVerifierAddr = address(new InteractionVerifier());
        referralVerifierAddr = address(new ReferralVerifier());
        approvalVerifierAddr = address(new ApprovalVerifier(cbbtc, vaultNFT, 0));
        signatureVerifierAddr = address(new SignatureVerifier());
        identityVerifierAddr = address(new IdentityVerifier());

        console.log("All verifiers deployed");
    }

    function _registerChapter1() internal {
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
        console.log("Chapter 1 created");

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

        console.log("All 13 achievements registered");
    }

    function _logAddresses() internal view {
        console.log("\n=== Chapter System Deployment Complete ===");
        console.log("\n--- Core Contracts ---");
        console.log("CHAPTER_REGISTRY:", address(registry));
        console.log("CHAPTER_ACHIEVEMENT_NFT:", address(achievementNFT));
        console.log("CHAPTER_MINTER:", address(minter));
        console.log("\n--- Verifiers ---");
        console.log("PROFILE_REGISTRY:", profileRegistryAddr);
        console.log("PROFILE_VERIFIER:", profileVerifierAddr);
        console.log("PRESENCE_VERIFIER:", presenceVerifierAddr);
        console.log("AGGREGATE_VERIFIER:", aggregateVerifierAddr);
        console.log("INTERACTION_VERIFIER:", interactionVerifierAddr);
        console.log("REFERRAL_VERIFIER:", referralVerifierAddr);
        console.log("APPROVAL_VERIFIER:", approvalVerifierAddr);
        console.log("SIGNATURE_VERIFIER:", signatureVerifierAddr);
        console.log("IDENTITY_VERIFIER:", identityVerifierAddr);
    }
}
