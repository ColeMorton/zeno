// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IBtcToken} from "./interfaces/IBtcToken.sol";

contract BtcToken is ERC20, IBtcToken {
    address public immutable vault;

    error OnlyVault();

    modifier onlyVault() {
        if (msg.sender != vault) revert OnlyVault();
        _;
    }

    constructor(
        address _vault,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        vault = _vault;
    }

    function mint(address to, uint256 amount) external onlyVault {
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external onlyVault {
        _burn(from, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
