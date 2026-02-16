# 📜 The Transcend Constitution

This document defines what Transcend is and the mathematical rules it must **never** break.

## 1. Core Identity
Transcend is a **Stateless Settlement Layer**. 
* It does not store your money. 
* It does not give advice. 
* It is a "Judge" that checks if a deal was completed correctly.

## 2. Unbreakable Rules (Invariants)
To keep the system safe, these 10 rules are permanent:

1. **No Proof, No Pay:** A Solver never gets paid unless they show cryptographic proof that the user got exactly what they asked for.
2. **One-Time Use:** Every request has a unique ID (nonce). It can never be used twice.
3. **All or Nothing:** A deal cannot be "half-done." It either finishes perfectly or resets completely.
4. **Predictable:** The system must act exactly the same way every time it sees the same proof.
5. **No Sitting Money:** Transcend never holds "pools" of user funds. Money moves through the system, not into it.
6. **Cost Limits:** The system can never charge a fee higher than what the user agreed to sign.
7. **Wrong Chain Protection:** A request meant for "Chain A" cannot be tricked into working on "Chain B."
8. **Real Proofs only:** Proofs must come from verified math, not just someone saying "trust me."
9. **Deadlines Matter:** If a request expires, it can never be processed.
10. **Limited Power:** People in charge (Governance) can change settings, but they can **never** steal user funds or break these rules.
