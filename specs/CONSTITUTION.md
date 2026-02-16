# 📜 The Transcend Constitution

This document defines what Transcend is and the mathematical rules it must **never** break.

## 1. Core Identity
Transcend is a **Stateless Settlement Layer**.
* It does not store user funds.
* It does not provide advice or strategies.
* It acts as a "Judge" that validates if an intent was fulfilled correctly.

## 2. Unbreakable Rules (Invariants)
To keep the system safe, these 10 rules are permanent:

1. **No Proof, No Pay:** A Solver never gets paid unless they provide cryptographic proof of delivery.
2. **One-Time Use:** Every request has a unique ID (nonce) that can never be used twice.
3. **All or Nothing:** Execution is atomic; a deal either finishes perfectly or resets completely.
4. **Predictable:** The system must produce the same result every time it sees the same proof.
5. **No Sitting Money:** Transcend never holds "pools" of user funds.
6. **Cost Limits:** The system can never charge a fee higher than the user’s signed `maxFee`.
7. **Domain Protection:** A request meant for one chain cannot be settled on another.
8. **Real Proofs Only:** Proofs must follow a documented, chain-specific Finality Policy as defined in `VERIFIER_ARCH.md`.
9. **Deadlines Matter:** If a request expires, it can never be processed.
10. **Limited Power:** Governance can adjust parameters but can **never** access user funds or override invariants.