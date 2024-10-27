;; Cross-chain Atomic Swap Contract
;; Enables secure token swaps between different blockchain networks

(use-trait fungible-token-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; Error codes
(define-constant ERROR-SWAP-EXPIRED (err u1))
(define-constant ERROR-SWAP-NOT-FOUND (err u2))
(define-constant ERROR-UNAUTHORIZED-ACCESS (err u3))
(define-constant ERROR-SWAP-ALREADY-FINALIZED (err u4))
(define-constant ERROR-INVALID-TOKEN-AMOUNT (err u5))
(define-constant ERROR-INSUFFICIENT-TOKEN-BALANCE (err u6))

;; Data storage
(define-map atomic-swaps
  { atomic-swap-identifier: (buff 32) }
  {
    swap-initiator: principal,
    swap-participant: (optional principal),
    token-contract-principal: principal,
    token-amount: uint,
    atomic-hash-lock: (buff 32),
    swap-expiration-height: uint,
    swap-current-status: (string-ascii 20),
    destination-blockchain: (string-ascii 20),
    destination-wallet-address: (string-ascii 42)
  }
)

(define-data-var atomic-swap-counter uint u0)

;; Read-only functions
(define-read-only (get-atomic-swap-details (atomic-swap-identifier (buff 32)))
  (map-get? atomic-swaps { atomic-swap-identifier: atomic-swap-identifier })
)

(define-read-only (verify-hash-preimage (provided-preimage (buff 32)) (stored-hash (buff 32)))
  (is-eq (sha256 provided-preimage) stored-hash)
)

;; Public functions
(define-public (initialize-atomic-swap 
    (token-contract-principal <fungible-token-trait>)
    (token-amount uint)
    (atomic-hash-lock (buff 32))
    (swap-duration-blocks uint)
    (destination-blockchain (string-ascii 20))
    (destination-wallet-address (string-ascii 42)))
  (let
    (
      (atomic-swap-identifier (generate-atomic-swap-identifier))
      (swap-expiration-height (+ block-height swap-duration-blocks))
      (transaction-sender tx-sender)
    )
    ;; Validate inputs
    (asserts! (> token-amount u0) ERROR-INVALID-TOKEN-AMOUNT)
    (asserts! (> swap-duration-blocks u0) ERROR-INVALID-TOKEN-AMOUNT)
    
    ;; Transfer tokens to contract
    (try! (contract-call? token-contract-principal transfer 
      token-amount
      transaction-sender
      (as-contract tx-sender)
      none))
    
    ;; Create atomic swap record
    (map-set atomic-swaps
      { atomic-swap-identifier: atomic-swap-identifier }
      {
        swap-initiator: transaction-sender,
        swap-participant: none,
        token-contract-principal: (contract-of token-contract-principal),
        token-amount: token-amount,
        atomic-hash-lock: atomic-hash-lock,
        swap-expiration-height: swap-expiration-height,
        swap-current-status: "active",
        destination-blockchain: destination-blockchain,
        destination-wallet-address: destination-wallet-address
      }
    )
    
    ;; Increment atomic swap counter
    (var-set atomic-swap-counter (+ (var-get atomic-swap-counter) u1))
    
    (ok atomic-swap-identifier)
  )
)

(define-public (register-swap-participant
    (atomic-swap-identifier (buff 32)))
  (let
    (
      (swap-details (unwrap! (get-atomic-swap-details atomic-swap-identifier) ERROR-SWAP-NOT-FOUND))
      (transaction-sender tx-sender)
    )
    ;; Validate swap state
    (asserts! (is-eq (get swap-current-status swap-details) "active") ERROR-SWAP-ALREADY-FINALIZED)
    (asserts! (is-none (get swap-participant swap-details)) ERROR-SWAP-ALREADY-FINALIZED)
    
    ;; Update participant
    (map-set atomic-swaps
      { atomic-swap-identifier: atomic-swap-identifier }
      (merge swap-details { 
        swap-participant: (some transaction-sender),
        swap-current-status: "participated"
      })
    )
    
    (ok true)
  )
)

(define-public (redeem-atomic-swap
    (atomic-swap-identifier (buff 32))
    (hash-preimage (buff 32)))
  (let
    (
      (swap-details (unwrap! (get-atomic-swap-details atomic-swap-identifier) ERROR-SWAP-NOT-FOUND))
      (token-contract-principal (get token-contract-principal swap-details))
    )
    ;; Validate swap state
    (asserts! (is-eq (get swap-current-status swap-details) "participated") ERROR-SWAP-ALREADY-FINALIZED)
    (asserts! (< block-height (get swap-expiration-height swap-details)) ERROR-SWAP-EXPIRED)
    (asserts! (verify-hash-preimage hash-preimage (get atomic-hash-lock swap-details)) ERROR-UNAUTHORIZED-ACCESS)
    
    ;; Transfer tokens to participant
    (try! (as-contract (contract-call? (unwrap-panic (contract-call? .fungible-token-trait-interface from-contract token-contract-principal))
      transfer
      (get token-amount swap-details)
      tx-sender
      (unwrap! (get swap-participant swap-details) ERROR-UNAUTHORIZED-ACCESS)
      none)))
    
    ;; Update swap status
    (map-set atomic-swaps
      { atomic-swap-identifier: atomic-swap-identifier }
      (merge swap-details { swap-current-status: "redeemed" })
    )
    
    (ok true)
  )
)

(define-public (process-swap-refund
    (atomic-swap-identifier (buff 32)))
  (let
    (
      (swap-details (unwrap! (get-atomic-swap-details atomic-swap-identifier) ERROR-SWAP-NOT-FOUND))
      (token-contract-principal (get token-contract-principal swap-details))
    )
    ;; Validate swap state
    (asserts! (is-eq (get swap-current-status swap-details) "active") ERROR-SWAP-ALREADY-FINALIZED)
    (asserts! (>= block-height (get swap-expiration-height swap-details)) ERROR-UNAUTHORIZED-ACCESS)
    (asserts! (is-eq tx-sender (get swap-initiator swap-details)) ERROR-UNAUTHORIZED-ACCESS)
    
    ;; Transfer tokens back to initiator
    (try! (as-contract (contract-call? (unwrap-panic (contract-call? .fungible-token-trait-interface from-contract token-contract-principal))
      transfer
      (get token-amount swap-details)
      tx-sender
      (get swap-initiator swap-details)
      none)))
    
    ;; Update swap status
    (map-set atomic-swaps
      { atomic-swap-identifier: atomic-swap-identifier }
      (merge swap-details { swap-current-status: "refunded" })
    )
    
    (ok true)
  )
)

;; Private functions
(define-private (generate-atomic-swap-identifier)
  (sha256 (concat (var-get atomic-swap-counter) block-height))
)