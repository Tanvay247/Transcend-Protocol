# 🔤 Universal Intent Schema (v1.1)

This document defines the **Language of Transcend**. For the system to work, every request (Intent) must be written in this exact format. If the grammar is wrong, the "Judge" (The Core Contract) will reject the deal.

## 1. Why do we need this?
In a world with many different blockchains and AI agents, we need a "Universal Translator." This schema ensures that:
* **Users** know exactly what they are signing.
* **Solvers** know exactly what work to do.
* **The Core Contract** can verify the deal using math, not guesswork.

---

## 2. The Intent Structure (The "Form")
Think of an Intent as a digital envelope. It has four layers of information:

### Layer 1: The Domain (Where?)
* **Version**: Tells the system which rules to use (currently v1).
* **User**: The wallet address of the person paying.
* **Origin Chain**: The blockchain where the user's money starts.
* **Destination Chain**: The blockchain where the user wants the result.

### Layer 2: The Deal (What?)
* **Input Asset & Amount**: What the user is giving (e.g., 2500 USDC).
* **Max Fee**: The highest fee the user is willing to pay the system.
* **Output Asset & Min Amount**: What the user must receive (e.g., at least 1 ETH).
* **Recipient**: The wallet address that will receive the final assets.

### Layer 3: Safety (When?)
* **Expiry**: The exact second the deal becomes "stale" and invalid.
* **Nonce**: A unique "ticket number" to make sure the deal isn't processed twice.

### Layer 4: The Path (How?)
* **Route Hash**: A digital fingerprint of the specific path the Solver promised to take. This keeps the Solver honest about which protocols they use.

---

## 3. The Rules of the Language

### ⚖️ ABI Encoding is Law
We do not use JSON to calculate the security hash. JSON is too "loose" (it can have extra spaces or different orders). Instead, we use **ABI Encoding**. This is the native, unbreakable language of the Ethereum Virtual Machine (EVM). 

### ✍️ EIP-712 Signing
Transcend uses the **EIP-712 standard**. When a user signs an Intent, their wallet (like MetaMask) will show them a clear, readable list of exactly what they are agreeing to—no "blind signing" of random numbers.

### 🎯 Recipient-First Enforcement
The system does **not** assume the user is the one getting the money. It checks the `recipient` field. This allows an AI to pay a bill or send a gift to a third party as part of a single atomic step.

---

## 4. How the "Judge" Reads the Intent
When a Solver wants to settle a deal, the Transcend Core contract checks these steps:
1. **Signature**: Is this really what the User signed?
2. **Commitment**: Does the path the Solver took match the `routeHash`?
3. **Delivery**: Did the `recipient` get the `minAmount` on the `destinationChain`?
4. **Limits**: Is the fee lower than the `maxFee`?

If any answer is **NO**, the Solver gets paid **nothing**.

---

## 5. Technical Summary
* **Canonical Hashing**: `keccak256(abi.encode(TYPEHASH, version, user, ...))`
* **Statelessness**: The schema contains all information needed to verify the deal; the contract doesn't need to look up outside data.
* **Version Lock**: Version 1 is frozen. Any future changes will be called Version 2.