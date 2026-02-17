// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {TranscendCore} from "../src/TranscendCore.sol";
import {MerkleHeaderVerifierStub} from "../test/mocks/MerkleHeaderVerifierStub.sol";

contract DeployTranscend is Script {
    function run() external {
        // 1. Load configuration
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address treasury = vm.envAddress("TREASURY_ADDRESS");
        
        // 2. Begin Broadcast
        vm.startBroadcast(privateKey);

        // 3. Deploy Verifier Stub
        MerkleHeaderVerifierStub verifier = new MerkleHeaderVerifierStub();

        // 4. Deploy Core with Dynamic Fee parameters
        // Matches the 3-argument constructor: (flatBaseFee, bpsFee, treasury)
        TranscendCore core = new TranscendCore(
            0.003 ether, // flatBaseFee 
            30,          // bpsFee (0.30%) 
            treasury     // Treasury Address 
        );

        // 5. Initial Protocol Configuration
        // Registering Chain 1 as a valid destination with the new verifier
        core.registerHeaderVerifier(1, address(verifier)); 

        vm.stopBroadcast();

        // 6. Output log for Etherscan verification
        console.log("TranscendCore deployed at:", address(core));
        console.log("Verifier registered at:", address(verifier));
        console.log("Treasury set to:", treasury);
    }
}