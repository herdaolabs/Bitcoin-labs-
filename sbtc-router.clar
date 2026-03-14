;; sBTC Router — Capital Allocation Layer
;; HER DAO Labs | Bitcoin DeFi Infrastructure on Stacks
;;
;; PURPOSE:
;;   Routes sBTC liquidity across registered DeFi protocols based on
;;   configurable allocation weights. A governance principal manages
;;   protocol registration and rebalancing triggers.
;;
;; NOTE: Proof-of-concept. Not audited. Do not use in production.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-INVALID-WEIGHT (err u101))
(define-constant ERR-PROTOCOL-NOT-FOUND (err u102))
(define-constant ERR-WEIGHTS-UNBALANCED (err u103))
(define-constant ERR-ZERO-AMOUNT (err u104))
(define-constant ERR-PROTOCOL-EXISTS (err u105))
(define-constant ERR-INSUFFICIENT-BALANCE (err u106))
(define-constant MAX-BPS u10000)

(define-data-var total-deposited uint u0)
(define-data-var protocol-count uint u0)

(define-map protocols
  { protocol-id: uint }
  {
    name: (string-ascii 64),
    contract: principal,
    weight-bps: uint,
    allocated: uint,
    active: bool
  }
)

(define-map user-deposits
  { user: principal }
  { amount: uint }
)

(define-read-only (get-protocol (protocol-id uint))
  (map-get? protocols { protocol-id: protocol-id })
)

(define-read-only (get-user-deposit (user principal))
  (default-to { amount: u0 } (map-get? user-deposits { user: user }))
)

(define-read-only (get-total-deposited) (var-get total-deposited))
(define-read-only (get-protocol-count) (var-get protocol-count))
(define-read-only (is-owner (caller principal)) (is-eq caller CONTRACT-OWNER))

(define-public (register-protocol (name (string-ascii 64)) (contract principal) (weight-bps uint))
  (let ((pid (var-get protocol-count)))
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (> weight-bps u0) ERR-INVALID-WEIGHT)
    (asserts! (<= weight-bps MAX-BPS) ERR-INVALID-WEIGHT)
    (map-set protocols { protocol-id: pid }
      { name: name, contract: contract, weight-bps: weight-bps, allocated: u0, active: true })
    (var-set protocol-count (+ pid u1))
    (ok pid)
  )
)

(define-public (update-weight (protocol-id uint) (new-weight-bps uint))
  (let ((protocol (unwrap! (get-protocol protocol-id) ERR-PROTOCOL-NOT-FOUND)))
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (<= new-weight-bps MAX-BPS) ERR-INVALID-WEIGHT)
    (map-set protocols { protocol-id: protocol-id } (merge protocol { weight-bps: new-weight-bps }))
    (ok true)
  )
)

(define-public (deactivate-protocol (protocol-id uint))
  (let ((protocol (unwrap! (get-protocol protocol-id) ERR-PROTOCOL-NOT-FOUND)))
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (map-set protocols { protocol-id: protocol-id } (merge protocol { active: false }))
    (ok true)
  )
)

;; Deposit sBTC into router (simulated — no SIP-010 call in PoC)
(define-public (deposit (amount uint))
  (let ((caller tx-sender)
        (current-deposit (get amount (get-user-deposit caller))))
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    ;; Production: (try! (contract-call? .sbtc transfer amount caller (as-contract tx-sender) none))
    (map-set user-deposits { user: caller } { amount: (+ current-deposit amount) })
    (var-set total-deposited (+ (var-get total-deposited) amount))
    (print { event: "deposit", user: caller, amount: amount })
    (ok amount)
  )
)

;; Route allocation proportionally to protocol 0 (extend to fold over list in production)
(define-public (route-allocation (total-amount uint))
  (begin
    (asserts! (is-owner tx-sender) ERR-NOT-OWNER)
    (asserts! (> total-amount u0) ERR-ZERO-AMOUNT)
    (match (get-protocol u0)
      protocol (let ((alloc (/ (* total-amount (get weight-bps protocol)) MAX-BPS)))
        (map-set protocols { protocol-id: u0 } (merge protocol { allocated: (+ (get allocated protocol) alloc) }))
        (print { event: "route", protocol-id: u0, allocated: alloc })
        (ok alloc)
      )
      ERR-PROTOCOL-NOT-FOUND
    )
  )
)

(define-public (withdraw (amount uint))
  (let ((caller tx-sender)
        (current-deposit (get amount (get-user-deposit caller))))
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (>= current-deposit amount) ERR-INSUFFICIENT-BALANCE)
    (map-set user-deposits { user: caller } { amount: (- current-deposit amount) })
    (var-set total-deposited (- (var-get total-deposited) amount))
    ;; Production: (try! (as-contract (contract-call? .sbtc transfer amount tx-sender caller none)))
    (print { event: "withdraw", user: caller, amount: amount })
    (ok amount)
  )
)
