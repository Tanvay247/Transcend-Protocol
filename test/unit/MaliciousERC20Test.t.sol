// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockHeaderVerifier.sol";
import "../mocks/MaliciousERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title MaliciousERC20Test
 * @notice Precise unit tests for adversarial ERC20 behaviors.
 */
contract MaliciousERC20Test is Test {
    TranscendCore core;
    MockHeaderVerifier verifier;
    MaliciousERC20 token;

    address treasury;
    address solver;
    address user;
    uint256 userPK = 0xA11CE;

    uint256 constant FLAT_FEE = 1 ether;

    function setUp() public {
        treasury = makeAddr("treasury");
        solver = makeAddr("solver");
        user = vm.addr(userPK);

        verifier = new MockHeaderVerifier();
        core = new TranscendCore(FLAT_FEE, 30, treasury);
        token = new MaliciousERC20();

        core.registerHeaderVerifier(1, address(verifier));
        token.mint(user, 100 ether);

        vm.prank(user);
        token.approve(address(core), type(uint256).max);
        vm.deal(solver, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildIntent(uint256 amount) internal view returns (TranscendCore.Intent memory intent, bytes32 structHash) {
        intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: block.chainid,
            destinationChainId: 1,
            inputAsset: address(token),
            outputAsset: address(999),
            inputAmount: amount,
            minOutputAmount: 5 ether,
            recipient: user,
            maxFee: 2 ether,
            expiry: block.timestamp + 1 hours,
            nonce: 1,
            routeHash: keccak256("route")
        });

        structHash = keccak256(abi.encode(
            core.INTENT_TYPEHASH(),
            intent.version,
            intent.user,
            intent.originChainId,
            intent.destinationChainId,
            intent.inputAsset,
            intent.outputAsset,
            intent.inputAmount,
            intent.minOutputAmount,
            intent.recipient,
            intent.maxFee,
            intent.expiry,
            intent.nonce,
            intent.routeHash
        ));
    }

    function _sign(bytes32 structHash) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        return abi.encodePacked(r, s, v);
    }

    /*//////////////////////////////////////////////////////////////
                                TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ReturnFalseModeReverts() public {
        // Mode: returns false instead of reverting [cite: 17, 28]
        token.setModes(true, false, false, false);

        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        // Asserts exact OpenZeppelin 5.x error selector [cite: 105, 116]
        vm.expectRevert(abi.encodeWithSelector(SafeERC20.SafeERC20FailedOperation.selector, address(token)));
        vm.prank(solver);
        core.settle(intent, signature, proof);
    }

    function test_RevertModeReverts() public {
        // Mode: Explicitly reverts [cite: 17, 28]
        token.setModes(false, false, false, true);

        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        vm.expectRevert("Malicious revert");
        vm.prank(solver);
        core.settle(intent, signature, proof);
    }

    function test_NoReturnModeSucceeds() public {
        // Mode: returns no data (USDT-style) [cite: 17, 28]
        token.setModes(false, false, true, false);

        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        vm.prank(solver);
        core.settle(intent, signature, proof);

        // Proves SafeERC20 allows successful settlement for "void" returns 
        assertTrue(core.nonceUsed(user, 1));
        assertEq(token.balanceOf(solver), 9 ether);        
        assertEq(token.balanceOf(treasury), 1 ether);
    }

    function test_SilentFailBreaksAccounting() public {
        // Mode: returns true but moves no funds [cite: 17, 28]
        token.setModes(false, true, false, false);

        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        vm.prank(solver);
        core.settle(intent, signature, proof);

        // Nonce is used because Core believes settlement worked [cite: 116]
        assertTrue(core.nonceUsed(user, 1));

        // Triple-Entry proof of imbalance [cite: 86, 113]
        assertEq(token.balanceOf(user), 100 ether);
        assertEq(token.balanceOf(solver), 0);       // Solver received nothing
        assertEq(token.balanceOf(treasury), 0);     // Treasury received nothing
    }
}