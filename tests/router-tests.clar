;; sBTC Router — Clarity Unit Tests
;; HER DAO Labs | Bitcoin Capital Markets Lab

(define-public (test-register-protocol)
  (let (
    (result (contract-call? .sbtc-router register-protocol
      "test-protocol"
      'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM
      u5000))
  )
    (asserts! (is-ok result) (err "register-protocol should succeed for owner"))
    (asserts! (is-eq result (ok u0)) (err "first protocol should have id 0"))
    (ok true)
  )
)

(define-public (test-deposit)
  (let (
    (deposit-result (contract-call? .sbtc-router deposit u500000))
    (balance (contract-call? .sbtc-router get-user-deposit tx-sender))
  )
    (asserts! (is-ok deposit-result) (err "deposit should succeed"))
    (asserts! (is-eq (get amount balance) u500000) (err "balance should equal deposit"))
    (ok true)
  )
)

(define-public (test-withdraw)
  (begin
    (try! (contract-call? .sbtc-router deposit u1000000))
    (let (
      (withdraw-result (contract-call? .sbtc-router withdraw u400000))
      (balance (contract-call? .sbtc-router get-user-deposit tx-sender))
    )
      (asserts! (is-ok withdraw-result) (err "withdraw should succeed"))
      (asserts! (is-eq (get amount balance) u600000) (err "balance should be 600000"))
      (ok true)
    )
  )
)

(define-public (test-withdraw-overdraft)
  (begin
    (try! (contract-call? .sbtc-router deposit u100))
    (let ((result (contract-call? .sbtc-router withdraw u999999)))
      (asserts! (is-eq result (err u106)) (err "should return ERR-INSUFFICIENT-BALANCE"))
      (ok true)
    )
  )
)

(define-public (test-zero-deposit)
  (let ((result (contract-call? .sbtc-router deposit u0)))
    (asserts! (is-eq result (err u104)) (err "should return ERR-ZERO-AMOUNT"))
    (ok true)
  )
)
