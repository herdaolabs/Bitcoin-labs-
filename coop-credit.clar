;; CoopCredit — Reputation-Based Cooperative Credit Primitive
;; HER DAO Labs | Bitcoin DeFi Infrastructure on Stacks
;;
;; PURPOSE:
;;   Explores on-chain reputation as collateral. Members build
;;   credit scores through verified activity (repayments, vouches,
;;   on-chain history). Credit score unlocks access to undercollateralized
;;   loans from a cooperative lending pool.
;;
;; DESIGN:
;;   - Members join a cooperative credit union
;;   - Score = base + repayment_bonus - default_penalty + vouch_weight
;;   - Score determines max borrow limit (score × multiplier)
;;   - Other members can vouch for applicants (stake their own score)
;;   - Defaults slash both borrower and vouchers' scores
;;
;; NOTE: Proof-of-concept. Not audited. Do not use in production.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u300))
(define-constant ERR-NOT-MEMBER (err u301))
(define-constant ERR-ALREADY-MEMBER (err u302))
(define-constant ERR-INSUFFICIENT-SCORE (err u303))
(define-constant ERR-ZERO-AMOUNT (err u304))
(define-constant ERR-EXCEEDS-LIMIT (err u305))
(define-constant ERR-NO-ACTIVE-LOAN (err u306))
(define-constant ERR-ALREADY-VOUCHED (err u307))
(define-constant ERR-CANNOT-VOUCH-SELF (err u308))
(define-constant ERR-INSUFFICIENT-POOL (err u309))

;; Credit scoring constants
(define-constant BASE-SCORE u100)
(define-constant REPAYMENT-BONUS u10)
(define-constant DEFAULT-PENALTY u50)
(define-constant VOUCH-WEIGHT u5)
(define-constant MAX-VOUCHES-PER-MEMBER u5)
;; Borrow limit = score × SCORE-MULTIPLIER (in micro-sBTC / satoshis equivalent)
(define-constant SCORE-MULTIPLIER u1000)

(define-data-var pool-balance uint u0)
(define-data-var member-count uint u0)
(define-data-var total-loans-issued uint u0)

;; Member registry
(define-map members
  { member: principal }
  {
    score: uint,
    active-loan: uint,          ;; 0 if no active loan
    loan-count: uint,           ;; total historical loans
    default-count: uint,
    vouches-given: uint,        ;; how many vouches this member has given
    joined-at: uint             ;; block height
  }
)

;; Vouch registry: (voucher, borrower) → vouch-amount
(define-map vouches
  { voucher: principal, borrower: principal }
  { amount: uint, active: bool }
)

;; Loan registry
(define-map loans
  { loan-id: uint }
  {
    borrower: principal,
    amount: uint,
    due-block: uint,            ;; block height when repayment due
    repaid: bool,
    defaulted: bool
  }
)

(define-data-var loan-nonce uint u0)

;; ============================================================
;; Read-Only
;; ============================================================

(define-read-only (get-member (member principal))
  (map-get? members { member: member })
)

