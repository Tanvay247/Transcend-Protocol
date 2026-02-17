// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockHeaderVerifier.sol";
import "../mocks/ReentrantERC20.sol";

/**
 * @title ReentrancyTest
 * @notice Final verification of CEI protection and Nonce Lock integrity.
 */
contract ReentrancyTest is Test {
    TranscendCore core;
    MockHeaderVerifier verifier;
    ReentrantERC20 token;

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
        token = new ReentrantERC20(core);

        core.registerHeaderVerifier(1, address(verifier));

        token.mint(user, 100 ether);

        vm.prank(user);
        token.approve(address(core), type(uint256).max);
    }

    function test_ReplayReentrancyFails() public {
        TranscendCore.Intent memory intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: block.chainid,
            destinationChainId: 1,
            inputAsset: address(token),
            outputAsset: address(999),
            inputAmount: 10 ether,
            minOutputAmount: 5 ether,
            recipient: user,
            maxFee: 2 ether,
            expiry: block.timestamp + 1 hours,
            nonce: 1,
            routeHash: keccak256("route")
        });

        bytes32 structHash = keccak256(
            abi.encode(
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
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        // Configure the harness to attack during the transferFrom interaction
        token.configureAttack(true, intent, signature, proof);

        vm.prank(solver);
        core.settle(intent, signature, proof);

        // 1. Confirm the original transaction marked the nonce as used [cite: 55, 60]
        assertTrue(core.nonceUsed(user, 1));

        // 2. Confirm the reentrant call failed specifically with the Nonce error 
        assertEq(
            token.lastErrorSelector(),
            TranscendCore.ErrNonceUsed.selector
        );
    }
}