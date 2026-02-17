// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/TranscendCore.sol";
import "../mocks/MockERC20.sol";

contract TranscendHandler is Test {
    TranscendCore public core;
    MockERC20 public token;
    address public treasury;

    address[] public users;
    address[] public solvers;

    mapping(address => uint256) public userNonce;

    uint256 public totalUserDebited;
    uint256 public totalSolverCredited;
    uint256 public totalTreasuryCredited;
    uint256 public successfulSettlements;

    constructor(
        TranscendCore _core,
        MockERC20 _token,
        address _treasury,
        address[] memory _users,
        address[] memory _solvers
    ) {
        core = _core;
        token = _token;
        treasury = _treasury;
        users = _users;
        solvers = _solvers;
    }

    function settleRandom(
        uint256 userSeed,
        uint256 solverSeed,
        uint256 amount
    ) public {
        uint256 flatFee = core.flatBaseFee();
        if (amount <= flatFee || amount > 100_000 ether) return;

        address user = users[userSeed % users.length];
        address solver = solvers[solverSeed % solvers.length];

        uint256 tentativeNonce = userNonce[user] + 1;

        // Calculate expected protocol fee for maxFee setting
        uint256 dynamicFee = (amount * core.bpsFee()) / 10000;
        uint256 expectedFee = dynamicFee > flatFee ? dynamicFee : flatFee;

        TranscendCore.Intent memory intent = TranscendCore.Intent({
            version: 1,
            user: user,
            originChainId: block.chainid,
            destinationChainId: 1,
            inputAsset: address(token),
            outputAsset: address(999),
            inputAmount: amount,
            minOutputAmount: 1, // Minimize delivery constraints for fuzzing
            recipient: user,
            maxFee: expectedFee,
            expiry: block.timestamp + 1 hours,
            nonce: tentativeNonce,
            routeHash: keccak256("route")
        });

        bytes32 structHash = keccak256(
            abi.encode(
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
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", core.DOMAIN_SEPARATOR(), structHash)
        );

        uint256 privateKey = uint256(uint160(user));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory proofFact = abi.encode(
            structHash,
            user,
            intent.outputAsset,
            intent.minOutputAmount
        );

        uint256 userStart = token.balanceOf(user);
        uint256 solverStart = token.balanceOf(solver);
        uint256 treasuryStart = token.balanceOf(treasury);

        vm.startPrank(solver);
        try core.settle(intent, signature, proofFact) {
            userNonce[user]++;
            successfulSettlements++;

            uint256 userEnd = token.balanceOf(user);
            uint256 solverEnd = token.balanceOf(solver);
            uint256 treasuryEnd = token.balanceOf(treasury);

            totalUserDebited += (userStart - userEnd);
            totalSolverCredited += (solverEnd - solverStart);
            totalTreasuryCredited += (treasuryEnd - treasuryStart);
        } catch {}
        vm.stopPrank();
    }
}