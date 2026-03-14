;; sBTC Streams — Programmable Payment Streaming
;; HER DAO Labs | Bitcoin DeFi Infrastructure on Stacks
;;
;; PURPOSE:
;;   Enables continuous, block-by-block payment streaming of sBTC.
;;   Useful for payroll, subscriptions, grants, vesting schedules.
;;   Inspired by Sablier/Superfluid but adapted for Stacks + sBTC.
;;
;; MECHANISM:
;;   - Sender deposits sBTC and defines a stream: recipient, rate, duration
;;   - Each block, (rate × blocks_elapsed) becomes claimable by recipient
;;   - Recipient calls withdraw at any time to claim accrued sBTC
;;   - Sender can cancel early; unclaimed portion returns to sender
;;   - Streams are identified by a monotonically increasing stream-id
;;
;; NOTE: Proof-of-concept. Not audited. Do not use in production.

(define-constant ERR-NOT-SENDER (err u400))
(define-constant ERR-NOT-RECIPIENT (err u401))
(define-constant ERR-STREAM-NOT-FOUND (err u402))
(define-constant ERR-STREAM-ENDED (err u403))
(define-constant ERR-STREAM-CANCELLED (err u404))
(define-constant ERR-ZERO-AMOUNT (err u405))
(define-constant ERR-INVALID-DURATION (err u406))
(define-constant ERR-NOTHING-TO-CLAIM (err u407))
(define-constant ERR-INSUFFICIENT-DEPOSIT (err u408))

(define-data-var stream-nonce uint u0)

;; Stream record
;; rate-per-block is in micro-sBTC (satoshis) per block
(define-map streams
  { stream-id: uint }
  {
    sender: principal,
    recipient: principal,
    deposit: uint,          ;; total sBTC locked
    rate-per-block: uint,   ;; sBTC released per Stacks block
    start-block: uint,
    end-block: uint,
    claimed: uint,          ;; total claimed by recipient so far
    cancelled: bool,
    cancel-block: uint      ;; block when cancelled (0 if not cancelled)
  }
)

;; ============================================================
;; Read-Only
;; ============================================================

(define-read-only (get-stream (stream-id uint))
  (map-get? streams { stream-id: stream-id })
)

(define-read-only (get-stream-count) (var-get stream-nonce))

;; Compute how much a recipient can currently claim from a stream
(define-read-only (claimable-amount (stream-id uint))
  (match (get-stream stream-id)
    s (let (
        ;; If cancelled, stream ends at cancel-block; else at end-block
        (effective-end (if (get cancelled s) (get cancel-block s) (get end-block s)))
        ;; Current block, clamped to effective-end
        (current (if (>= block-height effective-end) effective-end block-height))
        ;; Elapsed blocks since stream started
        (elapsed (if (>= current (get start-block s))
                   (- current (get start-block s))
                   u0))
        ;; Total earned so far (capped at deposit)
        (earned (min (* (get rate-per-block s) elapsed) (get deposit s)))
        ;; Subtract already-claimed amount
        (unclaimed (if (>= earned (get claimed s))
                     (- earned (get claimed s))
                     u0))
      )
      (ok unclaimed)
    )
    (err ERR-STREAM-NOT-FOUND)
  )
)

;; Compute remaining sendable balance (deposit minus earned-to-date)
(define-read-only (sender-balance (stream-id uint))
  (match (get-stream stream-id)
    s (let (
        (effective-end (if (get cancelled s) (get cancel-block s) (get end-block s)))
        (current (if (>= block-height effective-end) effective-end block-height))
        (elapsed (if (>= current (get start-block s)) (- current (get start-block s)) u0))
        (earned (min (* (get rate-per-block s) elapsed) (get deposit s)))
      )
      (ok (if (>= (get deposit s) earned) (- (get deposit s) earned) u0))
    )
    (err ERR-STREAM-NOT-FOUND)
  )
)

;; ============================================================
;; Create Stream
;; ============================================================

