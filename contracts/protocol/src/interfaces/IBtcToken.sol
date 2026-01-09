// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBtcToken is IERC20 {
    error ZeroAddress();

    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
}
