# ⚖️ The Solver Market Model

This document explains the economic incentives that keep Transcend efficient.

## 1. First-to-Finish Competition
Transcend uses a competitive model where any whitelisted solver can settle an intent. The first valid settlement mined on the origin chain wins the user's payment.

## 2. Risk Allocation
* **Solver Risks**: Slippage, bridge failure, gas spikes, and user revocation.
* **User Benefits**: Guaranteed outcomes or $0 cost.

## 3. Solver Profit
Solvers only act if the expected profit is positive:
`Profit = (User_Payment - Flat_Fee) - Execution_Costs`

## 4. Equilibrium
Competitive pressure forces solvers to minimize costs and maximize speed, creating an efficient automated market for user intents.