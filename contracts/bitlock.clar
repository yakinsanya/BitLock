;; Title: BitLock Protocol
;;
;; Summary:
;; Transform idle Bitcoin into productive capital through trustless collateralization.
;; Access stablecoin liquidity while preserving Bitcoin holdings and price exposure.
;;
;; Description:
;; BitLock brings institutional-grade collateralized lending to Bitcoin via Stacks.
;; Lock BTC, mint stablecoins against your position, and keep full control of your
;; assets. Algorithmic risk management ensures protocol safety through automated
;; health monitoring and smart liquidation triggers.
;;

;; CONSTANTS & ERROR DEFINITIONS

;; Core protocol constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant VALID-ASSETS (list "BTC" "STX"))

;; Error codes - Authorization & Validation
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-BELOW-MINIMUM (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ALREADY-INITIALIZED (err u104))
(define-constant ERR-NOT-INITIALIZED (err u105))
(define-constant ERR-INVALID-LIQUIDATION (err u106))

;; Error codes - Loan Operations
(define-constant ERR-LOAN-NOT-FOUND (err u107))
(define-constant ERR-LOAN-NOT-ACTIVE (err u108))
(define-constant ERR-INVALID-LOAN-ID (err u109))

;; Error codes - Oracle & Pricing
(define-constant ERR-INVALID-PRICE (err u110))
(define-constant ERR-INVALID-ASSET (err u111))

;; DATA VARIABLES

;; Platform configuration
(define-data-var platform-initialized bool false)
(define-data-var minimum-collateral-ratio uint u150)
(define-data-var liquidation-threshold uint u120)
(define-data-var platform-fee-rate uint u1)

;; Protocol metrics
(define-data-var total-btc-locked uint u0)
(define-data-var total-loans-issued uint u0)

;; DATA MAPS

;; Loan position tracking
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    collateral-amount: uint,
    loan-amount: uint,
    interest-rate: uint,
    start-height: uint,
    last-interest-calc: uint,
    status: (string-ascii 20)
  }
)

;; User loan index
(define-map user-loans
  { user: principal }
  { active-loans: (list 10 uint) }
)

;; Price oracle feeds
(define-map collateral-prices
  { asset: (string-ascii 3) }
  { price: uint }
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-loan-details (loan-id uint))
  (map-get? loans {loan-id: loan-id})
)

(define-read-only (get-user-loans (user principal))
  (map-get? user-loans {user: user})
)

(define-read-only (get-platform-stats)
  {
    total-btc-locked: (var-get total-btc-locked),
    total-loans-issued: (var-get total-loans-issued),
    minimum-collateral-ratio: (var-get minimum-collateral-ratio),
    liquidation-threshold: (var-get liquidation-threshold)
  }
)

(define-read-only (get-valid-assets)
  VALID-ASSETS
)

;; PRIVATE UTILITY FUNCTIONS

(define-private (calculate-collateral-ratio (collateral uint) (loan uint) (btc-price uint))
  (let
    (
      (collateral-value (* collateral btc-price))
      (ratio (* (/ collateral-value loan) u100))
    )
    ratio
  )
)

(define-private (calculate-interest (principal uint) (rate uint) (blocks uint))
  (let
    (
      (interest-per-block (/ (* principal rate) (* u100 u144)))
      (total-interest (* interest-per-block blocks))
    )
    total-interest
  )
)

(define-private (validate-loan-id (loan-id uint))
  (and 
    (> loan-id u0)
    (<= loan-id (var-get total-loans-issued))
  )
)

(define-private (is-valid-asset (asset (string-ascii 3)))
  (is-some (index-of VALID-ASSETS asset))
)

(define-private (is-valid-price (price uint))
  (and 
    (> price u0)
    (<= price u1000000000000)
  )
)

(define-private (not-equal-loan-id (id uint))
  (not (is-eq id id))
)

(define-private (check-liquidation (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans {loan-id: loan-id}) ERR-LOAN-NOT-FOUND))
      (btc-price (unwrap! (get price (map-get? collateral-prices {asset: "BTC"})) ERR-NOT-INITIALIZED))
      (current-ratio (calculate-collateral-ratio (get collateral-amount loan) (get loan-amount loan) btc-price))
    )
    (if (<= current-ratio (var-get liquidation-threshold))
      (liquidate-position loan-id)
      (ok true)
    )
  )
)

