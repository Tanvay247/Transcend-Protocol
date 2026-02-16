# 🏗️ The Technical Blueprint

This is the technical design for the Transcend smart contracts.

## 1. The Intent Structure
This is the canonical "Order Form" signed by the user. It must contain these exact fields:

| Field | Description |
| :--- | :--- |
| **version** | The protocol version (enables future upgrades). |
| **user** | The wallet address signing and paying for the intent. |
| **originChainId** | The blockchain where settlement occurs. |
| **destinationChainId** | The blockchain where assets must be delivered. |
| **inputAsset** | The token address the user is giving. |
| **outputAsset** | The token address the user wants to receive. |
| **inputAmount** | Exactly how much the user is giving. |
| **minOutputAmount** | The bare minimum the user is willing to accept. |
| **recipient** | The wallet that receives the final assets. |
| **maxFee** | The upper bound on protocol fees. |
| **expiry** | The timestamp when the request becomes invalid. |
| **nonce** | A unique number to prevent replay attacks. |
| **routeHash** | A fingerprint of the promised execution path. **Note: The Core enforces hash equality but does not interpret the route contents.** |

## 2. Core Functions
* `settle()`: Validates signatures, checks proofs, and executes atomic payment.
* `registerHeaderVerifier()`: Plugs in verified "Truth Sources" for specific chains.
* `pause()`: Emergency stop for settlement functions.

## 3. Forbidden Actions
The code is strictly prohibited from:
* Using hidden or random logic.
* Storing user transaction history.
* Enabling automatic rule upgrades (Non-upgradeable Core).