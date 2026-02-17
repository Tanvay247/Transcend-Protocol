// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockHeaderVerifier.sol";
import "../mocks/MockERC20.sol";

contract TranscendCoreBranchTest is Test {
    TranscendCore core;
    MockHeaderVerifier verifier;
    MockERC20 token;

    address treasury;
    address solver;
    address user;
    uint256 userPK = 0xA11CE;

    uint256 constant FLAT_FEE = 0.01 ether;
    uint256 constant BPS_FEE  = 30;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        treasury = makeAddr("treasury");
        solver   = makeAddr("solver");
        user     = vm.addr(userPK);

        verifier = new MockHeaderVerifier();
        core     = new TranscendCore(FLAT_FEE, BPS_FEE, treasury);
        token    = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier));

        token.mint(user, 1000 ether);
        vm.prank(user);
        token.approve(address(core), type(uint256).max);

        vm.deal(solver, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildIntent(
        uint256 expiry,
        uint256 destChain,
        uint256 maxFeeOverride,
        address inputAsset
    )
        internal
        view
        returns (TranscendCore.Intent memory intent, bytes32 structHash)
    {
        uint256 amount = 10 ether;
        uint256 dynamicFee = (amount * BPS_FEE) / 10000;
        uint256 expectedFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE;

        intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: block.chainid,
            destinationChainId: destChain,
            inputAsset: inputAsset,
            outputAsset: address(999),
            inputAmount: amount,
            minOutputAmount: 5 ether,
            recipient: user,
            maxFee: maxFeeOverride == 0 ? expectedFee : maxFeeOverride,
            expiry: expiry,
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
        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _proof(bytes32 structHash)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            abi.encode(structHash, user, address(999), 6 ether)
        );
    }

    /*//////////////////////////////////////////////////////////////
                        BRANCH COVERAGE TESTS
    //////////////////////////////////////////////////////////////*/

    /// Expiry branch
    function test_RevertIfExpired() public {
        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp - 1, 1, 0, address(token));

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrExpired.selector);
        core.settle(intent, sig, proof);
    }

    /// Fee exceeded branch
    function test_RevertIfFeeExceeded() public {
        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        intent.maxFee = 0;

        // Recompute hash after modifying maxFee
        hash = keccak256(abi.encode(
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

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrFeeExceeded.selector);
        core.settle(intent, sig, proof);
    }

    /// Invalid signature branch
    function test_RevertIfInvalidSignature() public {
        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        // 🔥 Sign correctly formed digest but with WRONG private key
        uint256 wrongPK = 0xBEEF;

        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(wrongPK, digest);
        bytes memory badSig = abi.encodePacked(r, s, v);

        bytes memory proof = _proof(structHash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrInvalidSignature.selector);
        core.settle(intent, badSig, proof);
    }

    /// Wrong destination chain branch
    /// Wrong origin chain branch
    function test_RevertIfInvalidChain() public {
        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        intent.originChainId = 999;

        hash = keccak256(abi.encode(
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

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrWrongChain.selector);
        core.settle(intent, sig, proof);
    }

    /// Missing verifier branch
    function test_RevertIfVerifierMissing() public {
        core.registerHeaderVerifier(1, address(0));

        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrProofInvalid.selector);
        core.settle(intent, sig, proof);
    }

    /// Native ETH path – incorrect msg.value
    function test_RevertIfNativeETHIncorrectAmount() public {
        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(0));

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);

        vm.expectRevert(TranscendCore.ErrInvalidETHAmount.selector);

        // Sending only solverTip instead of inputAmount + solverTip
        core.settle(intent, sig, proof);
    }

    function test_RevertIfPaused() public {
        core.pause(true);

        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrPaused.selector);
        core.settle(intent, sig, proof);
    }

    function test_RevertIfNonceUsed() public {
        uint256 customNonce = 999;

        (TranscendCore.Intent memory intent, ) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        intent.nonce = customNonce;

        // Recompute struct hash after changing nonce
        bytes32 hash = keccak256(abi.encode(
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

        bytes memory sig = _sign(hash);
        bytes memory proof = abi.encode(hash, user, intent.outputAsset, 6 ether);

        // First call MUST succeed
        vm.prank(solver);
        core.settle(intent, sig, proof);

        // Second call MUST revert with ErrNonceUsed
        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrNonceUsed.selector);
        core.settle(intent, sig, proof);
    }

    function test_RevertIfInsufficientAllowance() public {
        vm.prank(user);
        token.approve(address(core), 0);

        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        bytes memory sig = _sign(hash);
        bytes memory proof = _proof(hash);

        vm.prank(solver);
        vm.expectRevert();
        core.settle(intent, sig, proof);
    }

    function test_RevertIfMinOutputNotMet() public {
        (TranscendCore.Intent memory intent, bytes32 hash) =
            _buildIntent(block.timestamp + 1 hours, 1, 0, address(token));

        bytes memory sig = _sign(hash);

        bytes memory proof = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            abi.encode(hash, user, address(999), 1 ether) // below minOutputAmount
        );

        vm.prank(solver);
        vm.expectRevert();
        core.settle(intent, sig, proof);
    }

    function test_RevertIfUnauthorizedPause() public {
        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrUnauthorized.selector);
        core.pause(true);
    }

    function test_RevertIfUnauthorizedSetFees() public {
        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrUnauthorized.selector);
        core.setProtocolFees(1 ether, 10);
    }

    function test_RevertIfUnauthorizedRegisterVerifier() public {
        vm.prank(solver);
        vm.expectRevert(TranscendCore.ErrUnauthorized.selector);
        core.registerHeaderVerifier(2, address(verifier));
    }



}