(define-private (liquidate-position (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans {loan-id: loan-id}) ERR-LOAN-NOT-FOUND))
      (borrower (get borrower loan))
    )
    (begin
      (map-set loans
        {loan-id: loan-id}
        (merge loan {status: "liquidated"})
      )
      (map-delete user-loans {user: borrower})
      (ok true)
    )
  )
)

;; ADMIN FUNCTIONS

(define-public (initialize-platform)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get platform-initialized)) ERR-ALREADY-INITIALIZED)
    (var-set platform-initialized true)
    (ok true)
  )
)

(define-public (update-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-ratio u110) ERR-INVALID-AMOUNT)
    (var-set minimum-collateral-ratio new-ratio)
    (ok true)
  )
)

(define-public (update-liquidation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-threshold u110) ERR-INVALID-AMOUNT)
    (var-set liquidation-threshold new-threshold)
    (ok true)
  )
)

(define-public (update-price-feed (asset (string-ascii 3)) (new-price uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-asset asset) ERR-INVALID-ASSET)
    (asserts! (is-valid-price new-price) ERR-INVALID-PRICE)
    
    (ok (map-set collateral-prices
      {asset: asset}
      {price: new-price}
    ))
  )
)

;; CORE PROTOCOL FUNCTIONS

(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (var-set total-btc-locked (+ (var-get total-btc-locked) amount))
    (ok true)
  )
)

(define-public (request-loan (collateral uint) (loan-amount uint))
  (let
    (
      (btc-price (unwrap! (get price (map-get? collateral-prices {asset: "BTC"})) ERR-NOT-INITIALIZED))
      (collateral-value (* collateral btc-price))
      (required-collateral (* loan-amount (var-get minimum-collateral-ratio)))
      (loan-id (+ (var-get total-loans-issued) u1))
    )
    (begin
      (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
      (asserts! (>= collateral-value required-collateral) ERR-INSUFFICIENT-COLLATERAL)
      
      (map-set loans
        {loan-id: loan-id}
        {
          borrower: tx-sender,
          collateral-amount: collateral,
          loan-amount: loan-amount,
          interest-rate: u5,
          start-height: stacks-block-height,
          last-interest-calc: stacks-block-height,
          status: "active"
        }
      )
      
      (match (map-get? user-loans {user: tx-sender})
        existing-loans (map-set user-loans
          {user: tx-sender}
          {active-loans: (unwrap! (as-max-len? (append (get active-loans existing-loans) loan-id) u10) ERR-INVALID-AMOUNT)}
        )
        (map-set user-loans
          {user: tx-sender}
          {active-loans: (list loan-id)}
        )
      )
      
      (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
      (ok loan-id)
    )
  )
)

(define-public (repay-loan (loan-id uint) (amount uint))
  (begin
    (asserts! (validate-loan-id loan-id) ERR-INVALID-LOAN-ID)
    
    (let
      (
        (loan (unwrap! (map-get? loans {loan-id: loan-id}) ERR-LOAN-NOT-FOUND))
        (interest-owed (calculate-interest 
          (get loan-amount loan)
          (get interest-rate loan)
          (- stacks-block-height (get last-interest-calc loan))
        ))
        (total-owed (+ (get loan-amount loan) interest-owed))
      )
      (begin
        (asserts! (is-eq (get status loan) "active") ERR-LOAN-NOT-ACTIVE)
        (asserts! (is-eq (get borrower loan) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount total-owed) ERR-INVALID-AMOUNT)
        
        (map-set loans
          {loan-id: loan-id}
          (merge loan {
            status: "repaid",
            last-interest-calc: stacks-block-height
          })
        )
        
        (var-set total-btc-locked (- (var-get total-btc-locked) (get collateral-amount loan)))
        
        (match (map-get? user-loans {user: tx-sender})
          existing-loans (ok (map-set user-loans
            {user: tx-sender}
            {active-loans: (filter not-equal-loan-id (get active-loans existing-loans))}
          ))
          (ok false)
        )
      )
    )
  )
)