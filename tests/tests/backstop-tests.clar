;; sBTC Liquidity Backstop — Clarity Unit Tests
;; HER DAO Labs | Bitcoin Capital Markets Lab

(define-public (test-provide-liquidity)
  (let (
    (result (contract-call? .sbtc-backstop provide-liquidity u1000000))
    (shares (contract-call? .sbtc-backstop get-depositor tx-sender))
  )
    (asserts! (is-ok result) (err "provide-liquidity should succeed"))
    (asserts! (is-eq (get shares shares) u1000000) (err "first deposit shares should equal amount"))
    (ok true)
  )
)

(define-public (test-draw-exceeds-limit)
  (begin
    (try! (contract-call? .sbtc-backstop provide-liquidity u1000000))
    (try! (contract-call? .sbtc-backstop register-protocol
      tx-sender "test-protocol" u500))
    (let ((result (contract-call? .sbtc-backstop draw-coverage u600)))
      (asserts! (is-eq result (err u204)) (err "should return ERR-EXCEEDS-LIMIT"))
      (ok true)
    )
  )
)

(define-public (test-zero-liquidity)
  (let ((result (contract-call? .sbtc-backstop provide-liquidity u0)))
    (asserts! (is-eq result (err u202)) (err "should return ERR-ZERO-AMOUNT"))
    (ok true)
  )
)

(define-public (test-share-value)
  (begin
    (try! (contract-call? .sbtc-backstop provide-liquidity u1000000))
    (let (
      (sbtc-value (contract-call? .sbtc-backstop shares-to-sbtc u1000000))
    )
      (asserts! (is-eq sbtc-value u1000000) (err "share value should equal deposit on first mint"))
      (ok true)
    )
  )
)
