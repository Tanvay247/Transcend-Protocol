// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/TranscendCore.sol";
import "../test/mocks/MerkleHeaderVerifierStub.sol";

contract DeployTranscend is Script {
    function run() external {
        // 1. Load configuration
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        // 2. Begin Broadcast (all transactions after this are signed by deployer)
        vm.startBroadcast(privateKey);

        // 3. Deploy Verifier Stub
        MerkleHeaderVerifierStub verifier = new MerkleHeaderVerifierStub();

        // 4. Deploy Core with Dynamic Fee parameters
        TranscendCore core = new TranscendCore(
            0.003 ether, // flatBaseFee 
            30,          // bpsFee (0.30%)
            treasury     // Separate Treasury Address 
        );

        // 5. Initial Protocol Configuration
        // Registering Chain 1 (e.g., Ethereum Mainnet) as a valid destination
        core.registerHeaderVerifier(1, address(verifier)); 

        vm.stopBroadcast();

        // 6. Output log for Etherscan verification
        console.log("TranscendCore deployed at:", address(core));
        console.log("Verifier registered at:", address(verifier));
        console.log("Treasury set to:", treasury);
    }
}