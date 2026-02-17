// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/interfaces/IHeaderVerifier.sol";

/**
 * @title MockHeaderVerifier
 * @notice Simulates ZK Proof results for Transcend Core testing.
 */
contract MockHeaderVerifier is IHeaderVerifier {
    bool public shouldSucceed = true;
    bool public manualOverride = false;
    bytes public mockedPublicInputs;
    
    // Default metadata values
    uint8 public mockType = 1; // Default to ZK_SNARK (1)
    uint256 public mockVersion = 1;

    /**
     * @notice Manually force a specific result for negative testing.
     */
    function setManualResult(bool _shouldSucceed, bytes calldata _publicInputs) external {
        shouldSucceed = _shouldSucceed;
        mockedPublicInputs = _publicInputs;
        manualOverride = true;
    }

    function reset() external {
        manualOverride = false;
        shouldSucceed = true;
    }

    /*//////////////////////////////////////////////////////////////
                        INTERFACE IMPLEMENTATION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Implements the truth engine logic.
     */
    function verifyProof(
        uint256 destinationChainId,
        bytes calldata proof
    ) external view override returns (bool, bytes memory) {
        require(destinationChainId != 0, "ErrInvalidChain");

        if (manualOverride) {
            return (shouldSucceed, mockedPublicInputs);
        }

        return (shouldSucceed, proof);
    }

    /**
     * @notice Returns the mock verifier type.
     */
    function verifierType() external pure override returns (uint8) {
        return 1; // ZK_SNARK
    }

    /**
     * @notice Returns the mock version.
     */
    function version() external pure override returns (uint256) {
        return 1;
    }
}