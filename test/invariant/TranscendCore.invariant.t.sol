// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockHeaderVerifier.sol";
import "../mocks/MockERC20.sol";
import "./TranscendHandler.sol";

contract TranscendCoreInvariantTest is StdInvariant, Test {
    TranscendCore core;
    MockHeaderVerifier verifier;
    MockERC20 token;
    TranscendHandler handler;

    address treasury;

    function setUp() public {
        treasury = makeAddr("treasury");
        verifier = new MockHeaderVerifier();
        
        core = new TranscendCore(0.01 ether, 30, treasury);
        token = new MockERC20();

        core.registerHeaderVerifier(1, address(verifier));

        address[] memory users = new address[](3);
        address[] memory solvers = new address[](2);

        for (uint256 i; i < 3; i++) {
            users[i] = makeAddr(string.concat("user", vm.toString(i)));
            vm.deal(users[i], 1000 ether);
            token.mint(users[i], 1_000_000 ether);
            vm.prank(users[i]);
            token.approve(address(core), type(uint256).max);
        }

        for (uint256 i; i < 2; i++) {
            solvers[i] = makeAddr(string.concat("solver", vm.toString(i)));
            vm.deal(solvers[i], 1000 ether);
        }

        handler = new TranscendHandler(core, token, treasury, users, solvers);
        targetContract(address(handler));
    }

    function invariant_AccountingSymmetry() public view {
        assertEq(
            handler.totalUserDebited(),
            handler.totalSolverCredited() + handler.totalTreasuryCredited()
        );
    }

    function invariant_CoreHasNoERC20() public view {
        assertEq(token.balanceOf(address(core)), 0);
    }

    function invariant_CoreHasNoETH() public view {
        assertEq(address(core).balance, 0);
    }
}