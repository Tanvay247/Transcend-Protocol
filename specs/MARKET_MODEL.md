# ⚖️ The Solver Market Model

This document explains how Transcend stays honest and efficient using money and math.

## 1. How the Market Works
Transcend uses a **First-to-Finish** model. 
* Solvers see a user's request.
* They use their own money to buy the assets for the user.
* They race to be the first one to prove they did it.
* The winner gets the user's money + a small profit.

## 2. Risk Allocation
Who loses money when things go wrong?

| Problem | Who Bears the Cost? |
| :--- | :--- |
| **Market prices change** | The Solver (takes the risk). |
| **Bridge or chain fails** | The Solver (capital is stuck/lost). |
| **User cancels access** | The Solver (must check before acting). |
| **Smart Contract bug** | The Protocol / User. |

## 3. The Math of Profit
A Solver only works if they expect to make money.
The formula they use is:
$$Profit = (User\_Payment - Flat\_Fee) - Execution\_Costs$$

If the Solver fails to provide the proof, they receive **$0**. This ensures they have a massive incentive to be honest and fast.

## 4. Equilibrium
Over time, only the fastest and cheapest Solvers will stay in the market. This means users get the best possible prices without having to do any manual work.