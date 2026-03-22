// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IExpeditionCredits} from "./interfaces/IExpeditionCredits.sol";
import {VaultMath} from "./libraries/VaultMath.sol";

/// @title ExpeditionCredits (xBTC)
/// @notice Bootstrap-phase minting reward token enabling DeFi participation before vestedBTC exists.
/// @dev Minted 1:1 with collateral at vault creation during Bootstrap (days 0-1128).
///      Transfers restricted to whitelisted protocol contracts and EOA wallets.
contract ExpeditionCredits is ERC20, IExpeditionCredits {
    address public immutable vault;
    address public immutable admin;
    uint256 public immutable bootstrapEnd;

    mapping(address => bool) private _whitelisted;

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    constructor(
        address _vault,
        address _admin
    ) ERC20("Expedition Credits", "xBTC") {
        if (_vault == address(0)) revert ZeroAddress();
        if (_admin == address(0)) revert ZeroAddress();
        vault = _vault;
        admin = _admin;
        bootstrapEnd = block.timestamp + VaultMath.VESTING_PERIOD;
    }

    function mint(address to, uint256 amount) external onlyVault {
        if (block.timestamp > bootstrapEnd) revert BootstrapEnded();
        _mint(to, amount);
    }

    function addToWhitelist(address account) external onlyAdmin {
        if (account == address(0)) revert ZeroAddress();
        _whitelisted[account] = true;
        emit Whitelisted(account);
    }

    function removeFromWhitelist(address account) external onlyAdmin {
        _whitelisted[account] = false;
        emit RemovedFromWhitelist(account);
    }

    function isWhitelisted(address account) external view returns (bool) {
        return _whitelisted[account];
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }

    /// @dev Restricts transfers: contract addresses must be whitelisted. EOA-to-EOA always allowed.
    function _update(address from, address to, uint256 value) internal override {
        if (from != address(0) && to != address(0)) {
            if (to.code.length > 0 && !_whitelisted[to]) {
                revert RecipientNotWhitelisted(to);
            }
            if (from.code.length > 0 && !_whitelisted[from]) {
                revert SenderNotWhitelisted(from);
            }
        }
        super._update(from, to, value);
    }
}
