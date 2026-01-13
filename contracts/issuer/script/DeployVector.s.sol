// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockCurvePool} from "../test/mocks/MockCurvePool.sol";
import {MockVarianceOracle} from "../test/mocks/MockVarianceOracle.sol";
import {PerpetualVault} from "../src/perpetual/PerpetualVault.sol";
import {VolatilityPool} from "../src/volatility/VolatilityPool.sol";

/// @title DeployVector
/// @notice Deploys all contracts required for the Vector app
/// @dev Run with: forge script script/DeployVector.s.sol --rpc-url http://localhost:8545 --broadcast
contract DeployVector is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80));

        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock tokens
        MockERC20 vBTC = new MockERC20("vestedBTC", "vBTC", 8);
        MockERC20 cbBTC = new MockERC20("Coinbase Wrapped BTC", "cbBTC", 8);

        console.log("vBTC deployed at:", address(vBTC));
        console.log("cbBTC deployed at:", address(cbBTC));

        // Deploy Curve mock pool
        MockCurvePool curvePool = new MockCurvePool(address(cbBTC), address(vBTC));
        console.log("Curve Pool deployed at:", address(curvePool));

        // Set initial price oracle (15% discount)
        curvePool.setPriceOracle(0.85e18);
        curvePool.setLastPrice(0.85e18);

        // Deploy PerpetualVault
        PerpetualVault perpetualVault = new PerpetualVault(
            address(vBTC),
            address(curvePool)
        );
        console.log("PerpetualVault deployed at:", address(perpetualVault));

        // Deploy MockVarianceOracle for VolatilityPool
        MockVarianceOracle varianceOracle = new MockVarianceOracle();
        console.log("VarianceOracle deployed at:", address(varianceOracle));

        // Deploy VolatilityPool
        // strikeVariance: 4% annualized (4e16)
        // settlementInterval: 1 day
        // varianceWindow: 7 days
        // minDeposit: 0.01 vBTC (1e6 with 8 decimals)
        VolatilityPool volatilityPool = new VolatilityPool(
            address(vBTC),
            address(varianceOracle),
            4e16,        // strikeVariance
            1 days,      // settlementInterval
            7 days,      // varianceWindow
            1e6          // minDeposit (0.01 vBTC)
        );
        console.log("VolatilityPool deployed at:", address(volatilityPool));

        // Deploy a simple ERC-4626 mock yield vault
        MockYieldVault yieldVault = new MockYieldVault(address(vBTC));
        console.log("YieldVault deployed at:", address(yieldVault));

        // Mint some test tokens to deployer
        address deployer = vm.addr(deployerPrivateKey);
        vBTC.mint(deployer, 100e8); // 100 vBTC
        cbBTC.mint(deployer, 100e8); // 100 cbBTC
        console.log("Minted 100 vBTC and 100 cbBTC to deployer:", deployer);

        // Seed Curve pool with liquidity
        vBTC.mint(address(curvePool), 1000e8);
        cbBTC.mint(address(curvePool), 1000e8);
        curvePool.setBalances(1000e8, 1000e8);
        console.log("Seeded Curve pool with 1000 vBTC and 1000 cbBTC");

        vm.stopBroadcast();

        // Output for .env.local
        console.log("\n=== Copy to apps/vector/.env.local ===");
        console.log("NEXT_PUBLIC_VBTC_ANVIL=", address(vBTC));
        console.log("NEXT_PUBLIC_CBBTC_ANVIL=", address(cbBTC));
        console.log("NEXT_PUBLIC_CURVE_POOL_ANVIL=", address(curvePool));
        console.log("NEXT_PUBLIC_PERPETUAL_VAULT_ANVIL=", address(perpetualVault));
        console.log("NEXT_PUBLIC_YIELD_VAULT_ANVIL=", address(yieldVault));
        console.log("NEXT_PUBLIC_VOLATILITY_POOL_ANVIL=", address(volatilityPool));
    }
}

/// @notice Simple ERC-4626 mock yield vault for testing
contract MockYieldVault {
    address public immutable asset;
    string public constant name = "Yield vestedBTC";
    string public constant symbol = "yvBTC";
    uint8 public constant decimals = 8;

    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    uint256 public totalAssets;

    constructor(address _asset) {
        asset = _asset;
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        MockERC20(asset).transferFrom(msg.sender, address(this), assets);
        shares = convertToShares(assets);
        balanceOf[receiver] += shares;
        totalSupply += shares;
        totalAssets += assets;
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        shares = convertToShares(assets);
        require(balanceOf[owner] >= shares, "Insufficient balance");
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        MockERC20(asset).transfer(receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        require(balanceOf[owner] >= shares, "Insufficient balance");
        assets = convertToAssets(shares);
        balanceOf[owner] -= shares;
        totalSupply -= shares;
        totalAssets -= assets;
        MockERC20(asset).transfer(receiver, assets);
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        if (totalSupply == 0) return assets;
        return (assets * totalSupply) / totalAssets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        if (totalSupply == 0) return shares;
        return (shares * totalAssets) / totalSupply;
    }

    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function previewDeposit(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewWithdraw(uint256 assets) external view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) external view returns (uint256) {
        return convertToAssets(shares);
    }
}
