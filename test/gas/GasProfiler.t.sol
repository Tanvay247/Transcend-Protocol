// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../../src/TranscendCore.sol";
import "../mocks/MerkleHeaderVerifierStub.sol";
import "../mocks/MockERC20.sol";
import "../mocks/MaliciousERC20.sol";

/**
 * @title GasProfiler
 * @notice Gas benchmarking suite for TranscendCore settlement paths.
 * @dev Use with:
 *      forge test --gas-report
 *      forge snapshot
 */
contract GasProfiler is Test {

    TranscendCore core;
    MerkleHeaderVerifierStub verifier;

    MockERC20 normalToken;
    MaliciousERC20 maliciousToken;

    address treasury;
    address solver;
    address user;

    uint256 userPK = 0xA11CE;
    uint256 constant FLAT_FEE = 1 ether;

    uint256 internal nonceCounter;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        treasury = makeAddr("treasury");
        solver = makeAddr("solver");
        user = vm.addr(userPK);

        verifier = new MerkleHeaderVerifierStub();
        core = new TranscendCore(FLAT_FEE, 30, treasury);

        core.registerHeaderVerifier(1, address(verifier));

        normalToken = new MockERC20();
        maliciousToken = new MaliciousERC20();

        normalToken.mint(user, 1000 ether);
        maliciousToken.mint(user, 1000 ether);

        vm.prank(user);
        normalToken.approve(address(core), type(uint256).max);

        vm.prank(user);
        maliciousToken.approve(address(core), type(uint256).max);

        vm.deal(solver, 100 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildIntent(address token, uint256 amount)
        internal
        returns (TranscendCore.Intent memory intent, bytes32 structHash)
    {
        nonceCounter++;

        intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: block.chainid,
            destinationChainId: 1,
            inputAsset: token,
            outputAsset: address(999),
            inputAmount: amount,
            minOutputAmount: 5 ether,
            recipient: user,
            maxFee: 2 ether,
            expiry: block.timestamp + 1 hours,
            nonce: nonceCounter,
            routeHash: keccak256("route")
        });

        structHash = keccak256(
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
    }

    function _sign(bytes32 structHash)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest =
            keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _proof(
        bytes32 structHash,
        address recipient,
        address outputAsset
    )
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(
            bytes32(uint256(1)),  // fake root
            bytes32(uint256(2)),  // fake leaf
            abi.encode(
                structHash,
                recipient,
                outputAsset,
                uint256(6 ether)
            )
        );
    }

    /*//////////////////////////////////////////////////////////////
                            GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    /// Baseline ERC20 settlement
    function testGas_NormalERC20() public {
        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(address(normalToken), 10 ether);

        bytes memory signature = _sign(structHash);
        bytes memory proofData =_proof(structHash, intent.recipient, intent.outputAsset);

        vm.prank(solver);
        core.settle(intent, signature, proofData);
    }

    /// USDT-style no-return token
    function testGas_NoReturnERC20() public {
        maliciousToken.setModes(false, false, true, false);

        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(address(maliciousToken), 10 ether);

        bytes memory signature = _sign(structHash);
        bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

        vm.prank(solver);
        core.settle(intent, signature, proofData);
    }

    /// Return-false revert path
    function testGas_ReturnFalseRevert() public {
        maliciousToken.setModes(true, false, false, false);

        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(address(maliciousToken), 10 ether);

        bytes memory signature = _sign(structHash);
        bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

        vm.prank(solver);
        vm.expectRevert();
        core.settle(intent, signature, proofData);
    }

    /// Explicit revert path
    function testGas_RevertModeRevert() public {
        maliciousToken.setModes(false, false, false, true);

        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(address(maliciousToken), 10 ether);

        bytes memory signature = _sign(structHash);
        bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

        vm.prank(solver);
        vm.expectRevert();
        core.settle(intent, signature, proofData);
    }

    /// Native ETH path
    function testGas_NativeETH() public {
        (TranscendCore.Intent memory intent, bytes32 structHash) =
            _buildIntent(address(0), 10 ether);

        bytes memory signature = _sign(structHash);
        bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

        vm.prank(solver);
        core.settle{value: intent.inputAmount}(intent, signature, proofData);
    }
}