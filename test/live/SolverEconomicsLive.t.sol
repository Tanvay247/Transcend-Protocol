// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MerkleHeaderVerifierStub.sol";
import "../mocks/MockERC20.sol";

contract SolverEconomicsLive is Test {
    TranscendCore core;
    MerkleHeaderVerifierStub verifier;
    MockERC20 token;

    address treasury;
    address solver;
    address user;

    uint256 userPK = 0xA11CE;
    uint256 constant FLAT_FEE = 0.01 ether;
    uint256 constant BPS_FEE = 30; // 0.30%

    function setUp() public {
        treasury = makeAddr("treasury");
        solver   = makeAddr("solver");
        user     = vm.addr(userPK);

        verifier = new MerkleHeaderVerifierStub();
        // Corrected for 3-argument constructor [cite: 21]
        core     = new TranscendCore(FLAT_FEE, BPS_FEE, treasury);
        token    = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier));
        token.mint(user, 1000 ether);

        vm.prank(user);
        token.approve(address(core), type(uint256).max);
        vm.deal(solver, 10 ether);
    }

    function _buildIntent(uint256 amount) internal view returns (TranscendCore.Intent memory intent, bytes32 structHash) {
        // Calculate maxFee based on protocol's dynamic logic to avoid ErrFeeExceeded 
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
            minOutputAmount: 50 ether,
            recipient: user,
            maxFee: expectedFee, // Set to exactly what core will extract
            expiry: block.timestamp + 1 hours,
            nonce: 1,
            routeHash: keccak256("economics-route")
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
        // Must match intent recipient and asset to pass verification 
        return abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            abi.encode(structHash, recip, asset, uint256(60 ether))
        );
    }

    function test_SolverProfitabilityLive() public {
        uint256 inputAmount = 100 ether;
        (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(inputAmount);

        bytes memory signature = _sign(structHash);
        bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

        uint256 gasBefore = gasleft();
        vm.prank(solver);
        core.settle(intent, signature, proofData);
        uint256 gasUsed = gasBefore - gasleft();

        // Corrected memory array initialization
        uint256[] memory gasPrices = new uint256[](4);
        gasPrices[0] = 20 gwei;
        gasPrices[1] = 50 gwei;
        gasPrices[2] = 100 gwei;
        gasPrices[3] = 500 gwei;

        console.log("---- Solver Economics Report ----");
        console.log("Gas Used:", gasUsed);

        for (uint256 i = 0; i < gasPrices.length; i++) {
            uint256 gasCost = gasUsed * gasPrices[i];
            
            // Mirroring the Core's hybrid fee logic 
            uint256 dynamicFee = (inputAmount * BPS_FEE) / 10000;
            uint256 finalFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE;
            
            uint256 solverGross = (inputAmount - finalFee); 
            uint256 solverNet = solverGross > gasCost ? solverGross - gasCost : 0;

            console.log("Gas Price (Gwei):", gasPrices[i] / 1 gwei);
            console.log("Gas Cost (Wei):", gasCost);
            console.log("Solver Net (Wei):", solverNet);
            console.log("-----------------------------");
        }

        assertTrue(token.balanceOf(solver) > 0);
    }
}