// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IVaultNFT is IERC721 {
    enum DormancyState {
        ACTIVE,
        POKE_PENDING,
        CLAIMABLE
    }

    struct DelegatePermission {
        uint256 percentageBPS;      // Basis points (100 = 1%, 10000 = 100%)
        uint256 lastWithdrawal;     // Timestamp of last withdrawal
        uint256 grantedAt;          // When permission was granted
        bool active;                // Permission status
    }

    event VaultMinted(
        uint256 indexed tokenId,
        address indexed owner,
        address treasureContract,
        uint256 treasureTokenId,
        uint256 collateral
    );
    event Withdrawn(uint256 indexed tokenId, address indexed to, uint256 amount);
    event EarlyRedemption(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 returned,
        uint256 forfeited
    );
    event BtcTokenMinted(uint256 indexed tokenId, address indexed to, uint256 amount);
    event BtcTokenReturned(uint256 indexed tokenId, address indexed from, uint256 amount);
    event MatchClaimed(uint256 indexed tokenId, uint256 amount);
    event MatchPoolFunded(uint256 amount, uint256 newBalance);
    event DormantPoked(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed poker,
        uint256 graceDeadline
    );
    event DormancyStateChanged(uint256 indexed tokenId, DormancyState newState);
    event ActivityProven(uint256 indexed tokenId, address indexed owner);
    event DormantCollateralClaimed(
        uint256 indexed tokenId,
        address indexed originalOwner,
        address indexed claimer,
        uint256 collateralClaimed
    );

    // Delegation events
    event WithdrawalDelegateGranted(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 percentageBPS
    );
    event WithdrawalDelegateRevoked(
        uint256 indexed tokenId,
        address indexed delegate
    );
    event AllWithdrawalDelegatesRevoked(uint256 indexed tokenId);
    event DelegatedWithdrawal(
        uint256 indexed tokenId,
        address indexed delegate,
        uint256 amount
    );

    error NotTokenOwner(uint256 tokenId);
    error StillVesting(uint256 tokenId);
    error WithdrawalTooSoon(uint256 tokenId, uint256 nextAllowed);
    error ZeroCollateral();
    error BtcTokenAlreadyMinted(uint256 tokenId);
    error BtcTokenRequired(uint256 tokenId);
    error InsufficientBtcToken(uint256 required, uint256 available);
    error NotVested(uint256 tokenId);
    error AlreadyClaimed(uint256 tokenId);
    error NoPoolAvailable();
    error NotDormantEligible(uint256 tokenId);
    error AlreadyPoked(uint256 tokenId);
    error NotClaimable(uint256 tokenId);
    error InvalidCollateralToken(address token);
    error TokenDoesNotExist(uint256 tokenId);

    // Delegation errors
    error ZeroAddress();
    error CannotDelegateSelf();
    error InvalidPercentage(uint256 percentage);
    error ExceedsDelegationLimit();
    error DelegateNotActive(uint256 tokenId, address delegate);
    error NotActiveDelegate(uint256 tokenId, address delegate);
    error WithdrawalPeriodNotMet(uint256 tokenId, address delegate);

    function mint(
        address treasureContract,
        uint256 treasureTokenId,
        address collateralToken,
        uint256 collateralAmount
    ) external returns (uint256 tokenId);

    function withdraw(uint256 tokenId) external returns (uint256 amount);

    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited);

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount);

    function returnBtcToken(uint256 tokenId) external;

    function claimMatch(uint256 tokenId) external returns (uint256 amount);

    function pokeDormant(uint256 tokenId) external;

    function proveActivity(uint256 tokenId) external;

    function claimDormantCollateral(uint256 tokenId) external returns (uint256 collateral);

    function isDormantEligible(uint256 tokenId)
        external
        view
        returns (bool eligible, DormancyState state);

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract,
            uint256 treasureTokenId,
            address collateralToken,
            uint256 collateralAmount,
            uint256 mintTimestamp,
            uint256 lastWithdrawal,
            uint256 lastActivity,
            uint256 btcTokenAmount,
            uint256 originalMintedAmount
        );

    function isVested(uint256 tokenId) external view returns (bool);

    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256);

    function getCollateralClaim(uint256 tokenId) external view returns (uint256);

    function getClaimValue(address holder, uint256 tokenId) external view returns (uint256);

    // ========== Withdrawal Delegation Functions ==========
    
    function grantWithdrawalDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS
    ) external;

    function revokeWithdrawalDelegate(uint256 tokenId, address delegate) external;

    function revokeAllWithdrawalDelegates(uint256 tokenId) external;

    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount);

    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount);

    function getDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (DelegatePermission memory);

    function totalDelegatedBPS(uint256 tokenId) external view returns (uint256);
}
