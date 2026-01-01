// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IdentityVerifier, IENS, IIdRegistry} from "../../../src/verifiers/IdentityVerifier.sol";

contract MockENS is IENS {
    mapping(address => bytes32) public nodes;

    function setNode(address addr, bytes32 nodeHash) external {
        nodes[addr] = nodeHash;
    }

    function node(address addr) external view returns (bytes32) {
        return nodes[addr];
    }

    function name(bytes32) external pure returns (string memory) {
        return "test.eth";
    }
}

contract MockFarcaster is IIdRegistry {
    mapping(address => uint256) public fids;

    function setFid(address addr, uint256 fid) external {
        fids[addr] = fid;
    }

    function idOf(address owner) external view returns (uint256) {
        return fids[owner];
    }
}

contract RevertingMock {
    function node(address) external pure returns (bytes32) {
        revert("Always reverts");
    }
}

contract RevertingFarcasterMock {
    function idOf(address) external pure returns (uint256) {
        revert("Always reverts");
    }
}

contract IdentityVerifierTest is Test {
    IdentityVerifier public verifier;
    MockENS public mockENS;
    MockFarcaster public mockFarcaster;

    address public owner = address(this);
    address public user = address(0xBEEF);

    function setUp() public {
        verifier = new IdentityVerifier();
        mockENS = new MockENS();
        mockFarcaster = new MockFarcaster();

        verifier.setENSReverseRegistrar(address(mockENS));
        verifier.setFarcasterIdRegistry(address(mockFarcaster));
    }

    function test_Verify_ReturnsFalse_WhenNoIdentity() public view {
        bool result = verifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_Verify_ReturnsTrue_WhenHasENS() public {
        mockENS.setNode(user, bytes32(uint256(1)));

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_ReturnsTrue_WhenHasFarcaster() public {
        mockFarcaster.setFid(user, 12345);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_ReturnsTrue_WhenHasBoth() public {
        mockENS.setNode(user, bytes32(uint256(1)));
        mockFarcaster.setFid(user, 12345);

        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_ReturnsFalse_WhenRegistrarsNotSet() public {
        IdentityVerifier freshVerifier = new IdentityVerifier();

        bool result = freshVerifier.verify(user, bytes32(0), "");
        assertFalse(result);
    }

    function test_SetENSReverseRegistrar_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setENSReverseRegistrar(address(0x1234));
    }

    function test_SetFarcasterIdRegistry_OnlyOwner() public {
        vm.prank(user);
        vm.expectRevert();
        verifier.setFarcasterIdRegistry(address(0x1234));
    }

    function test_Verify_HandlesFarcasterReverts() public {
        // Deploy a mock that always reverts
        RevertingFarcasterMock revertingMock = new RevertingFarcasterMock();
        verifier.setFarcasterIdRegistry(address(revertingMock));
        // ENS is still configured
        mockENS.setNode(user, bytes32(uint256(1)));

        // Should still return true via ENS check
        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }

    function test_Verify_HandlesENSReverts() public {
        // Deploy a mock that always reverts
        RevertingMock revertingMock = new RevertingMock();
        verifier.setENSReverseRegistrar(address(revertingMock));
        // Farcaster is still configured
        mockFarcaster.setFid(user, 12345);

        // Should still return true via Farcaster check
        bool result = verifier.verify(user, bytes32(0), "");
        assertTrue(result);
    }
}
