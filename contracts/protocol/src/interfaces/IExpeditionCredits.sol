// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IExpeditionCredits is IERC20 {
    error OnlyVault();
    error OnlyAdmin();
    error ZeroAddress();
    error BootstrapEnded();
    error RecipientNotWhitelisted(address recipient);
    error SenderNotWhitelisted(address sender);

    event Whitelisted(address indexed account);
    event RemovedFromWhitelist(address indexed account);

    function mint(address to, uint256 amount) external;
    function addToWhitelist(address account) external;
    function removeFromWhitelist(address account) external;
    function isWhitelisted(address account) external view returns (bool);
    function bootstrapEnd() external view returns (uint256);
}