(define-public (create-stream
    (recipient principal)
    (deposit uint)
    (rate-per-block uint)
    (duration-blocks uint))
  (let (
    (sender tx-sender)
    (stream-id (var-get stream-nonce))
    (start block-height)
    (end-blk (+ block-height duration-blocks))
    ;; Validate: deposit must cover entire duration at given rate
    (required-deposit (* rate-per-block duration-blocks))
  )
    (asserts! (> deposit u0) ERR-ZERO-AMOUNT)
    (asserts! (> rate-per-block u0) ERR-ZERO-AMOUNT)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    (asserts! (>= deposit required-deposit) ERR-INSUFFICIENT-DEPOSIT)

    ;; Production: (try! (contract-call? .sbtc transfer deposit sender (as-contract tx-sender) none))

    (map-set streams
      { stream-id: stream-id }
      {
        sender: sender,
        recipient: recipient,
        deposit: deposit,
        rate-per-block: rate-per-block,
        start-block: start,
        end-block: end-blk,
        claimed: u0,
        cancelled: false,
        cancel-block: u0
      }
    )

    (var-set stream-nonce (+ stream-id u1))

    (print {
      event: "stream-created",
      stream-id: stream-id,
      sender: sender,
      recipient: recipient,
      deposit: deposit,
      rate-per-block: rate-per-block,
      end-block: end-blk
    })

    (ok stream-id)
  )
)

;; ============================================================
;; Claim (Recipient withdraws accrued sBTC)
;; ============================================================

(define-public (claim (stream-id uint))
  (let (
    (caller tx-sender)
    (s (unwrap! (get-stream stream-id) ERR-STREAM-NOT-FOUND))
    (amount (unwrap! (claimable-amount stream-id) ERR-STREAM-NOT-FOUND))
  )
    (asserts! (is-eq caller (get recipient s)) ERR-NOT-RECIPIENT)
    (asserts! (not (get cancelled s)) ERR-STREAM-CANCELLED)
    (asserts! (> amount u0) ERR-NOTHING-TO-CLAIM)

    ;; Update claimed amount
    (map-set streams
      { stream-id: stream-id }
      (merge s { claimed: (+ (get claimed s) amount) })
    )

    ;; Production: (try! (as-contract (contract-call? .sbtc transfer amount tx-sender caller none)))

    (print { event: "claimed", stream-id: stream-id, recipient: caller, amount: amount })
    (ok amount)
  )
)

;; ============================================================
;; Cancel (Sender cancels stream, recovers unearned deposit)
;;
;; Recipient retains their earned-but-unclaimed balance.
;; Sender recovers everything after the cancel block.
;; ============================================================

(define-public (cancel-stream (stream-id uint))
  (let (
    (caller tx-sender)
    (s (unwrap! (get-stream stream-id) ERR-STREAM-NOT-FOUND))
  )
    (asserts! (is-eq caller (get sender s)) ERR-NOT-SENDER)
    (asserts! (not (get cancelled s)) ERR-STREAM-CANCELLED)
    (asserts! (< block-height (get end-block s)) ERR-STREAM-ENDED)

    ;; Mark cancelled at current block
    (map-set streams
      { stream-id: stream-id }
      (merge s { cancelled: true, cancel-block: block-height })
    )

    ;; Compute refund for sender (deposit minus everything earned up to now)
    (let (
      (elapsed (- block-height (get start-block s)))
      (earned (min (* (get rate-per-block s) elapsed) (get deposit s)))
      (refund (if (>= (get deposit s) earned) (- (get deposit s) earned) u0))
    )
      ;; Production: transfer refund to sender
      ;; (try! (as-contract (contract-call? .sbtc transfer refund tx-sender caller none)))

      (print { event: "stream-cancelled", stream-id: stream-id, sender: caller, refund: refund })
      (ok refund)
    )
  )
)

;; ============================================================
;; Settle (claim remaining after stream ends naturally)
;; ============================================================

(define-public (settle (stream-id uint))
  (let (
    (caller tx-sender)
    (s (unwrap! (get-stream stream-id) ERR-STREAM-NOT-FOUND))
    (amount (unwrap! (claimable-amount stream-id) ERR-STREAM-NOT-FOUND))
  )
    (asserts! (is-eq caller (get recipient s)) ERR-NOT-RECIPIENT)
    (asserts! (>= block-height (get end-block s)) ERR-STREAM-NOT-FOUND)
    (asserts! (> amount u0) ERR-NOTHING-TO-CLAIM)

    (map-set streams
      { stream-id: stream-id }
      (merge s { claimed: (+ (get claimed s) amount) })
    )

    ;; Production: transfer to recipient
    (print { event: "settled", stream-id: stream-id, recipient: caller, amount: amount })
    (ok amount)
  )
)
