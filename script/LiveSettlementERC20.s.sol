// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/TranscendCore.sol";

contract LiveSettlementERC20 is Script {

    function run() external {

        uint256 userKey   = vm.envUint("USER_PRIVATE_KEY");
        uint256 solverKey = vm.envUint("SOLVER_PRIVATE_KEY");

        address coreAddress  = vm.envAddress("CORE_ADDRESS");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");

        TranscendCore core = TranscendCore(coreAddress);

        address user   = vm.addr(userKey);
        address solver = vm.addr(solverKey);

        console.log("User:", user);
        console.log("Solver:", solver);
        console.log("Token:", tokenAddress);

        // --------------------------
        // Build Intent
        // --------------------------

        TranscendCore.Intent memory intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: 11155111, // Sepolia
            destinationChainId: 1,
            inputAsset: tokenAddress,
            outputAsset: address(999),
            inputAmount: 100 ether,
            minOutputAmount: 50 ether,
            recipient: user,
            maxFee: 10 ether,
            expiry: block.timestamp + 1 hours,
            nonce: 1,
            routeHash: keccak256("erc20-live-route")
        });

        // --------------------------
        // Sign Intent (User)
        // --------------------------

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

        console.log("Intent signed by user");

        // --------------------------
        // Build Proof
        // --------------------------

        bytes memory publicInputs = abi.encode(
            structHash,
            intent.recipient,
            intent.outputAsset,
            uint256(60 ether) // delivered amount > minOutputAmount
        );

        bytes memory proof = abi.encodePacked(
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            publicInputs
        );

        // --------------------------
        // Solver Executes
        // --------------------------

        vm.startBroadcast(solverKey);

        core.settle(
            intent,
            signature,
            proof
        );

        vm.stopBroadcast();

        console.log("Settlement complete.");
        console.log("User lost tokens.");
        console.log("Solver gained tokens.");
        console.log("Treasury gained fee.");
        console.log("Settlement Executed By Solver:", solver);
    }
}