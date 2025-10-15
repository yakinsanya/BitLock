# **BitLock Protocol**

**Transform idle Bitcoin into productive capital through trustless collateralization.**
BitLock enables Bitcoin holders to unlock liquidity without selling their BTC — securely minting stablecoins against their collateral while preserving Bitcoin price exposure. Built on **Stacks**, BitLock leverages Bitcoin’s finality and Clarity’s predictability to deliver institutional-grade, decentralized collateralized lending.

---

## **System Overview**

BitLock introduces a **non-custodial collateralized lending framework** where users can:

1. **Lock BTC as collateral** via Stacks.
2. **Mint stablecoins** proportional to the collateral value.
3. **Repay loans** to unlock collateral at any time.
4. **Rely on automated liquidation safeguards** when positions fall below health thresholds.

The system ensures **protocol solvency and user protection** through algorithmic risk parameters and **on-chain oracles** for real-time BTC price updates.

---

## **Core Features**

* **Trustless BTC Collateralization:**
  BTC holders deposit collateral directly without intermediaries.

* **Stablecoin Liquidity Access:**
  Borrow stable-value tokens pegged to fiat currencies.

* **Algorithmic Risk Management:**
  Health ratios and liquidation thresholds enforced via on-chain logic.

* **Transparent Loan Lifecycle:**
  Each loan, its collateral, and repayment status are publicly auditable.

* **Oracle-Driven Price Feeds:**
  Decentralized price updates for collateral valuation and liquidation.

---

## **Contract Architecture**

### **1. Constants and Error Codes**

Defines all global constants and structured error codes to maintain predictable, self-documenting behavior.

* **Authorization & Validation Errors:** `ERR-NOT-AUTHORIZED`, `ERR-INVALID-AMOUNT`, etc.
* **Loan Operation Errors:** `ERR-LOAN-NOT-FOUND`, `ERR-LOAN-NOT-ACTIVE`.
* **Oracle Errors:** `ERR-INVALID-PRICE`, `ERR-INVALID-ASSET`.

### **2. Data Variables**

| Variable                   | Type   | Description                            |
| -------------------------- | ------ | -------------------------------------- |
| `platform-initialized`     | `bool` | Protocol initialization flag           |
| `minimum-collateral-ratio` | `uint` | Collateral ratio for healthy loans     |
| `liquidation-threshold`    | `uint` | Ratio below which liquidation triggers |
| `platform-fee-rate`        | `uint` | System fee rate (basis points)         |
| `total-btc-locked`         | `uint` | Aggregate BTC collateral               |
| `total-loans-issued`       | `uint` | Total loans created on protocol        |

---

### **3. Data Maps**

| Map                 | Key         | Value                                                                | Description                              |
| ------------------- | ----------- | -------------------------------------------------------------------- | ---------------------------------------- |
| `loans`             | `{loan-id}` | Borrower data, collateral, loan amount, interest, timestamps, status | Tracks all loan positions                |
| `user-loans`        | `{user}`    | Active loan IDs                                                      | Maps users to their active positions     |
| `collateral-prices` | `{asset}`   | Current asset price                                                  | Oracle feed for BTC and supported assets |

---

### **4. Read-Only Functions**

* `get-loan-details(loan-id)` → Loan metadata
* `get-user-loans(user)` → List of user’s active loans
* `get-platform-stats()` → Protocol metrics
* `get-valid-assets()` → Supported collateral assets

---

### **5. Core Functional Logic**

#### **Collateralization**

Users deposit BTC as collateral. Deposits update protocol reserves and track total locked collateral.

```clarity
(deposit-collateral (amount uint))
```

#### **Loan Request**

Validate collateral adequacy using on-chain BTC price and risk parameters. On approval, issue a loan position.

```clarity
(request-loan (collateral uint) (loan-amount uint))
```

#### **Repayment**

Borrowers repay their loans (principal + interest) to unlock their BTC.

```clarity
(repay-loan (loan-id uint) (amount uint))
```

#### **Liquidation**

If collateral ratio falls below the liquidation threshold, the loan is automatically liquidated.

```clarity
(check-liquidation (loan-id uint))
```

---

### **6. Administrative Functions**

| Function                                      | Description                                  |
| --------------------------------------------- | -------------------------------------------- |
| `initialize-platform()`                       | Enables platform initialization (owner only) |
| `update-collateral-ratio(new-ratio)`          | Adjusts collateral requirement               |
| `update-liquidation-threshold(new-threshold)` | Modifies liquidation trigger point           |
| `update-price-feed(asset, new-price)`         | Updates on-chain oracle price feed           |

All admin operations require `CONTRACT-OWNER` authorization.

---

## **System Flow**

1. **Initialization:**
   The platform is initialized once by the contract owner, setting up collateralization parameters.

2. **Collateral Deposit:**
   User deposits BTC → Increases total BTC locked.

3. **Loan Issuance:**
   Loan parameters validated → Loan record created → Stablecoin liquidity issued off-chain or via synthetic minting.

4. **Price Monitoring:**
   Oracle updates BTC price feed → Protocol continuously evaluates loan health.

5. **Liquidation:**
   If `collateral ratio ≤ threshold`, loan auto-liquidates, protecting the system from insolvency.

6. **Repayment & Unlocking:**
   Borrower repays → Loan closed → BTC collateral unlocked.

---

## **Security & Risk Management**

* **Immutable Logic:** All contract operations are on-chain and deterministic.
* **Non-Custodial Ownership:** Users retain full control over their BTC via proof-of-lock.
* **Parameter Governance:** Admin functions restricted to platform owner (upgradeable through future governance).
* **Automatic Safeguards:** Continuous loan health monitoring prevents undercollateralized states.

---

## **Future Extensions**

* **Governance DAO:** Decentralized control over protocol parameters.
* **Multi-Asset Collateral:** Extend beyond BTC and STX.
* **Stability Pool:** Automated liquidation buffer to reduce liquidation volatility.
* **Dynamic Interest Rates:** Real-time adjustments based on utilization metrics.

---

## **Developer Notes**

* **Language:** Clarity v2.0
* **Target Chain:** Stacks (settled on Bitcoin)
* **Contract Type:** Smart contract (decentralized collateralized lending)
* **Primary Modules:** Loan management, Collateral registry, Oracle integration

---

## **Summary**

BitLock Protocol unlocks **Bitcoin-native DeFi liquidity** through a fully transparent, non-custodial lending system.
It combines the **immutability of Bitcoin** with the **programmability of Stacks**, delivering a secure foundation for decentralized collateralized stablecoin issuance.
