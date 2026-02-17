// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IHeaderVerifier.sol";

/**
 * @title MerkleHeaderVerifierStub
 * @notice Simulates realistic Merkle proof verification gas cost.
 */
contract MerkleHeaderVerifierStub is IHeaderVerifier {

    function verifyProof(
        uint256,
        bytes calldata proof
    )
        external
        pure
        override
        returns (bool, bytes memory)
    {
        bytes32 root;
        bytes32 leaf;

        assembly {
            root := calldataload(proof.offset)
            leaf := calldataload(add(proof.offset, 32))
        }

        // Simulate Merkle depth
        for (uint256 i = 0; i < 10; i++) {
            leaf = keccak256(abi.encodePacked(leaf, root));
        }

        // Return remaining bytes as public inputs
        bytes memory publicInputs = proof[64:];
        return (true, publicInputs);
    }

    function verifierType() external pure returns (uint8) {
        return 1;
    }

    function version() external pure returns (uint256) {
        return 1;
    }
}