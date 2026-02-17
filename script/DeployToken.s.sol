// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../test/mocks/MockERC20.sol";

contract DeployToken is Script {

    function run() external {

        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerKey);

        MockERC20 token = new MockERC20();

        vm.stopBroadcast();

        console.log("MockERC20 deployed at:", address(token));
    }
}