(define-read-only (get-loan (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

(define-read-only (get-pool-balance) (var-get pool-balance))

(define-read-only (get-borrow-limit (member principal))
  (match (get-member member)
    m (ok (* (get score m) SCORE-MULTIPLIER))
    (err ERR-NOT-MEMBER)
  )
)

(define-read-only (get-vouch (voucher principal) (borrower principal))
  (map-get? vouches { voucher: voucher, borrower: borrower })
)

(define-read-only (is-member (principal principal))
  (is-some (get-member principal))
)

;; ============================================================
;; Membership
;; ============================================================

(define-public (join-cooperative)
  (let ((caller tx-sender))
    (asserts! (not (is-member caller)) ERR-ALREADY-MEMBER)
    (map-set members
      { member: caller }
      {
        score: BASE-SCORE,
        active-loan: u0,
        loan-count: u0,
        default-count: u0,
        vouches-given: u0,
        joined-at: block-height
      }
    )
    (var-set member-count (+ (var-get member-count) u1))
    (print { event: "member-joined", member: caller, score: BASE-SCORE })
    (ok true)
  )
)

;; ============================================================
;; Pool Funding (Admin / Community)
;; ============================================================

(define-public (fund-pool (amount uint))
  (begin
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    ;; Production: (try! (contract-call? .sbtc transfer amount tx-sender (as-contract tx-sender) none))
    (var-set pool-balance (+ (var-get pool-balance) amount))
    (print { event: "pool-funded", amount: amount, funder: tx-sender })
    (ok true)
  )
)

;; ============================================================
;; Vouching
;; ============================================================

(define-public (vouch-for (borrower principal) (vouch-amount uint))
  (let (
    (voucher tx-sender)
    (voucher-data (unwrap! (get-member voucher) ERR-NOT-MEMBER))
    (borrower-data (unwrap! (get-member borrower) ERR-NOT-MEMBER))
  )
    (asserts! (not (is-eq voucher borrower)) ERR-CANNOT-VOUCH-SELF)
    (asserts! (is-none (get-vouch voucher borrower)) ERR-ALREADY-VOUCHED)
    (asserts! (<= (get vouches-given voucher-data) MAX-VOUCHES-PER-MEMBER) ERR-EXCEEDS-LIMIT)
    (asserts! (> vouch-amount u0) ERR-ZERO-AMOUNT)

    ;; Record vouch
    (map-set vouches
      { voucher: voucher, borrower: borrower }
      { amount: vouch-amount, active: true }
    )

    ;; Increase borrower score for receiving vouch
    (map-set members
      { member: borrower }
      (merge borrower-data { score: (+ (get score borrower-data) VOUCH-WEIGHT) })
    )

    ;; Track vouches given by voucher
    (map-set members
      { member: voucher }
      (merge voucher-data { vouches-given: (+ (get vouches-given voucher-data) u1) })
    )

    (print { event: "vouch-given", voucher: voucher, borrower: borrower, amount: vouch-amount })
    (ok true)
  )
)

;; ============================================================
;; Borrowing
;; ============================================================

(define-public (borrow (amount uint))
  (let (
    (caller tx-sender)
    (m (unwrap! (get-member caller) ERR-NOT-MEMBER))
    (limit (* (get score m) SCORE-MULTIPLIER))
    (loan-id (var-get loan-nonce))
  )
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (is-eq (get active-loan m) u0) ERR-EXCEEDS-LIMIT) ;; one loan at a time
    (asserts! (<= amount limit) ERR-INSUFFICIENT-SCORE)
    (asserts! (<= amount (var-get pool-balance)) ERR-INSUFFICIENT-POOL)

    ;; Create loan record (due in ~144 blocks ≈ 1 day on Stacks)
    (map-set loans
      { loan-id: loan-id }
      {
        borrower: caller,
        amount: amount,
        due-block: (+ block-height u144),
        repaid: false,
        defaulted: false
      }
    )

    ;; Update member state
    (map-set members
      { member: caller }
      (merge m { active-loan: loan-id, loan-count: (+ (get loan-count m) u1) })
    )

    (var-set pool-balance (- (var-get pool-balance) amount))
    (var-set loan-nonce (+ loan-id u1))
    (var-set total-loans-issued (+ (var-get total-loans-issued) u1))

    ;; Production: transfer sBTC to borrower
    (print { event: "loan-issued", borrower: caller, amount: amount, loan-id: loan-id })
    (ok loan-id)
  )
)

;; ============================================================
;; Repayment
;; ============================================================

(define-public (repay-loan (loan-id uint))
  (let (
    (caller tx-sender)
    (loan (unwrap! (get-loan loan-id) ERR-NO-ACTIVE-LOAN))
    (m (unwrap! (get-member caller) ERR-NOT-MEMBER))
  )
    (asserts! (is-eq (get borrower loan) caller) ERR-NOT-MEMBER)
    (asserts! (not (get repaid loan)) ERR-NO-ACTIVE-LOAN)

    ;; Mark loan repaid
    (map-set loans { loan-id: loan-id } (merge loan { repaid: true }))

    ;; Reward: increase credit score
    (map-set members
      { member: caller }
      (merge m {
        score: (+ (get score m) REPAYMENT-BONUS),
        active-loan: u0
      })
    )

    ;; Return funds to pool
    ;; Production: (try! (contract-call? .sbtc transfer (get amount loan) caller (as-contract tx-sender) none))
    (var-set pool-balance (+ (var-get pool-balance) (get amount loan)))

    (print { event: "loan-repaid", borrower: caller, loan-id: loan-id, new-score: (+ (get score m) REPAYMENT-BONUS) })
    (ok true)
  )
)

;; ============================================================
;; Default Processing (called by governance after due-block passes)
;; ============================================================

(define-public (process-default (loan-id uint))
  (let (
    (loan (unwrap! (get-loan loan-id) ERR-NO-ACTIVE-LOAN))
    (borrower (get borrower loan))
    (m (unwrap! (get-member borrower) ERR-NOT-MEMBER))
  )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (asserts! (not (get repaid loan)) ERR-NO-ACTIVE-LOAN)
    (asserts! (not (get defaulted loan)) ERR-NO-ACTIVE-LOAN)
    (asserts! (>= block-height (get due-block loan)) ERR-NO-ACTIVE-LOAN)

    ;; Mark defaulted
    (map-set loans { loan-id: loan-id } (merge loan { defaulted: true }))

    ;; Slash borrower score
    (map-set members
      { member: borrower }
      (merge m {
        score: (if (>= (get score m) DEFAULT-PENALTY)
                 (- (get score m) DEFAULT-PENALTY)
                 u0),
        default-count: (+ (get default-count m) u1),
        active-loan: u0
      })
    )

    (print { event: "default-processed", borrower: borrower, loan-id: loan-id })
    (ok true)
  )
)
