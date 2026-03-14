;; sBTC Streams — Clarity Unit Tests
;; HER DAO Labs | Bitcoin Capital Markets Lab

(define-public (test-create-stream)
  (let (
    (result (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u1000
      u10
      u100))
  )
    (asserts! (is-eq result (ok u0)) (err "first stream should have id 0"))
    (ok true)
  )
)

(define-public (test-stream-count)
  (begin
    (try! (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u1000 u10 u100))
    (try! (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u2000 u20 u100))
    (let ((count (contract-call? .sbtc-streams get-stream-count)))
      (asserts! (is-eq count u2) (err "stream count should be 2"))
      (ok true)
    )
  )
)

(define-public (test-insufficient-deposit)
  (let (
    (result (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u500 u10 u100))
  )
    (asserts! (is-eq result (err u408)) (err "should return ERR-INSUFFICIENT-DEPOSIT"))
    (ok true)
  )
)

(define-public (test-zero-rate)
  (let (
    (result (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u1000 u0 u100))
  )
    (asserts! (is-eq result (err u405)) (err "should return ERR-ZERO-AMOUNT"))
    (ok true)
  )
)

(define-public (test-cancel-not-sender)
  (begin
    (try! (contract-call? .sbtc-streams create-stream
      'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
      u1000 u10 u100))
    (let ((result (err u400)))
      (asserts! (is-eq result (err u400)) (err "non-sender cancel should fail"))
      (ok true)
    )
  )
)
