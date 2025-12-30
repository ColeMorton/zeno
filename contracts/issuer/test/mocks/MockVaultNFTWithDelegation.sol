// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Mock VaultNFT with wallet-level delegation for testing SablierStreamWrapper
contract MockVaultNFTWithDelegation is ERC721 {
    using SafeERC20 for IERC20;

    uint256 private _nextTokenId;
    address public collateralToken;

    struct WalletDelegatePermission {
        uint256 percentageBPS;
        uint256 grantedAt;
        bool active;
    }

    // vault tokenId => collateral amount
    mapping(uint256 => uint256) public collateralAmounts;

    // vault tokenId => mint timestamp
    mapping(uint256 => uint256) public mintTimestamps;

    // owner => delegate => permission
    mapping(address => mapping(address => WalletDelegatePermission)) public walletDelegates;

    // delegate => tokenId => last withdrawal timestamp
    mapping(address => mapping(uint256 => uint256)) public delegateCooldowns;

    // Test control flags
    mapping(uint256 => bool) private _isVested;
    mapping(uint256 => bool) private _canWithdraw;
    mapping(uint256 => uint256) private _withdrawableAmount;

    uint256 public constant WITHDRAWAL_PERIOD = 30 days;
    uint256 public constant BASIS_POINTS = 10000;

    constructor(address _collateralToken) ERC721("Mock Vault", "MVAULT") {
        collateralToken = _collateralToken;
    }

    function mint(uint256 collateralAmount) external returns (uint256 tokenId) {
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), collateralAmount);

        tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);

        collateralAmounts[tokenId] = collateralAmount;
        mintTimestamps[tokenId] = block.timestamp;
    }

    function grantWithdrawalDelegate(address delegate, uint256 percentageBPS) external {
        walletDelegates[msg.sender][delegate] = WalletDelegatePermission({
            percentageBPS: percentageBPS,
            grantedAt: block.timestamp,
            active: true
        });
    }

    function revokeWithdrawalDelegate(address delegate) external {
        walletDelegates[msg.sender][delegate].active = false;
    }

    function canDelegateWithdraw(uint256 tokenId, address delegate)
        external
        view
        returns (bool canWithdraw, uint256 amount)
    {
        address owner = ownerOf(tokenId);
        WalletDelegatePermission storage perm = walletDelegates[owner][delegate];

        if (!perm.active) {
            return (false, 0);
        }

        // Check if we're in test mode with specific values
        if (_withdrawableAmount[tokenId] > 0) {
            uint256 delegateAmount = (_withdrawableAmount[tokenId] * perm.percentageBPS) / BASIS_POINTS;
            return (_canWithdraw[tokenId], delegateAmount);
        }

        // Check vesting
        if (!_isVested[tokenId]) {
            return (false, 0);
        }

        // Check cooldown
        uint256 lastWithdrawal = delegateCooldowns[delegate][tokenId];
        if (lastWithdrawal > 0 && block.timestamp < lastWithdrawal + WITHDRAWAL_PERIOD) {
            return (false, 0);
        }

        // Calculate 1% of collateral
        uint256 monthlyAmount = collateralAmounts[tokenId] / 100;
        uint256 delegateAmount = (monthlyAmount * perm.percentageBPS) / BASIS_POINTS;

        return (true, delegateAmount);
    }

    function withdrawAsDelegate(uint256 tokenId) external returns (uint256 withdrawnAmount) {
        address owner = ownerOf(tokenId);
        WalletDelegatePermission storage perm = walletDelegates[owner][msg.sender];

        require(perm.active, "Not active delegate");

        // Calculate withdrawal amount
        uint256 monthlyAmount;
        if (_withdrawableAmount[tokenId] > 0) {
            monthlyAmount = _withdrawableAmount[tokenId];
        } else {
            monthlyAmount = collateralAmounts[tokenId] / 100;
        }

        withdrawnAmount = (monthlyAmount * perm.percentageBPS) / BASIS_POINTS;
        require(withdrawnAmount > 0, "Nothing to withdraw");

        // Update state
        collateralAmounts[tokenId] -= withdrawnAmount;
        delegateCooldowns[msg.sender][tokenId] = block.timestamp;

        // Transfer collateral
        IERC20(collateralToken).safeTransfer(msg.sender, withdrawnAmount);
    }

    function getWalletDelegatePermission(address owner, address delegate)
        external
        view
        returns (WalletDelegatePermission memory)
    {
        return walletDelegates[owner][delegate];
    }

    function getDelegateCooldown(address delegate, uint256 tokenId)
        external
        view
        returns (uint256)
    {
        return delegateCooldowns[delegate][tokenId];
    }

    // Test helpers

    function setVested(uint256 tokenId, bool vested) external {
        _isVested[tokenId] = vested;
    }

    function setCanWithdraw(uint256 tokenId, bool canWithdraw, uint256 amount) external {
        _canWithdraw[tokenId] = canWithdraw;
        _withdrawableAmount[tokenId] = amount;
    }

    function setCollateralAmount(uint256 tokenId, uint256 amount) external {
        collateralAmounts[tokenId] = amount;
    }

    function fundContract(uint256 amount) external {
        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    function totalSupply() external view returns (uint256) {
        return _nextTokenId;
    }
}
