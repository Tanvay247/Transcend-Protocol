// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";

contract MintToken is Script {

    function run() external {

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address userAddress = vm.envAddress("USER_ADDRESS");

        vm.startBroadcast(deployerKey);

        MockERC20 token = MockERC20(tokenAddress);

        token.mint(userAddress, 1000 ether);

        vm.stopBroadcast();

        console.log("Minted 1000 tokens to:", userAddress);
    }
}