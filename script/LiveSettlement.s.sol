// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TranscendCore.sol";

contract LiveSettlement is Script {
    function run() external {
        uint256 userKey   = vm.envUint("USER_PRIVATE_KEY");
        uint256 solverKey = vm.envUint("SOLVER_PRIVATE_KEY");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        TranscendCore core = TranscendCore(coreAddress);
        address user   = vm.addr(userKey);
        address solver = vm.addr(solverKey); // Variable is defined here

        TranscendCore.Intent memory intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: 11155111,
            destinationChainId: 1,
            inputAsset: address(0), 
            outputAsset: address(999),
            inputAmount: 0.01 ether,
            minOutputAmount: 0.005 ether,
            recipient: user,
            maxFee: 0.005 ether,
            expiry: block.timestamp + 1 hours,
            nonce: 4, 
            routeHash: keccak256("live-route")
        });

        bytes32 structHash = keccak256(abi.encode(
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

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash)
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory publicInputs = abi.encode(
            structHash,
            intent.recipient,
            intent.outputAsset,
            uint256(0.006 ether) 
        );

        bytes memory proof = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            publicInputs
        );

        vm.startBroadcast(solverKey);

        core.settle(
            intent,
            signature,
            proof
        );

        vm.stopBroadcast();

        // Using the 'solver' variable here removes the compiler warning
        console.log("Settlement Executed By Solver:", solver);
        console.log("Total Paid (Input Amount):", intent.inputAmount);
    }
}