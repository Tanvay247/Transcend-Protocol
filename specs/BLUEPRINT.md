# 🏗️ The Technical Blueprint

This is the technical design for the Transcend smart contracts.

## 1. The Intent Structure
This is the "Order Form" the user signs. It must contain these exact pieces of data:

| Field | Description |
| :--- | :--- |
| **user** | The wallet address of the person making the request. |
| **originChainId** | The blockchain where the user's money is starting. |
| **destinationChainId** | The blockchain where the user wants to receive assets. |
| **inputAsset** | The money the user is giving (e.g., USDC). |
| **outputAsset** | The asset the user wants to get (e.g., ETH). |
| **inputAmount** | Exactly how much the user is giving. |
| **minOutputAmount** | The bare minimum the user is willing to accept. |
| **maxFee** | The most the user is willing to pay in fees. |
| **expiry** | The date/time the request becomes invalid. |
| **nonce** | A unique number to prevent repeating the deal. |
| **routeHash** | A "fingerprint" of the specific path the Solver must take. |

## 2. Core Functions
* `settle()`: This is the main engine. It checks the signature, checks the proof, and moves the money.
* `registerHeaderVerifier()`: Plugs in a "Truth Source" for different blockchains.
* `pause()`: An emergency stop button for the people in charge.

## 3. Forbidden Actions
The code is strictly banned from:
* Using "hidden" or "random" logic.
* Storing lists of user history (to keep it fast and cheap).
* Changing its own rules automatically (Non-upgradeable).