# AgAu: A Peer-to-Peer Assurance Contract for Gold and Silver Reserves

**Thierry Arys Ruiz**
i@7ei.ai

---

## Abstract

A purely on-chain assurance mechanism that solves the trust problem of collective fundraising. Contributors send ETH to a smart contract. If the target amount is reached before the deadline, funds are released to a multisig treasury and contributors receive tokens proportional to their contribution. If the target is not reached, contributors withdraw their full amount. No intermediary can prevent either outcome. The contract enforces two possible states and only two: success with proportional issuance, or failure with full refund.

---

## 1. The Problem

A group of strangers wants to pool capital to acquire physical gold and silver. Each individual faces a dilemma: if they contribute and others don't, their money is stuck. If they don't contribute, the reserves are never built.

Traditional solutions require trust in a central party to hold funds and honour refund promises. This trust has been broken repeatedly throughout financial history.

We need a system where the rules are enforced by code, not by promises.

---

## 2. The Mechanism

The system consists of two contracts deployed on Ethereum:

**AgAuSale** — the escrow that holds ETH and enforces the rules.
**AgAuShare** — the ERC-20 token representing proportional ownership.

### 2.1 Parameters

The contract is initialised with three immutable values:

| Parameter | Description |
|-----------|-------------|
| `guardian` | The address of the SAFE multisig (`0x58E76A7473dB06dA9e0639bb3d05E9124a540937`) |
| `target` | The ETH amount required for success |
| `deadline` | November 5, 2026 00:00 UTC (Unix: `1793923200`) |

These values cannot be changed after deployment. They are constants of the system.

### 2.2 Contribution

Any Ethereum address can send ETH to the contract before the deadline. The contract records the sender's address and the amount. Multiple contributions from the same address are summed.

```
contributions[sender] += msg.value
totalContributed += msg.value
```

### 2.3 Two Outcomes

The contract has exactly two terminal states. No third state exists.

**State A — Success:**
If `totalContributed >= target` before the deadline, the guardian calls `declareSuccess()`. This is irreversible. The contract enters the success state.

After success:
- `releaseFunds()` sends all ETH to the guardian (SAFE multisig).
- Each contributor calls `claimTokens()` to receive AGAU tokens equal to their contribution in wei.

**State B — Refund:**
If the deadline passes and `declareSuccess()` was never called, each contributor calls `refund()` to withdraw exactly what they deposited.

```
If succeeded:
    contributor receives (contribution / totalContributed) share of token supply
If not succeeded and past deadline:
    contributor receives contribution back in full
```

### 2.4 Proportionality

Token distribution is proportional by construction. The total token supply equals `totalContributed`. Each contributor receives tokens equal to their contribution. Therefore:

```
share_i = contribution_i / totalContributed
```

A contributor who provides 1% of the total receives 1% of the tokens. This is arithmetic, not policy.

---

## 3. The Three Commandments

These are not encoded in the smart contract. They are encoded in the structure of the system itself.

**I. The non-for-profit proceeds shall benefit organic Humans.**
The contract has no fee. No party extracts value from contributions. The SAFE multisig is governed by a Swiss non-profit foundation. The physical gold and silver purchased with the proceeds back the token 1:1.

**II. The New Financial System shall be regulated Democratically by Humans with constitutional protections to Minorities.**
Token holders govern the DAO. No wallet can be frozen by governance vote. No minority can be excluded. The AGAU token is the vote.

**III. The 2 Commandments above shall never be broken.**
The contract is immutable. There is no upgrade mechanism, no admin key, no pause function. The rules are set at deployment and cannot be changed.

---

## 4. Security Properties

**No rug pull.** The guardian cannot withdraw funds unless the target is met and success is declared. There is no emergency withdrawal function. There is no owner override.

**No stuck funds.** If the deadline passes without success, every contributor can withdraw. The refund function has no access control — any contributor can call it for themselves.

**No inflation.** AGAU tokens are only minted when a contributor claims after success. The total supply is fixed at the total ETH contributed. No future minting is possible — the mint function can only be called by the sale contract.

**No reentrancy.** State changes occur before external calls. The OpenZeppelin ReentrancyGuard provides defense in depth.

---

## 5. The Target

| Metal | Amount | Purpose |
|-------|--------|---------|
| Silver (₳g) | 77,000,000 oz | 1:1 backing for ₳g tokens |
| Gold (₳u) | 7 metric tons | 1:1 backing for ₳u tokens |

The ETH target is set to the equivalent value at deployment, based on the price of gold, silver, and ETH on April 1, 2026.

---

## 6. Timeline

```
April 1, 2026      Contract deployed. Contributions open.
                    Price lock for gold/silver targets.

April 1 –          Collection period. 7 months, 5 days.
November 5, 2026

November 5, 2026   Deadline.
                    If target met: guardian declares success.
                      → Funds released to SAFE.
                      → Contributors claim AGAU tokens.
                    If target not met: refunds open.
                      → Each contributor withdraws their ETH.
```

---

## 7. Contract Addresses

| Contract | Description |
|----------|-------------|
| `AgAuSale` | The escrow. Holds ETH. Enforces rules. |
| `AgAuShare` | ERC-20 token. Deployed by AgAuSale constructor. |
| SAFE Multisig | `0x58E76A7473dB06dA9e0639bb3d05E9124a540937` |

Deployed addresses will be published after deployment on April 1, 2026.

---

## 8. Deployment

```solidity
new AgAuSale(
    0x58E76A7473dB06dA9e0639bb3d05E9124a540937,  // guardian (SAFE)
    TARGET_IN_WEI,                                 // target
    1793923200                                     // Nov 5, 2026 00:00 UTC
);
```

That's it. One transaction. Two contracts. Two outcomes. No trust required.

---

## References

1. Ethereum Yellow Paper. G. Wood, 2014.
2. ERC-20 Token Standard. Ethereum EIP-20.
3. Gnosis Safe. Multi-signature wallet.
4. AgAu.io. Swiss gold/silver tokenisation, 2018.

---

*"I believe that God has a very Mexican Sense of Humour." — Arturito7Ei*
