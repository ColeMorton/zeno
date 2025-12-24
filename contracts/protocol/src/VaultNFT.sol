// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IVaultNFT} from "./interfaces/IVaultNFT.sol";
import {IBtcToken} from "./interfaces/IBtcToken.sol";
import {VaultMath} from "./libraries/VaultMath.sol";

contract VaultNFT is ERC721, IVaultNFT {
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId;

    IBtcToken public immutable btcToken;
    mapping(address => bool) public acceptedCollateralTokens;

    mapping(uint256 => address) private _treasureContract;
    mapping(uint256 => uint256) private _treasureTokenId;
    mapping(uint256 => address) private _collateralToken;
    mapping(uint256 => uint256) private _collateralAmount;
    mapping(uint256 => uint256) private _mintTimestamp;
    mapping(uint256 => uint256) private _lastWithdrawal;
    mapping(uint256 => uint256) private _lastActivity;
    mapping(uint256 => uint256) private _btcTokenAmount;
    mapping(uint256 => uint256) private _originalMintedAmount;
    mapping(uint256 => uint256) private _pokeTimestamp;

    // Withdrawal delegation
    mapping(uint256 => mapping(address => DelegatePermission)) public withdrawalDelegates;
    mapping(uint256 => uint256) public totalDelegatedBPS;
    mapping(uint256 => uint256) public currentPeriodWithdrawn; // Track withdrawals in current period
    mapping(uint256 => uint256) public lastPeriodStart; // When current period started

    uint256 public matchPool;
    uint256 public totalActiveCollateral;
    mapping(uint256 => bool) public matured;
    mapping(uint256 => bool) public matchClaimed;
    uint256 private _snapshotDenominator;

    constructor(
        address _btcToken,
        address[] memory _acceptedTokens
    ) ERC721("Vault NFT", "VAULT") {
        btcToken = IBtcToken(_btcToken);
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            acceptedCollateralTokens[_acceptedTokens[i]] = true;
        }
    }

    function mint(
        address treasureContract_,
        uint256 treasureTokenId_,
        address collateralToken_,
        uint256 collateralAmount_
    ) external returns (uint256 tokenId) {
        if (!acceptedCollateralTokens[collateralToken_]) {
            revert InvalidCollateralToken(collateralToken_);
        }
        if (collateralAmount_ == 0) revert ZeroCollateral();

        IERC721(treasureContract_).transferFrom(msg.sender, address(this), treasureTokenId_);
        IERC20(collateralToken_).safeTransferFrom(msg.sender, address(this), collateralAmount_);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        _treasureContract[tokenId] = treasureContract_;
        _treasureTokenId[tokenId] = treasureTokenId_;
        _collateralToken[tokenId] = collateralToken_;
        _collateralAmount[tokenId] = collateralAmount_;
        _mintTimestamp[tokenId] = block.timestamp;
        _lastActivity[tokenId] = block.timestamp;

        totalActiveCollateral += collateralAmount_;

        emit VaultMinted(
            tokenId,
            msg.sender,
            treasureContract_,
            treasureTokenId_,
            collateralAmount_
        );
    }

    function withdraw(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (!VaultMath.canWithdraw(_lastWithdrawal[tokenId], block.timestamp)) {
            revert WithdrawalTooSoon(tokenId, _lastWithdrawal[tokenId] + VaultMath.WITHDRAWAL_PERIOD);
        }

        amount = VaultMath.calculateWithdrawal(_collateralAmount[tokenId]);
        if (amount == 0) return 0;

        _collateralAmount[tokenId] -= amount;
        _lastWithdrawal[tokenId] = block.timestamp;
        _updateActivity(tokenId);

        IERC20(_collateralToken[tokenId]).safeTransfer(msg.sender, amount);

        emit Withdrawn(tokenId, msg.sender, amount);
    }

    function earlyRedeem(uint256 tokenId) external returns (uint256 returned, uint256 forfeited) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

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

        uint256 collateral = _collateralAmount[tokenId];
        (returned, forfeited) = VaultMath.calculateEarlyRedemption(
            collateral,
            _mintTimestamp[tokenId],
            block.timestamp
        );

        if (forfeited > 0) {
            _snapshotDenominator = totalActiveCollateral;
            matchPool += forfeited;
            emit MatchPoolFunded(forfeited, matchPool);
        }

        if (!matured[tokenId]) {
            totalActiveCollateral -= collateral;
        }

        address treasureContract_ = _treasureContract[tokenId];
        uint256 treasureTokenId_ = _treasureTokenId[tokenId];
        address collateralToken_ = _collateralToken[tokenId];

        IERC721(treasureContract_).transferFrom(address(this), address(0xdead), treasureTokenId_);

        _clearVaultState(tokenId);
        _burn(tokenId);

        if (returned > 0) {
            IERC20(collateralToken_).safeTransfer(msg.sender, returned);
        }

        emit EarlyRedemption(tokenId, msg.sender, returned, forfeited);
    }

    function mintBtcToken(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }
        if (_btcTokenAmount[tokenId] > 0) {
            revert BtcTokenAlreadyMinted(tokenId);
        }

        amount = _collateralAmount[tokenId];
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

    function claimMatch(uint256 tokenId) external returns (uint256 amount) {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert NotVested(tokenId);
        }
        if (matchClaimed[tokenId]) revert AlreadyClaimed(tokenId);
        if (matchPool == 0) revert NoPoolAvailable();

        if (!matured[tokenId]) {
            totalActiveCollateral -= _collateralAmount[tokenId];
            matured[tokenId] = true;
        }

        uint256 denominator = _snapshotDenominator > 0 ? _snapshotDenominator : totalActiveCollateral;
        if (denominator == 0) revert NoPoolAvailable();

        amount = VaultMath.calculateMatchShare(matchPool, _collateralAmount[tokenId], denominator);
        if (amount == 0) revert NoPoolAvailable();

        matchClaimed[tokenId] = true;
        matchPool -= amount;
        _collateralAmount[tokenId] += amount;
        _updateActivity(tokenId);

        emit MatchClaimed(tokenId, amount);
    }

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

    function claimDormantCollateral(uint256 tokenId) external returns (uint256 collateral) {
        _requireOwned(tokenId);
        (, DormancyState state) = isDormantEligible(tokenId);
        if (state != DormancyState.CLAIMABLE) revert NotClaimable(tokenId);

        uint256 required = _originalMintedAmount[tokenId];
        uint256 available = btcToken.balanceOf(msg.sender);
        if (available < required) {
            revert InsufficientBtcToken(required, available);
        }

        address originalOwner = ownerOf(tokenId);
        collateral = _collateralAmount[tokenId];
        address treasureContract_ = _treasureContract[tokenId];
        uint256 treasureTokenId_ = _treasureTokenId[tokenId];
        address collateralToken_ = _collateralToken[tokenId];

        btcToken.burnFrom(msg.sender, required);

        _clearVaultState(tokenId);
        _burn(tokenId);

        IERC721(treasureContract_).transferFrom(address(this), address(0xdead), treasureTokenId_);
        IERC20(collateralToken_).safeTransfer(msg.sender, collateral);

        emit DormantCollateralClaimed(tokenId, originalOwner, msg.sender, collateral);
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

    function getVaultInfo(uint256 tokenId)
        external
        view
        returns (
            address treasureContract_,
            uint256 treasureTokenId_,
            address collateralToken_,
            uint256 collateralAmount_,
            uint256 mintTimestamp_,
            uint256 lastWithdrawal_,
            uint256 lastActivity_,
            uint256 btcTokenAmount_,
            uint256 originalMintedAmount_
        )
    {
        _requireOwned(tokenId);
        return (
            _treasureContract[tokenId],
            _treasureTokenId[tokenId],
            _collateralToken[tokenId],
            _collateralAmount[tokenId],
            _mintTimestamp[tokenId],
            _lastWithdrawal[tokenId],
            _lastActivity[tokenId],
            _btcTokenAmount[tokenId],
            _originalMintedAmount[tokenId]
        );
    }

    function isVested(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId);
        return VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp);
    }

    function getWithdrawableAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return 0;
        }
        if (!VaultMath.canWithdraw(_lastWithdrawal[tokenId], block.timestamp)) {
            return 0;
        }
        return VaultMath.calculateWithdrawal(_collateralAmount[tokenId]);
    }

    function treasureContract(uint256 tokenId) external view returns (address) {
        _requireOwned(tokenId);
        return _treasureContract[tokenId];
    }

    function treasureTokenId(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _treasureTokenId[tokenId];
    }

    function collateralToken(uint256 tokenId) external view returns (address) {
        _requireOwned(tokenId);
        return _collateralToken[tokenId];
    }

    function collateralAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _collateralAmount[tokenId];
    }

    function mintTimestamp(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _mintTimestamp[tokenId];
    }

    function lastWithdrawal(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _lastWithdrawal[tokenId];
    }

    function lastActivity(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _lastActivity[tokenId];
    }

    function btcTokenAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _btcTokenAmount[tokenId];
    }

    function originalMintedAmount(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _originalMintedAmount[tokenId];
    }

    function pokeTimestamp(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        return _pokeTimestamp[tokenId];
    }

    function getCollateralClaim(uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        if (_btcTokenAmount[tokenId] == 0) return 0;
        return _collateralAmount[tokenId];
    }

    function getClaimValue(address holder, uint256 tokenId) external view returns (uint256) {
        _requireOwned(tokenId);
        uint256 holderBalance = btcToken.balanceOf(holder);
        uint256 originalAmount = _originalMintedAmount[tokenId];
        if (originalAmount == 0 || holderBalance == 0) return 0;

        uint256 currentCollateral = _collateralAmount[tokenId];
        return (currentCollateral * holderBalance) / originalAmount;
    }

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
        delete _collateralToken[tokenId];
        delete _collateralAmount[tokenId];
        delete _mintTimestamp[tokenId];
        delete _lastWithdrawal[tokenId];
        delete _lastActivity[tokenId];
        delete _btcTokenAmount[tokenId];
        delete _originalMintedAmount[tokenId];
        delete _pokeTimestamp[tokenId];
        delete matured[tokenId];
        delete matchClaimed[tokenId];
    }

    // ========== Withdrawal Delegation Functions ==========

    function grantWithdrawalDelegate(
        uint256 tokenId,
        address delegate,
        uint256 percentageBPS
    ) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);
        if (delegate == address(0)) revert ZeroAddress();
        if (delegate == msg.sender) revert CannotDelegateSelf();
        if (percentageBPS == 0 || percentageBPS > 10000) revert InvalidPercentage(percentageBPS);

        // Check total delegation doesn't exceed 100%
        uint256 currentDelegated = totalDelegatedBPS[tokenId];
        if (withdrawalDelegates[tokenId][delegate].active) {
            currentDelegated -= withdrawalDelegates[tokenId][delegate].percentageBPS;
        }
        if (currentDelegated + percentageBPS > 10000) revert ExceedsDelegationLimit();

        // Update state
        withdrawalDelegates[tokenId][delegate] = DelegatePermission({
            percentageBPS: percentageBPS,
            lastWithdrawal: 0,
            grantedAt: block.timestamp,
            active: true
        });

        totalDelegatedBPS[tokenId] = currentDelegated + percentageBPS;

        // Update activity
        _updateActivity(tokenId);

        emit WithdrawalDelegateGranted(tokenId, delegate, percentageBPS);
    }

    function revokeWithdrawalDelegate(uint256 tokenId, address delegate) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        DelegatePermission storage permission = withdrawalDelegates[tokenId][delegate];
        if (!permission.active) revert DelegateNotActive(tokenId, delegate);

        // Update state
        totalDelegatedBPS[tokenId] -= permission.percentageBPS;
        permission.active = false;

        // Update activity
        _updateActivity(tokenId);

        emit WithdrawalDelegateRevoked(tokenId, delegate);
    }

    function revokeAllWithdrawalDelegates(uint256 tokenId) external {
        _requireOwned(tokenId);
        if (ownerOf(tokenId) != msg.sender) revert NotTokenOwner(tokenId);

        // Reset total delegation
        totalDelegatedBPS[tokenId] = 0;

        // Note: Individual delegate mappings are not cleared to save gas
        // The totalDelegatedBPS reset effectively disables all delegations
        // Future grant calls will overwrite old inactive entries

        // Update activity
        _updateActivity(tokenId);

        emit AllWithdrawalDelegatesRevoked(tokenId);
    }

    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
        _requireOwned(tokenId);
        
        // Check vesting complete
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            revert StillVesting(tokenId);
        }

        // Check delegation
        DelegatePermission storage permission = withdrawalDelegates[tokenId][msg.sender];
        if (!permission.active || totalDelegatedBPS[tokenId] == 0) revert NotActiveDelegate(tokenId, msg.sender);

        // Check withdrawal period (30 days for delegate)
        if (permission.lastWithdrawal > 0 && 
            !VaultMath.canWithdraw(permission.lastWithdrawal, block.timestamp)) {
            revert WithdrawalPeriodNotMet(tokenId, msg.sender);
        }

        // Calculate delegate's withdrawal amount from the total pool
        // The pool should be calculated from the collateral at the beginning of the period
        uint256 currentCollateral = _collateralAmount[tokenId];
        uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
        withdrawnAmount = (totalPool * permission.percentageBPS) / 10000;

        if (withdrawnAmount == 0) return 0;

        // Update state BEFORE transfer
        _collateralAmount[tokenId] = currentCollateral - withdrawnAmount;
        permission.lastWithdrawal = block.timestamp;

        // Update activity
        _updateActivity(tokenId);

        // Transfer to delegate
        IERC20(_collateralToken[tokenId]).safeTransfer(msg.sender, withdrawnAmount);

        emit DelegatedWithdrawal(tokenId, msg.sender, withdrawnAmount);

        return withdrawnAmount;
    }

    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount)
    {
        try this.ownerOf(tokenId) {
            // Token exists
        } catch {
            return (false, 0);
        }
        
        // Check vesting
        if (!VaultMath.isVested(_mintTimestamp[tokenId], block.timestamp)) {
            return (false, 0);
        }

        DelegatePermission storage permission = withdrawalDelegates[tokenId][delegate];
        if (!permission.active || totalDelegatedBPS[tokenId] == 0) {
            return (false, 0);
        }

        // Check withdrawal period
        if (permission.lastWithdrawal > 0 && 
            !VaultMath.canWithdraw(permission.lastWithdrawal, block.timestamp)) {
            return (false, 0);
        }

        // Calculate available amount
        uint256 currentCollateral = _collateralAmount[tokenId];
        uint256 totalPool = VaultMath.calculateWithdrawal(currentCollateral);
        amount = (totalPool * permission.percentageBPS) / 10000;

        return (amount > 0, amount);
    }

    function getDelegatePermission(uint256 tokenId, address delegate)
        external
        view
        returns (DelegatePermission memory)
    {
        _requireOwned(tokenId);
        return withdrawalDelegates[tokenId][delegate];
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
