// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MerkleHeaderVerifierStub.sol";
import "../mocks/MockERC20.sol";

contract SolverDeadZone is Test {
    TranscendCore core;
    MerkleHeaderVerifierStub verifier;
    MockERC20 token;

    address treasury;
    address solver;
    address user;

    uint256 userPK = 0xA11CE;

    uint256 constant FLAT_FEE = 0.01 ether;
    uint256 constant BPS_FEE  = 30; // 0.30%

    function setUp() public {
        treasury = makeAddr("treasury");
        solver   = makeAddr("solver");
        user     = vm.addr(userPK);

        verifier = new MerkleHeaderVerifierStub();
        core     = new TranscendCore(FLAT_FEE, BPS_FEE, treasury);
        token    = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier));
        token.mint(user, 10_000 ether);

        vm.prank(user);
        token.approve(address(core), type(uint256).max);
        vm.deal(solver, 10 ether);
    }

    function _buildIntent(uint256 amount, uint256 nonce) internal view returns (TranscendCore.Intent memory intent, bytes32 structHash) {
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
            minOutputAmount: 0.001 ether,
            recipient: user,
            maxFee: expectedFee,
            expiry: block.timestamp + 1 hours,
            nonce: nonce,
            routeHash: keccak256(abi.encodePacked("dead-zone", nonce))

        });

        structHash = keccak256(abi.encode(
            core.INTENT_TYPEHASH(), intent.version, intent.user, intent.originChainId,
            intent.destinationChainId, intent.inputAsset, intent.outputAsset, intent.inputAmount,
            intent.minOutputAmount, intent.recipient, intent.maxFee, intent.expiry,
            intent.nonce, intent.routeHash
        ));
    }

    function _sign(bytes32 structHash) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPK, digest);
        return abi.encodePacked(r, s, v);
    }

    function _proof(bytes32 structHash, address recip, address asset) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            abi.encode(structHash, recip, asset, uint256(2 ether))
        );
    }

    function test_MapSolverDeadZone() public {
        uint256[] memory gasPrices = new uint256[](4);
        gasPrices[0] = 20 gwei;
        gasPrices[1] = 50 gwei;
        gasPrices[2] = 100 gwei;
        gasPrices[3] = 500 gwei;

        uint256[] memory intentSizes = new uint256[](6);
        intentSizes[0] = 0.01 ether;
        intentSizes[1] = 0.05 ether;
        intentSizes[2] = 0.1 ether;
        intentSizes[3] = 0.5 ether;
        intentSizes[4] = 1 ether;
        intentSizes[5] = 5 ether;

        console.log("==== SOLVER ECONOMIC LIVENESS MAP ====");

        for (uint256 i = 0; i < intentSizes.length; i++) {
            uint256 amount = intentSizes[i];

            // Use Snapshots for isolated state modeling
            uint256 snapshotId = vm.snapshot();

            (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(amount, i + 1);
            bytes memory signature = _sign(structHash);
            bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

            uint256 gasBefore = gasleft();
            vm.prank(solver);
            core.settle(intent, signature, proofData);
            uint256 gasUsed = gasBefore - gasleft();

            uint256 dynamicFee = (amount * BPS_FEE) / 10000;
            uint256 finalFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE;
            uint256 solverGross = (amount - finalFee);

            console.log("--------------------------------");
            console.log("Intent Size:", amount);
            console.log("Fixed Gas Consumption:", gasUsed);

            for (uint256 j = 0; j < gasPrices.length; j++) {
                uint256 gasCost = gasUsed * gasPrices[j];
                bool profitable = solverGross > gasCost;

                // Mathematical Break-Even Detection
                // Min Size = (GasCost * 10000) / BPS
                uint256 minViableSize = (gasCost * 10000) / BPS_FEE;

                console.log("Gas Price (Gwei):", gasPrices[j] / 1 gwei);
                if (profitable) {
                    console.log("Status: PROFITABLE");
                } else {
                    console.log("Status: DEAD ZONE (LOSS)");
                    console.log("Required Intent Size for Break-Even (Wei):", minViableSize);
                }
            }

            // Revert to clean state for next intent size
            vm.revertTo(snapshotId);
        }
    }
}