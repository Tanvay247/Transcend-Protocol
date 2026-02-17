// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MerkleHeaderVerifierStub.sol";
import "../mocks/MockERC20.sol";

/**
 * @title ProtocolRevenueModel
 * @notice Simulates large-scale intent flow to measure treasury sustainability and solver health.
 */
contract ProtocolRevenueModel is Test {
    TranscendCore core;
    MerkleHeaderVerifierStub verifier;
    MockERC20 token;

    address treasury;
    address solver;
    address user;

    uint256 userPK = 0xA11CE;

    uint256 constant FLAT_FEE = 0.01 ether;
    uint256 constant BPS_FEE  = 30; // 0.30%
    uint256 constant SIMULATION_SIZE = 200; 

    function setUp() public {
        treasury = makeAddr("treasury");
        solver   = makeAddr("solver");
        user     = vm.addr(userPK);

        verifier = new MerkleHeaderVerifierStub();
        core     = new TranscendCore(FLAT_FEE, BPS_FEE, treasury); 
        token    = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier)); 
        token.mint(user, 1_000_000 ether);

        vm.prank(user);
        token.approve(address(core), type(uint256).max);
        vm.deal(solver, 10 ether);
    }

    function _buildIntent(uint256 amount, uint256 nonce) 
        internal 
        view 
        returns (TranscendCore.Intent memory intent, bytes32 structHash) 
    {
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
            routeHash: keccak256(abi.encodePacked("rev", nonce))
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

    function _proof(bytes32 structHash, address recip, address asset) internal pure returns (bytes memory) {
        return abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            abi.encode(structHash, recip, asset, uint256(2 ether))
        );
    }

    function test_ProtocolRevenueProjection() public {
        uint256 treasuryStart = token.balanceOf(treasury);
        uint256 totalVolume;
        uint256 totalGasUsed;
        uint256 solverLossCount; 
        uint256 marketGasPrice = 50 gwei; // Baseline congestion assumption

        console.log("==== PROTOCOL SUSTAINABILITY REPORT ====");

        for (uint256 i = 0; i < SIMULATION_SIZE; i++) {
            // Randomized intent sizes between 0.01 and 5 ETH
            uint256 amount = bound(uint256(keccak256(abi.encode(i))) % 5 ether, 0.01 ether, 5 ether);
            totalVolume += amount;

            (TranscendCore.Intent memory intent, bytes32 structHash) = _buildIntent(amount, i + 1);
            bytes memory signature = _sign(structHash);
            bytes memory proofData = _proof(structHash, intent.recipient, intent.outputAsset);

            uint256 gasBefore = gasleft();
            vm.prank(solver);
            core.settle(intent, signature, proofData); 
            uint256 gasUsed = gasBefore - gasleft();
            totalGasUsed += gasUsed;

            // Solver Health Logic
            uint256 gasCost = gasUsed * marketGasPrice;
            uint256 dynamicFee = (amount * BPS_FEE) / 10000; 
            uint256 finalFee = dynamicFee > FLAT_FEE ? dynamicFee : FLAT_FEE; 
            
            uint256 solverGross;
            unchecked { solverGross = (amount - finalFee); } 
            
            if (gasCost > solverGross) {
                solverLossCount++;
            }
        }

        uint256 treasuryEnd = token.balanceOf(treasury);
        uint256 treasuryRevenue = treasuryEnd - treasuryStart;

        console.log("Simulation Size:", SIMULATION_SIZE);
        console.log("Total Volume Processed:", totalVolume);
        console.log("Total Treasury Revenue:", treasuryRevenue);
        console.log("Average Gas Per Settlement:", totalGasUsed / SIMULATION_SIZE);
        console.log("Solver 'Toxic' Trade Count:", solverLossCount);
        console.log("Protocol Health Score:", 100 - (solverLossCount * 100 / SIMULATION_SIZE), "%");
        console.log("Revenue % of Volume (BPS):", (treasuryRevenue * 10000) / totalVolume);

        assertTrue(treasuryRevenue > 0);
    }
}