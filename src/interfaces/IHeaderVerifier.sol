// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IHeaderVerifier
 * @notice Stateless interface for chain-specific proof verification engines.
 *
 * @dev The Verifier is responsible ONLY for validating cryptographic truth.
 * It does NOT enforce economic constraints. That responsibility belongs to
 * the TranscendCore contract.
 *
 * The returned `publicInputs` MUST ABI-decode into:
 *
 * (
 *     bytes32 intentHash,
 *     address recipient,
 *     address asset,
 *     uint256 deliveredAmount
 * )
 *
 * These values are bound and validated by the Core contract.
 */
interface IHeaderVerifier {

    /**
     * @notice Verifies a cross-chain proof of delivery.
     *
     * @param destinationChainId The chain where delivery occurred.
     * @param proof Encoded proof blob (ZK proof, optimistic proof, etc.).
     *
     * @return success Whether the proof is cryptographically valid.
     * @return publicInputs ABI-encoded observed facts extracted from the proof.
     *
     * @dev Requirements:
     * - MUST be stateless.
     * - MUST NOT modify state.
     * - MUST bind proof validity strictly to destinationChainId.
     */
    function verifyProof(
        uint256 destinationChainId,
        bytes calldata proof
    ) external view returns (bool success, bytes memory publicInputs);

    /**
     * @notice Returns the security model classification of this verifier.
     *
     * Example return values:
     * 1 = ZK_SNARK
     * 2 = OPTIMISTIC_ROOT
     * 3 = TEE
     * 4 = COMMITTEE
     *
     * @dev Metadata only. Must NOT influence settlement logic.
     */
    function verifierType() external pure returns (uint8);

    /**
     * @notice Returns the implementation version of this verifier.
     *
     * @dev Allows tracking verifier upgrades over time.
     * Pure metadata. Must NOT influence settlement logic.
     */
    function version() external pure returns (uint256);
}