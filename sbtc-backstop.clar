;; sBTC Liquidity Backstop — Shared Reserve for Protocol Stability
;; HER DAO Labs | Bitcoin DeFi Infrastructure on Stacks
;;
;; PURPOSE:
;;   A shared sBTC reserve that registered DeFi protocols can draw from
;;   during liquidity stress events. Depositors earn a share of protocol
;;   fees in exchange for providing backstop coverage.
;;
;; MECHANISM:
;;   1. Depositors contribute sBTC to the backstop pool
;;   2. Each depositor receives a proportional "coverage share"
;;   3. Registered protocols can request coverage (up to their limit)
;;   4. Protocols repay draws + a fee; fees accrue to depositors
;;   5. Governance can add/remove authorized protocols
;;
;; NOTE: Proof-of-concept. Not audited. Do not use in production.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u200))
(define-constant ERR-NOT-AUTHORIZED (err u201))
(define-constant ERR-ZERO-AMOUNT (err u202))
(define-constant ERR-INSUFFICIENT-RESERVE (err u203))
(define-constant ERR-EXCEEDS-LIMIT (err u204))
(define-constant ERR-PROTOCOL-NOT-FOUND (err u205))
(define-constant ERR-ALREADY-REGISTERED (err u206))
(define-constant ERR-INSUFFICIENT-BALANCE (err u207))

;; Fee charged on protocol draws, in basis points (e.g. 50 = 0.5%)
(define-constant DRAW-FEE-BPS u50)
(define-constant MAX-BPS u10000)

(define-data-var total-reserve uint u0)
(define-data-var total-shares uint u0)
(define-data-var accumulated-fees uint u0)

;; Depositor positions: user → shares held
(define-map depositor-shares
  { depositor: principal }
  { shares: uint }
)

;; Authorized protocols: protocol-principal → coverage limit + outstanding draws
(define-map authorized-protocols
  { protocol: principal }
  {
    name: (string-ascii 64),
    coverage-limit: uint,   ;; max sBTC this protocol can draw
    outstanding: uint,      ;; current amount drawn and not repaid
    active: bool
  }
)

;; ============================================================
;; Read-Only
;; ============================================================

(define-read-only (get-reserve) (var-get total-reserve))
(define-read-only (get-total-shares) (var-get total-shares))
(define-read-only (get-accumulated-fees) (var-get accumulated-fees))

(define-read-only (get-depositor (depositor principal))
  (default-to { shares: u0 } (map-get? depositor-shares { depositor: depositor }))
)

(define-read-only (get-protocol (protocol principal))
  (map-get? authorized-protocols { protocol: protocol })
)

;; Calculate sBTC value of a depositor's shares
(define-read-only (shares-to-sbtc (shares uint))
  (if (is-eq (var-get total-shares) u0)
    u0
    (/ (* shares (var-get total-reserve)) (var-get total-shares))
  )
)

;; Calculate shares for a given sBTC deposit amount
(define-read-only (sbtc-to-shares (amount uint))
  (if (is-eq (var-get total-reserve) u0)
    amount ;; 1:1 on first deposit
    (/ (* amount (var-get total-shares)) (var-get total-reserve))
  )
)

;; ============================================================
;; Governance: Protocol Registration
;; ============================================================

