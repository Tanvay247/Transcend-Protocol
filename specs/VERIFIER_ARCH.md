# 🛡️ ZK Header Verifier Architecture (Hardened)

This document defines the cryptographic engine of Transcend. It explains how the protocol establishes "Truth" across blockchains without middlemen.

## 1. The Verification Pipeline
A proof must pass through three distinct mathematical gates:

### Layer 1: Consensus Proof (Is the Block Real?)
The ZK circuit proves a **Block Header** is valid according to a chain-specific **Finality Policy**:
* **Ethereum**: Verified against Beacon Chain finalized epochs.
* **Rollups (v1)**: Verified against L1-posted state roots (e.g., Base, Arbitrum).

### Layer 2: Inclusion Proof (Is the Event in the Block?)
The circuit proves that a specific **Transaction Receipt** exists inside that block's `receiptsRoot` using a Merkle Proof.

### Layer 3: Semantic Proof (What actually happened?)
The circuit extracts the **Observed Facts** from the canonical `IntentFulfilled` event:

```solidity
event IntentFulfilled(
    bytes32 indexed intentHash,
    address recipient,
    address asset,
    uint256 deliveredAmount
);
```

## 2. Public Input Binding
```
To prevent proof replay, the ZK circuit must export these as Public Inputs:

intentHash

destinationChainId

recipient

asset

deliveredAmount
```

## 3. The Separation of Concerns
The Verifier answers: "Is this proof mathematically valid?"

The Core answers: "Does this fact satisfy the user's constraints?"

Core Binding Logic:

Solidity
// 1. Verify this proof belongs to THIS intent
```
require(proof.intentHash == keccak256(abi.encode(intent)), "ErrIntentMismatch");
```

// 2. Enforce Economic Constraints (The Judge checks the Fact vs. the Constraint)
```
require(proof.recipient == intent.recipient, "ErrWrongRecipient");
require(proof.asset == intent.outputAsset, "ErrWrongAsset");
require(proof.deliveredAmount >= intent.minOutputAmount, "ErrMinOutputNotMet");
```

## 4. Implementation: Rollup-First
v1 focuses on L2 Rollups to maintain momentum. We use L1-posted state roots as our "Anchor of Truth," inheriting Ethereum's security with lower proof costs.

## 5. Verifier Interface (IHeaderVerifier)
All verifiers must follow this stateless standard:
```
Solidity
interface IHeaderVerifier {
    function verifyProof(
        uint256 destinationChainId,
        bytes calldata proof
    ) external view returns (bool success, bytes memory publicInputs);
}
```