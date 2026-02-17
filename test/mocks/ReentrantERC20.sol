// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../../src/TranscendCore.sol";

/**
 * @title ReentrantERC20
 * @notice Attempts replay-style reentrancy attack and captures error selectors.
 */
contract ReentrantERC20 {
    string public name = "ReentrantToken";
    string public symbol = "REENT";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    TranscendCore public core;

    bool public attackEnabled;
    bytes4 public lastErrorSelector; // Captures the specific error selector

    TranscendCore.Intent public storedIntent;
    bytes public storedSignature;
    bytes public storedProof;

    constructor(TranscendCore _core) {
        core = _core;
    }

    /*//////////////////////////////////////////////////////////////
                                ADMIN
    //////////////////////////////////////////////////////////////*/

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function configureAttack(
        bool enabled,
        TranscendCore.Intent memory intent,
        bytes memory signature,
        bytes memory proof
    ) external {
        attackEnabled = enabled;
        storedIntent = intent;
        storedSignature = signature;
        storedProof = proof;
        lastErrorSelector = bytes4(0); // Reset for new attack
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 TRANSFER
    //////////////////////////////////////////////////////////////*/

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        
        // standard allowance check
        if (from != msg.sender && allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "Not approved");
            allowance[from][msg.sender] -= amount;
        }

        // Apply state changes BEFORE external call (CEI alignment)
        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        if (attackEnabled) {
            attackEnabled = false; // Prevents infinite recursion 

            // Attempt reentrant replay attack
            try core.settle(storedIntent, storedSignature, storedProof) {
                // Should never be reached if Core is secure
            } catch (bytes memory reason) {
                // Extract the 4-byte selector from the revert reason
                lastErrorSelector = bytes4(reason);
            }
        }

        return true;
    }
}