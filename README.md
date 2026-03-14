# HER DAO Labs — Bitcoin DeFi Infrastructure on Stacks

> Open-source research lab exploring financial primitives enabled by sBTC.

## Overview

HER DAO Labs is building modular, well-documented proof-of-concept implementations of DeFi infrastructure on the Stacks blockchain, leveraging sBTC as the base asset. These prototypes are designed for hackathons, grant-funded research, and community experimentation.

---

## Projects

### 1. sBTC Router
**Capital Allocation Layer**

Routes sBTC liquidity across registered DeFi protocols based on configurable weight allocations (basis points). Think of it as a programmable portfolio manager for protocol liquidity.

**Key Functions:**
- `register-protocol` — add a protocol with a target weight
- `deposit` — users deposit sBTC into the router
- `route-allocation` — proportionally distributes capital to protocols
- `withdraw` — users reclaim their deposited sBTC

**Architecture Notes:**
- Weights are stored in basis points (sum should = 10,000 for 100%)
- Governance-controlled routing decisions
- Extend `route-allocation` to fold over a protocol list for N protocols

---

### 2. sBTC Liquidity Backstop
**Shared Reserve for Protocol Stability**

A shared sBTC reserve that authorized DeFi protocols can draw from during stress events. Backstop providers earn fees; protocols pay a draw fee and must repay.

**Key Functions:**
- `provide-liquidity` / `withdraw-liquidity` — depositors earn shares
- `draw-coverage` — registered protocols request emergency liquidity
- `repay-coverage` — protocols return drawn funds
- `shares-to-sbtc` / `sbtc-to-shares` — share pricing math

**Architecture Notes:**
- Share-based accounting means fee accrual auto-increases share value
- Draw fee (50bps default) goes back into reserve, benefiting all depositors
- Per-protocol coverage limits prevent single-protocol drain

---

### 3. CoopCredit
**Reputation-Based Cooperative Credit**

On-chain reputation as collateral. Members build credit scores through repayment history and vouching. Score determines borrow limit.

**Scoring Model:**
```
score = BASE(100) + repayments×10 - defaults×50 + vouches_received×5
borrow_limit = score × 1000 (micro-sBTC)
```

**Key Functions:**
- `join-cooperative` — any address can join (starts at score 100)
- `vouch-for` — members stake their reputation to boost others
- `borrow` / `repay-loan` — credit-gated loans from pool
- `process-default` — governance slashes defaulted borrowers + vouchers

**Architecture Notes:**
- One active loan per member at a time
- Vouchers' reputations are implicitly at risk (extend to explicit slashing)
- Scores are public — transparent community accountability

---

### 4. sBTC Streams
**Programmable Payment Streaming**

Continuous block-by-block sBTC payments. Ideal for payroll, grants, vesting, subscriptions.

**Key Functions:**
- `create-stream` — lock sBTC with a rate-per-block and duration
- `claim` — recipient withdraws accrued sBTC at any time
- `cancel-stream` — sender cancels; unearned deposit refunded
- `settle` — final claim after stream ends
- `claimable-amount` — read-only: how much can recipient claim right now

**Architecture Notes:**
- Rate-per-block pricing means all math is integer arithmetic
- Cancel is clean: recipient keeps earned amount, sender gets refund
- Composable: streams can fund other contracts

---

## Technical Stack

| Layer | Technology |
|-------|-----------|
| Smart Contracts | Clarity (Stacks) |
| Base Asset | sBTC (SIP-010 token) |
| Network | Stacks L2 on Bitcoin |
| Testing | Clarinet (recommended) |
| Frontend | React + Stacks.js (future) |

## Getting Started

```bash
# Install Clarinet
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
cargo install clarinet-cli

# Initialise a new project
clarinet new her-dao-labs
cd her-dao-labs

# Copy contracts into contracts/
# Run tests
clarinet test

# Start local devnet
clarinet devnet start
```

## sBTC Integration

In production contracts, replace all simulated transfer comments with actual SIP-010 calls:

```clarity
;; Deposit sBTC into contract
(try! (contract-call? .sbtc transfer amount tx-sender (as-contract tx-sender) none))

;; Send sBTC from contract to user  
(try! (as-contract (contract-call? .sbtc transfer amount tx-sender recipient none)))
```

The `.sbtc` contract address on mainnet: `SP3DX3H4FEYZJZ586MFBS25ZW3HZDMEW92260R2PR.Wrapped-Bitcoin`

## Design Principles

- **Clarity over cleverness** — code is documentation
- **Fail loudly** — explicit error codes for every failure mode
- **Event logging** — every state change emits a `print` event
- **Modular** — each primitive is independent and composable
- **Upgrade path** — PoC patterns that can evolve to production

## License

MIT — build freely, attribute kindly.

## Contributing

HER DAO Labs welcomes contributors from the Stacks and Bitcoin DeFi communities. Open issues, PRs, and research notes welcome.

---

*Built with love for the Bitcoin DeFi ecosystem.*
