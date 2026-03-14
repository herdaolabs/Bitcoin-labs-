;; CoopCredit — Clarity Unit Tests
;; HER DAO Labs | Bitcoin Capital Markets Lab

(define-public (test-join-cooperative)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (let (
      (member (contract-call? .coop-credit get-member tx-sender))
    )
      (asserts! (is-some member) (err "member should exist after joining"))
      (asserts! (is-eq (get score (unwrap-panic member)) u100)
        (err "base score should be 100"))
      (ok true)
    )
  )
)

(define-public (test-join-twice)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (let ((result (contract-call? .coop-credit join-cooperative)))
      (asserts! (is-eq result (err u302)) (err "should return ERR-ALREADY-MEMBER"))
      (ok true)
    )
  )
)

(define-public (test-borrow-within-limit)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (try! (contract-call? .coop-credit fund-pool u500000))
    (let ((result (contract-call? .coop-credit borrow u50000)))
      (asserts! (is-ok result) (err "borrow within limit should succeed"))
      (ok true)
    )
  )
)

(define-public (test-borrow-exceeds-limit)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (try! (contract-call? .coop-credit fund-pool u999999))
    (let ((result (contract-call? .coop-credit borrow u200000)))
      (asserts! (is-eq result (err u303)) (err "should return ERR-INSUFFICIENT-SCORE"))
      (ok true)
    )
  )
)

(define-public (test-repayment-increases-score)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (try! (contract-call? .coop-credit fund-pool u500000))
    (let ((loan-id (unwrap-panic (contract-call? .coop-credit borrow u10000))))
      (try! (contract-call? .coop-credit repay-loan loan-id))
      (let (
        (member (unwrap-panic (contract-call? .coop-credit get-member tx-sender)))
      )
        (asserts! (is-eq (get score member) u110)
          (err "score should increase by 10 after repayment"))
        (ok true)
      )
    )
  )
)

(define-public (test-no-self-vouch)
  (begin
    (try! (contract-call? .coop-credit join-cooperative))
    (let ((result (contract-call? .coop-credit vouch-for tx-sender u10)))
      (asserts! (is-eq result (err u308)) (err "should return ERR-CANNOT-VOUCH-SELF"))
      (ok true)
    )
  )
)