(define-public (register-protocol
    (protocol principal)
    (name (string-ascii 64))
    (coverage-limit uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (asserts! (is-none (get-protocol protocol)) ERR-ALREADY-REGISTERED)
    (asserts! (> coverage-limit u0) ERR-ZERO-AMOUNT)
    (map-set authorized-protocols
      { protocol: protocol }
      { name: name, coverage-limit: coverage-limit, outstanding: u0, active: true }
    )
    (print { event: "protocol-registered", protocol: protocol, limit: coverage-limit })
    (ok true)
  )
)

(define-public (update-coverage-limit (protocol principal) (new-limit uint))
  (let ((p (unwrap! (get-protocol protocol) ERR-PROTOCOL-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (map-set authorized-protocols { protocol: protocol } (merge p { coverage-limit: new-limit }))
    (ok true)
  )
)

;; ============================================================
;; Depositor: Provide Backstop Liquidity
;; ============================================================

(define-public (provide-liquidity (amount uint))
  (let (
    (caller tx-sender)
    (new-shares (sbtc-to-shares amount))
    (current-shares (get shares (get-depositor caller)))
  )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    ;; Production: (try! (contract-call? .sbtc transfer amount caller (as-contract tx-sender) none))
    (map-set depositor-shares
      { depositor: caller }
      { shares: (+ current-shares new-shares) }
    )
    (var-set total-shares (+ (var-get total-shares) new-shares))
    (var-set total-reserve (+ (var-get total-reserve) amount))
    (print { event: "liquidity-provided", depositor: caller, amount: amount, shares: new-shares })
    (ok new-shares)
  )
)

;; Withdraw liquidity (burn shares → receive proportional sBTC)
(define-public (withdraw-liquidity (shares uint))
  (let (
    (caller tx-sender)
    (current-shares (get shares (get-depositor caller)))
    (sbtc-out (shares-to-sbtc shares))
  )
    (asserts! (> shares u0) ERR-ZERO-AMOUNT)
    (asserts! (>= current-shares shares) ERR-INSUFFICIENT-BALANCE)
    (asserts! (<= sbtc-out (var-get total-reserve)) ERR-INSUFFICIENT-RESERVE)

    (map-set depositor-shares { depositor: caller } { shares: (- current-shares shares) })
    (var-set total-shares (- (var-get total-shares) shares))
    (var-set total-reserve (- (var-get total-reserve) sbtc-out))
    ;; Production: (try! (as-contract (contract-call? .sbtc transfer sbtc-out tx-sender caller none)))
    (print { event: "liquidity-withdrawn", depositor: caller, shares: shares, sbtc: sbtc-out })
    (ok sbtc-out)
  )
)

;; ============================================================
;; Protocol: Draw Coverage
;; ============================================================

(define-public (draw-coverage (amount uint))
  (let (
    (caller tx-sender)
    (p (unwrap! (get-protocol caller) ERR-NOT-AUTHORIZED))
    (new-outstanding (+ (get outstanding p) amount))
    (fee (/ (* amount DRAW-FEE-BPS) MAX-BPS))
  )
    (asserts! (get active p) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (<= new-outstanding (get coverage-limit p)) ERR-EXCEEDS-LIMIT)
    (asserts! (<= amount (var-get total-reserve)) ERR-INSUFFICIENT-RESERVE)

    (map-set authorized-protocols { protocol: caller } (merge p { outstanding: new-outstanding }))
    (var-set total-reserve (- (var-get total-reserve) amount))
    ;; Accrue fee into reserve (increases share value for all depositors)
    (var-set accumulated-fees (+ (var-get accumulated-fees) fee))
    (var-set total-reserve (+ (var-get total-reserve) fee))
    ;; Production: transfer sBTC to caller
    (print { event: "coverage-drawn", protocol: caller, amount: amount, fee: fee })
    (ok amount)
  )
)

;; Protocol repays its draw
(define-public (repay-coverage (amount uint))
  (let (
    (caller tx-sender)
    (p (unwrap! (get-protocol caller) ERR-NOT-AUTHORIZED))
    (repay-amount (min amount (get outstanding p)))
  )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    ;; Production: receive sBTC from protocol
    (map-set authorized-protocols
      { protocol: caller }
      (merge p { outstanding: (- (get outstanding p) repay-amount) })
    )
    (var-set total-reserve (+ (var-get total-reserve) repay-amount))
    (print { event: "coverage-repaid", protocol: caller, amount: repay-amount })
    (ok repay-amount)
  )
)
