// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";

contract ApproveToken is Script {

    function run() external {

        uint256 userKey = vm.envUint("USER_PRIVATE_KEY");
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address coreAddress = vm.envAddress("CORE_ADDRESS");

        vm.startBroadcast(userKey);

        MockERC20 token = MockERC20(tokenAddress);

        token.approve(coreAddress, type(uint256).max);

        vm.stopBroadcast();

        console.log("User approved Core contract.");
    }
}