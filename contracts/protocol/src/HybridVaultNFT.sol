// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IHybridVaultNFT} from "./interfaces/IHybridVaultNFT.sol";
import {IBtcToken} from "./interfaces/IBtcToken.sol";
import {VaultMath} from "./libraries/VaultMath.sol";

/// @title HybridVaultNFT
/// @notice Dual-collateral vault NFT with asymmetric withdrawal models
/// @dev Primary: 1% monthly perpetual withdrawal | Secondary: 100% one-time at vesting
contract HybridVaultNFT is ERC721, IHybridVaultNFT {
    using SafeERC20 for IERC20;

    /// @notice Address to burn tokens (treasure NFTs on early redemption)
    address public constant BURN_ADDRESS = address(0xdead);
    /// @notice Full 100% in basis points
    uint256 public constant FULL_BPS = 10000;

    uint256 private _nextTokenId;

    IBtcToken public immutable btcToken;
    address public immutable primaryToken;
    address public immutable secondaryToken;

    // Per-vault state
    mapping(uint256 => uint256) private _primaryAmount;
    mapping(uint256 => uint256) private _secondaryAmount;
    mapping(uint256 => uint256) private _mintTimestamp;
    mapping(uint256 => uint256) private _lastPrimaryWithdrawal;
    mapping(uint256 => bool) private _secondaryWithdrawn;
    mapping(uint256 => uint256) private _lastActivity;
    mapping(uint256 => uint256) private _pokeTimestamp;

    // Treasure state
    mapping(uint256 => address) private _treasureContract;
    mapping(uint256 => uint256) private _treasureTokenId;

    // vestedBTC separation state (primary only)
    mapping(uint256 => uint256) private _btcTokenAmount;
    mapping(uint256 => uint256) private _originalMintedAmount;

    // Match pools
    uint256 public primaryMatchPool;
    uint256 public secondaryMatchPool;
    uint256 public totalActivePrimary;
    uint256 public totalActiveSecondary;
    mapping(uint256 => bool) public primaryMatured;
    mapping(uint256 => bool) public secondaryMatured;
    mapping(uint256 => bool) public primaryMatchClaimed;
    mapping(uint256 => bool) public secondaryMatchClaimed;
    uint256 private _primarySnapshotDenominator;
    uint256 private _secondarySnapshotDenominator;

    // Wallet-level delegation
    mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;
    mapping(address => uint256) public walletTotalDelegatedBPS;
    mapping(address => mapping(uint256 => uint256)) public delegateVaultCooldown;

    // Vault-level delegation
    mapping(uint256 => mapping(address => VaultDelegatePermission)) public vaultDelegates;
    mapping(uint256 => uint256) public vaultTotalDelegatedBPS;

    constructor(
        address _btcToken,
        address _primaryToken,
        address _secondaryToken,
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {
        if (_btcToken == address(0)) revert ZeroAddress();
        if (_primaryToken == address(0)) revert ZeroAddress();
        if (_secondaryToken == address(0)) revert ZeroAddress();
        btcToken = IBtcToken(_btcToken);
        primaryToken = _primaryToken;
        secondaryToken = _secondaryToken;
    }

    // ========== Core Functions ==========

    function mint(
        address treasureContract_,
        uint256 treasureTokenId_,
        uint256 primaryAmount_,
        uint256 secondaryAmount_
    ) external returns (uint256 tokenId) {
        if (primaryAmount_ == 0) revert ZeroPrimaryCollateral();
        if (secondaryAmount_ == 0) revert ZeroSecondaryCollateral();

        IERC721(treasureContract_).transferFrom(msg.sender, address(this), treasureTokenId_);
        IERC20(primaryToken).safeTransferFrom(msg.sender, address(this), primaryAmount_);
        IERC20(secondaryToken).safeTransferFrom(msg.sender, address(this), secondaryAmount_);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        _treasureContract[tokenId] = treasureContract_;
        _treasureTokenId[tokenId] = treasureTokenId_;
        _primaryAmount[tokenId] = primaryAmount_;
        _secondaryAmount[tokenId] = secondaryAmount_;
        _mintTimestamp[tokenId] = block.timestamp;
        _lastActivity[tokenId] = block.timestamp;

        totalActivePrimary += primaryAmount_;
        totalActiveSecondary += secondaryAmount_;

        emit HybridVaultMinted(
            tokenId,
            msg.sender,
            treasureContract_,
            treasureTokenId_,
            primaryAmount_,
            secondaryAmount_
        );
    }

    function withdrawPrimary(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (!VaultMath.canWithdraw(_lastPrimaryWithdrawal[tokenId], block.timestamp)) {
            revert PrimaryWithdrawalTooSoon(tokenId, _lastPrimaryWithdrawal[tokenId] + VaultMath.WITHDRAWAL_PERIOD);
        }

        amount = VaultMath.calculateWithdrawal(_primaryAmount[tokenId]);
        if (amount == 0) return 0;

        _primaryAmount[tokenId] -= amount;
        _lastPrimaryWithdrawal[tokenId] = block.timestamp;
        _updateActivity(tokenId);

        IERC20(primaryToken).safeTransfer(msg.sender, amount);

        emit PrimaryWithdrawn(tokenId, msg.sender, amount);
    }

    function withdrawSecondary(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (_secondaryWithdrawn[tokenId]) {
            revert SecondaryAlreadyWithdrawn(tokenId);
        }

        amount = _secondaryAmount[tokenId];
        _secondaryAmount[tokenId] = 0;
        _secondaryWithdrawn[tokenId] = true;
        _updateActivity(tokenId);

        IERC20(secondaryToken).safeTransfer(msg.sender, amount);

        emit SecondaryWithdrawn(tokenId, msg.sender, amount);
    }

    function earlyRedeem(uint256 tokenId)
        external
        returns (
            uint256 primaryReturned,
            uint256 primaryForfeited,
            uint256 secondaryReturned,
            uint256 secondaryForfeited
        )
    {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        // Handle vestedBTC return if separated
        if (_btcTokenAmount[tokenId] > 0) {
            uint256 required = _originalMintedAmount[tokenId];
            uint256 available = btcToken.balanceOf(msg.sender);
            if (available < required) {
                revert InsufficientBtcToken(required, available);
            }
            btcToken.burnFrom(msg.sender, required);
            _btcTokenAmount[tokenId] = 0;
            _originalMintedAmount[tokenId] = 0;
        }

        uint256 primary = _primaryAmount[tokenId];
        uint256 secondary = _secondaryAmount[tokenId];

        // Calculate primary early redemption (same formula as VaultNFT)
        (primaryReturned, primaryForfeited) = VaultMath.calculateEarlyRedemption(
            primary,
            _mintTimestamp[tokenId],
            block.timestamp
        );

        // Calculate secondary early redemption (same linear ramp)
        (secondaryReturned, secondaryForfeited) = VaultMath.calculateEarlyRedemption(
            secondary,
            _mintTimestamp[tokenId],
            block.timestamp
        );

        // Fund match pools
        if (primaryForfeited > 0) {
            _primarySnapshotDenominator = totalActivePrimary;
            primaryMatchPool += primaryForfeited;
            emit PrimaryMatchPoolFunded(primaryForfeited, primaryMatchPool);
        }

        if (secondaryForfeited > 0) {
            _secondarySnapshotDenominator = totalActiveSecondary;
            secondaryMatchPool += secondaryForfeited;
            emit SecondaryMatchPoolFunded(secondaryForfeited, secondaryMatchPool);
        }

        // Update active totals
        if (!primaryMatured[tokenId]) {
            totalActivePrimary -= primary;
        }
        if (!secondaryMatured[tokenId]) {
            totalActiveSecondary -= secondary;
        }

        // Burn treasure
        address treasureContract_ = _treasureContract[tokenId];
        uint256 treasureTokenId_ = _treasureTokenId[tokenId];
        IERC721(treasureContract_).transferFrom(address(this), BURN_ADDRESS, treasureTokenId_);

        // Clear state and burn vault
        _clearVaultState(tokenId);
        _burn(tokenId);

        // Transfer returned collateral
        if (primaryReturned > 0) {
            IERC20(primaryToken).safeTransfer(msg.sender, primaryReturned);
        }
        if (secondaryReturned > 0) {
            IERC20(secondaryToken).safeTransfer(msg.sender, secondaryReturned);
        }

        emit HybridEarlyRedemption(
            tokenId,
            msg.sender,
            primaryReturned,
            primaryForfeited,
            secondaryReturned,
            secondaryForfeited
        );
    }

    // ========== vestedBTC Separation (Primary Only) ==========

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (_btcTokenAmount[tokenId] > 0) {
            revert BtcTokenAlreadyMinted(tokenId);
        }

        amount = _primaryAmount[tokenId];
        _btcTokenAmount[tokenId] = amount;
        _originalMintedAmount[tokenId] = amount;
        _updateActivity(tokenId);

        btcToken.mint(msg.sender, amount);

        emit BtcTokenMinted(tokenId, msg.sender, amount);
    }

    function returnBtcToken(uint256 tokenId) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (_btcTokenAmount[tokenId] == 0) {
            revert BtcTokenRequired(tokenId);
        }

        uint256 required = _originalMintedAmount[tokenId];
        uint256 available = btcToken.balanceOf(msg.sender);
        if (available < required) {
            revert InsufficientBtcToken(required, available);
        }

        btcToken.burnFrom(msg.sender, required);
        _btcTokenAmount[tokenId] = 0;
        _originalMintedAmount[tokenId] = 0;
        _updateActivity(tokenId);

        emit BtcTokenReturned(tokenId, msg.sender, required);
    }

    // ========== Match Pool Claims ==========

    function claimPrimaryMatch(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert NotVested(tokenId);
        }
        if (primaryMatchClaimed[tokenId]) revert AlreadyClaimed(tokenId);
        if (primaryMatchPool == 0) revert NoPoolAvailable();

        if (!primaryMatured[tokenId]) {
            totalActivePrimary -= _primaryAmount[tokenId];
            primaryMatured[tokenId] = true;
        }

        uint256 denominator = _primarySnapshotDenominator > 0 ? _primarySnapshotDenominator : totalActivePrimary;
        if (denominator == 0) revert NoPoolAvailable();

        amount = VaultMath.calculateMatchShare(primaryMatchPool, _primaryAmount[tokenId], denominator);
        if (amount == 0) revert NoPoolAvailable();

        primaryMatchClaimed[tokenId] = true;
        primaryMatchPool -= amount;
        _primaryAmount[tokenId] += amount;
        _updateActivity(tokenId);

        emit PrimaryMatchClaimed(tokenId, amount);
    }

    function claimSecondaryMatch(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert NotVested(tokenId);
        }
        if (secondaryMatchClaimed[tokenId]) revert AlreadyClaimed(tokenId);
        if (secondaryMatchPool == 0) revert NoPoolAvailable();

        if (!secondaryMatured[tokenId]) {
            totalActiveSecondary -= _secondaryAmount[tokenId];
            secondaryMatured[tokenId] = true;
        }

        uint256 denominator =
            _secondarySnapshotDenominator > 0 ? _secondarySnapshotDenominator : totalActiveSecondary;
        if (denominator == 0) revert NoPoolAvailable();

        amount = VaultMath.calculateMatchShare(secondaryMatchPool, _secondaryAmount[tokenId], denominator);
        if (amount == 0) revert NoPoolAvailable();

        secondaryMatchClaimed[tokenId] = true;
        secondaryMatchPool -= amount;
        _secondaryAmount[tokenId] += amount;
        _updateActivity(tokenId);

        emit SecondaryMatchClaimed(tokenId, amount);
    }

    // ========== Dormancy Functions ==========

    function pokeDormant(uint256 tokenId) external {
        _requireOwned(tokenId);
        (bool eligible, DormancyState state) = isDormantEligible(tokenId);
        if (!eligible) revert NotDormantEligible(tokenId);
        if (state != DormancyState.ACTIVE) revert AlreadyPoked(tokenId);

        _pokeTimestamp[tokenId] = block.timestamp;

        emit DormantPoked(
            tokenId,
            ownerOf(tokenId),
            msg.sender,
            block.timestamp + VaultMath.GRACE_PERIOD
        );
        emit DormancyStateChanged(tokenId, DormancyState.POKE_PENDING);
    }

    function proveActivity(uint256 tokenId) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        _updateActivity(tokenId);

        emit ActivityProven(tokenId, msg.sender);
    }

    function claimDormantCollateral(uint256 tokenId) external returns (uint256 primary, uint256 secondary) {
        _requireOwned(tokenId);
        (, DormancyState state) = isDormantEligible(tokenId);
        if (state != DormancyState.CLAIMABLE) revert NotClaimable(tokenId);

        uint256 required = _originalMintedAmount[tokenId];
        uint256 available = btcToken.balanceOf(msg.sender);
        if (available < required) {
            revert InsufficientBtcToken(required, available);
        }

        address originalOwner = ownerOf(tokenId);
        primary = _primaryAmount[tokenId];
        secondary = _secondaryAmount[tokenId];
        address treasureContract_ = _treasureContract[tokenId];
        uint256 treasureTokenId_ = _treasureTokenId[tokenId];

        btcToken.burnFrom(msg.sender, required);

        _clearVaultState(tokenId);
        _burn(tokenId);

        IERC721(treasureContract_).transferFrom(address(this), BURN_ADDRESS, treasureTokenId_);
        IERC20(primaryToken).safeTransfer(msg.sender, primary);
        if (secondary > 0) {
            IERC20(secondaryToken).safeTransfer(msg.sender, secondary);
        }

        emit DormantCollateralClaimed(tokenId, originalOwner, msg.sender, primary, secondary);
    }

    function isDormantEligible(uint256 tokenId)
        public
        view
        returns (bool eligible, DormancyState state)
    {
        _requireOwned(tokenId);

        if (_btcTokenAmount[tokenId] == 0) {
            return (false, DormancyState.ACTIVE);
        }

        address owner_ = ownerOf(tokenId);
        if (btcToken.balanceOf(owner_) >= _btcTokenAmount[tokenId]) {
            return (false, DormancyState.ACTIVE);
        }

        if (!VaultMath.isDormant(_lastActivity[tokenId], block.timestamp)) {
            return (false, DormancyState.ACTIVE);
        }

        eligible = true;

        if (_pokeTimestamp[tokenId] == 0) {
            state = DormancyState.ACTIVE;
        } else if (VaultMath.isGracePeriodExpired(_pokeTimestamp[tokenId], block.timestamp)) {
            state = DormancyState.CLAIMABLE;
        } else {
            state = DormancyState.POKE_PENDING;
        }
    }

    // ========== Wallet-Level Delegation ==========

    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external {
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateSelf();
        if (percentageBPS == 0 || percentageBPS > FULL_BPS) revert InvalidPercentage(percentageBPS);

        uint256 currentDelegated = walletTotalDelegatedBPS[msg.sender];
        WalletDelegatePermission storage existingPermission = walletDelegates[msg.sender][delegate];
        bool isUpdate = existingPermission.active;
        uint256 oldPercentageBPS = existingPermission.percentageBPS;

        if (isUpdate) {
            currentDelegated -= oldPercentageBPS;
        }
        if (currentDelegated + percentageBPS > FULL_BPS) revert ExceedsDelegationLimit();

        walletDelegates[msg.sender][delegate] = WalletDelegatePermission({
            percentageBPS: percentageBPS,
            grantedAt: block.timestamp,
            active: true
        });

        walletTotalDelegatedBPS[msg.sender] = currentDelegated + percentageBPS;

        if (isUpdate) {
            emit WalletDelegateUpdated(msg.sender, delegate, oldPercentageBPS, percentageBPS);
        } else {
            emit WalletDelegateGranted(msg.sender, delegate, percentageBPS);
        }
    }

    function revokeWithdrawalDelegate(address delegate) external {
        WalletDelegatePermission storage permission = walletDelegates[msg.sender][delegate];
        if (!permission.active) revert DelegateNotActive(msg.sender, delegate);

        walletTotalDelegatedBPS[msg.sender] -= permission.percentageBPS;
        permission.active = false;

        emit WalletDelegateRevoked(msg.sender, delegate);
    }

    function revokeAllWithdrawalDelegates() external {
        walletTotalDelegatedBPS[msg.sender] = 0;
        emit AllWalletDelegatesRevoked(msg.sender);
    }

    // ========== Vault-Level Delegation ==========

    function grantVaultDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS,
        uint256 durationSeconds
    ) external {
        if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateSelf();
        if (percentageBPS == 0 || percentageBPS > FULL_BPS) revert InvalidPercentage(percentageBPS);

        uint256 currentVaultDelegated = vaultTotalDelegatedBPS[tokenId];
        VaultDelegatePermission storage existing = vaultDelegates[tokenId][delegate];
        bool isUpdate = existing.active;
        uint256 oldPercentageBPS = existing.percentageBPS;

        if (isUpdate) {
            currentVaultDelegated -= oldPercentageBPS;
        }
        if (currentVaultDelegated + percentageBPS > FULL_BPS) revert ExceedsVaultDelegationLimit(tokenId);

        uint256 expiresAt = durationSeconds > 0 ? block.timestamp + durationSeconds : 0;
        vaultDelegates[tokenId][delegate] = VaultDelegatePermission({
            percentageBPS: percentageBPS,
            grantedAt: block.timestamp,
            expiresAt: expiresAt,
            active: true
        });
        vaultTotalDelegatedBPS[tokenId] = currentVaultDelegated + percentageBPS;

        if (isUpdate) {
            emit VaultDelegateUpdated(tokenId, delegate, oldPercentageBPS, percentageBPS, expiresAt);
        } else {
            emit VaultDelegateGranted(tokenId, delegate, percentageBPS, expiresAt);
        }
    }

    function revokeVaultDelegate(uint256 tokenId, address delegate) external {
        if (ownerOf(tokenId) != msg.sender) revert NotVaultOwner(tokenId);

        VaultDelegatePermission storage permission = vaultDelegates[tokenId][delegate];
        if (!permission.active) revert VaultDelegateNotActive(tokenId, delegate);

        vaultTotalDelegatedBPS[tokenId] -= permission.percentageBPS;
        permission.active = false;

        emit VaultDelegateRevoked(tokenId, delegate);
    }

    function withdrawPrimaryAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
        _requireOwned(tokenId);
        address vaultOwner = ownerOf(tokenId);

        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }

        uint256 effectivePercentageBPS;

        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][msg.sender];
        if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
            effectivePercentageBPS = vaultPerm.percentageBPS;
        } else {
            WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][msg.sender];
            if (!walletPerm.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
                revert NotActiveDelegate(tokenId, msg.sender);
            }
            effectivePercentageBPS = walletPerm.percentageBPS;
        }

        uint256 delegateLastWithdrawal = delegateVaultCooldown[msg.sender][tokenId];
        if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
            revert WithdrawalPeriodNotMet(tokenId, msg.sender);
        }

        uint256 currentPrimary = _primaryAmount[tokenId];
        uint256 totalPool = VaultMath.calculateWithdrawal(currentPrimary);
        withdrawnAmount = (totalPool * effectivePercentageBPS) / FULL_BPS;

        if (withdrawnAmount == 0) return 0;

        _primaryAmount[tokenId] = currentPrimary - withdrawnAmount;
        delegateVaultCooldown[msg.sender][tokenId] = block.timestamp;
        _updateActivity(tokenId);

        IERC20(primaryToken).safeTransfer(msg.sender, withdrawnAmount);

        emit DelegatedWithdrawal(tokenId, msg.sender, vaultOwner, withdrawnAmount);

        return withdrawnAmount;
    }

    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount, DelegationType delegationType)
    {
        address vaultOwner;
        try this.ownerOf(tokenId) returns (address owner_) {
            vaultOwner = owner_;
        } catch {
            return (false, 0, DelegationType.None);
        }

        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return (false, 0, DelegationType.None);
        }

        uint256 effectivePercentageBPS;
        DelegationType dtype;

        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];
        if (vaultPerm.active && (vaultPerm.expiresAt == 0 || vaultPerm.expiresAt > block.timestamp)) {
            effectivePercentageBPS = vaultPerm.percentageBPS;
            dtype = DelegationType.VaultSpecific;
        } else {
            WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
            if (!walletPerm.active || walletTotalDelegatedBPS[vaultOwner] == 0) {
                return (false, 0, DelegationType.None);
            }
            effectivePercentageBPS = walletPerm.percentageBPS;
            dtype = DelegationType.WalletLevel;
        }

        uint256 delegateLastWithdrawal = delegateVaultCooldown[delegate][tokenId];
        if (delegateLastWithdrawal > 0 && !VaultMath.canWithdraw(delegateLastWithdrawal, block.timestamp)) {
            return (false, 0, dtype);
        }

        uint256 currentPrimary = _primaryAmount[tokenId];
        uint256 totalPool = VaultMath.calculateWithdrawal(currentPrimary);
        amount = (totalPool * effectivePercentageBPS) / FULL_BPS;

        return (amount > 0, amount, dtype);
    }

    // ========== View Functions ==========

    function primaryAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _primaryAmount[tokenId];
    }

    function secondaryAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _secondaryAmount[tokenId];
    }

    function isVested(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp);
    }

    function secondaryWithdrawn(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return _secondaryWithdrawn[tokenId];
    }

    function treasureContract(uint256 tokenId) external view returns (address) {
        _requireOwned(tokenId);
        return _treasureContract[tokenId];
    }

    function treasureTokenId(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _treasureTokenId[tokenId];
    }

    function mintTimestamp(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _mintTimestamp[tokenId];
    }

    function lastPrimaryWithdrawal(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _lastPrimaryWithdrawal[tokenId];
    }

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract_,
            uint256 treasureTokenId_,
            uint256 primaryAmount_,
            uint256 secondaryAmount_,
            uint256 mintTimestamp_,
            uint256 lastPrimaryWithdrawal_,
            bool secondaryWithdrawn_,
            uint256 btcTokenAmount_
        )
    {
        _requireOwned(tokenId);
        return (
            _treasureContract[tokenId],
            _treasureTokenId[tokenId],
            _primaryAmount[tokenId],
            _secondaryAmount[tokenId],
            _mintTimestamp[tokenId],
            _lastPrimaryWithdrawal[tokenId],
            _secondaryWithdrawn[tokenId],
            _btcTokenAmount[tokenId]
        );
    }

    function getWithdrawablePrimary(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return 0;
        }
        if (!VaultMath.canWithdraw(_lastPrimaryWithdrawal[tokenId], block.timestamp)) {
            return 0;
        }
        return VaultMath.calculateWithdrawal(_primaryAmount[tokenId]);
    }

    function getWithdrawableSecondary(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return 0;
        }
        if (_secondaryWithdrawn[tokenId]) {
            return 0;
        }
        return _secondaryAmount[tokenId];
    }

    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory)
    {
        return walletDelegates[owner][delegate];
    }

    function getVaultDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (VaultDelegatePermission memory)
    {
        return vaultDelegates[tokenId][delegate];
    }

    function getEffectiveDelegation(uint256 tokenId, address delegate)
        external
        view
        returns (uint256 percentageBPS, DelegationType dtype, bool isExpired)
    {
        VaultDelegatePermission storage vaultPerm = vaultDelegates[tokenId][delegate];

        if (vaultPerm.active) {
            bool expired = vaultPerm.expiresAt > 0 && block.timestamp > vaultPerm.expiresAt;
            return (vaultPerm.percentageBPS, DelegationType.VaultSpecific, expired);
        }

        address vaultOwner;
        try this.ownerOf(tokenId) returns (address owner_) {
            vaultOwner = owner_;
        } catch {
            return (0, DelegationType.None, false);
        }

        WalletDelegatePermission storage walletPerm = walletDelegates[vaultOwner][delegate];
        if (walletPerm.active && walletTotalDelegatedBPS[vaultOwner] > 0) {
            return (walletPerm.percentageBPS, DelegationType.WalletLevel, false);
        }

        return (0, DelegationType.None, false);
    }

    function getDelegateCooldown(address delegate, uint256 tokenId) external view returns (uint256) {
        return delegateVaultCooldown[delegate][tokenId];
    }

    // ========== Internal Functions ==========

    function _updateActivity(uint256 tokenId) internal {
        _lastActivity[tokenId] = block.timestamp;
        if (_pokeTimestamp[tokenId] != 0) {
            _pokeTimestamp[tokenId] = 0;
            emit DormancyStateChanged(tokenId, DormancyState.ACTIVE);
        }
    }

    function _clearVaultState(uint256 tokenId) internal {
        delete _treasureContract[tokenId];
        delete _treasureTokenId[tokenId];
        delete _primaryAmount[tokenId];
        delete _secondaryAmount[tokenId];
        delete _mintTimestamp[tokenId];
        delete _lastPrimaryWithdrawal[tokenId];
        delete _secondaryWithdrawn[tokenId];
        delete _lastActivity[tokenId];
        delete _btcTokenAmount[tokenId];
        delete _originalMintedAmount[tokenId];
        delete _pokeTimestamp[tokenId];
        delete primaryMatured[tokenId];
        delete secondaryMatured[tokenId];
        delete primaryMatchClaimed[tokenId];
        delete secondaryMatchClaimed[tokenId];
    }

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = super._update(to, tokenId, auth);
        if (from != address(0) && to != address(0)) {
            _updateActivity(tokenId);
        }
        return from;
    }
}
