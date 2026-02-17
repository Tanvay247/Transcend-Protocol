// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockHeaderVerifier.sol";
import "../mocks/MockERC20.sol";

contract TranscendCoreTest is Test {
    TranscendCore core;
    MockHeaderVerifier verifier;
    MockERC20 token;

    address treasury;
    address solver;
    address user;
    uint256 userPK = 0xA11CE;

    uint256 constant FLAT_FEE = 0.01 ether;
    uint256 constant BPS_FEE = 30; // 0.3%

    function setUp() public {
        treasury = makeAddr("treasury");
        solver = makeAddr("solver");
        user = vm.addr(userPK);

        verifier = new MockHeaderVerifier();
        core = new TranscendCore(FLAT_FEE, BPS_FEE, treasury);
        token = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier));

        token.mint(user, 1000000 ether);
        vm.prank(user);
        token.approve(address(core), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildIntent(uint256 amount) internal view returns (TranscendCore.Intent memory intent, bytes32 structHash) {
        uint256 dynamicFee = (amount * BPS_FEE) / 10000;
        uint256 expectedFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE;

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
            maxFee: expectedFee,
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

    function testFuzz_SettleERC20(uint256 amount) public {
        amount = bound(amount, 0.1 ether, 10000 ether);

        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(amount);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        uint256 userStart = token.balanceOf(user);
        uint256 solverStart = token.balanceOf(solver);
        uint256 treasuryStart = token.balanceOf(treasury);

        vm.prank(solver);
        core.settle(intent, signature, proof);

        uint256 dynamicFee = (amount * BPS_FEE) / 10000;
        uint256 expectedFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE;

        assertEq(token.balanceOf(user), userStart - amount);
        assertEq(token.balanceOf(solver), solverStart + (amount - expectedFee));
        assertEq(token.balanceOf(treasury), treasuryStart + expectedFee);
        assertTrue(core.nonceUsed(user, 1));
    }

    function test_RevertIfDeliveryTooLow() public {
        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);

        // Providing a lower amount than minOutputAmount
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 4 ether);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrIntentMismatch.selector);
        core.settle(intent, signature, proof);
    }

    function test_RevertOnDoubleSpend() public {
        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(10 ether);
        bytes memory signature = _sign(structHash);
        bytes memory proof = abi.encode(structHash, user, intent.outputAsset, 6 ether);

        vm.startPrank(solver);
        core.settle(intent, signature, proof);

        vm.expectRevert(TranscendCore.ErrNonceUsed.selector);
        core.settle(intent, signature, proof);
        vm.stopPrank();
    }

    function test_VerifierMetadata() public view {
        address verifierAddr = core.headerVerifiers(1);
        assertEq(verifierAddr, address(verifier));
    }
}