;; Mock sBTC Token — SIP-010 Fungible Token for Local Testing
;; HER DAO Labs | Bitcoin Capital Markets Lab
;;
;; Deploy this first before the other contracts.
;; Call (mint u1000000 tx-sender) to fund test wallets.

(impl-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u1000))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))

(define-fungible-token mock-sbtc)

(define-public (transfer (amount uint) (sender principal) (recipient principal) (memo (optional (buff 34))))
  (begin
    (asserts! (is-eq tx-sender sender) (err u1003))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (try! (ft-transfer? mock-sbtc amount sender recipient))
    (match memo m (print m) true)
    (ok true)
  )
)

(define-read-only (get-name) (ok "Mock sBTC"))
(define-read-only (get-symbol) (ok "msBTC"))
(define-read-only (get-decimals) (ok u8))
(define-read-only (get-balance (owner principal))
  (ok (ft-get-balance mock-sbtc owner))
)
(define-read-only (get-total-supply)
  (ok (ft-get-supply mock-sbtc))
)
(define-read-only (get-token-uri)
  (ok (some u"https://herdaolabs.xyz/mock-sbtc.json"))
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-mint? mock-sbtc amount recipient)
  )
)

(define-public (burn (amount uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender owner) (err u1004))
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (ft-burn? mock-sbtc amount owner)
  )
)
