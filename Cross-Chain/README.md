# Atomic Cross-Chain Swap Smart Contract

## About
A secure and robust implementation of a cross-chain atomic swap protocol built with Clarity for the Stacks blockchain. This smart contract enables trustless token exchanges between different blockchain networks using Hash Time Locked Contracts (HTLC).

## Features

- **Atomic Swaps**: Guarantees that either both parties receive their tokens or neither does
- **Cross-Chain Compatibility**: Supports token exchanges across different blockchain networks
- **Time-Locked Security**: Implements automatic timeout and refund mechanisms
- **SIP-010 Compliance**: Compatible with standard fungible tokens
- **Comprehensive Error Handling**: Robust error checking and status management
- **Gas Efficient**: Optimized for minimal gas consumption

## Prerequisites

- Clarity CLI tools
- Node.js
- Stacks blockchain development environment
- Understanding of atomic swaps and HTLC concepts

## Contract Architecture

### Core Components

1. **Data Storage**
```clarity
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
```

2. **Main Functions**
- `initialize-atomic-swap`: Create new swap
- `register-swap-participant`: Register counterparty
- `redeem-atomic-swap`: Complete swap with hash preimage
- `process-swap-refund`: Refund after timeout

## Usage

### 1. Initializing a Swap

```clarity
(contract-call? .atomic-cross-chain-swap initialize-atomic-swap
    token-contract
    u1000                ;; amount
    hash-lock
    u144                 ;; 24-hour timeout
    "Ethereum"           ;; destination chain
    "0x1234...5678"     ;; destination address
)
```

### 2. Participating in a Swap

```clarity
(contract-call? .atomic-cross-chain-swap register-swap-participant
    swap-identifier
)
```

### 3. Redeeming a Swap

```clarity
(contract-call? .atomic-cross-chain-swap redeem-atomic-swap
    swap-identifier
    preimage
)
```

### 4. Requesting a Refund

```clarity
(contract-call? .atomic-cross-chain-swap process-swap-refund
    swap-identifier
)
```

## Security Considerations

1. **Time Constraints**
   - Set appropriate timeout periods
   - Consider block time variations between chains

2. **Hash Lock Security**
   - Use cryptographically secure random values
   - Never share preimage before confirming counterparty lock

3. **Token Safety**
   - Verify token contracts
   - Check allowances and balances
   - Use standard token interfaces

## Error Handling

The contract defines several error codes:
```clarity
ERROR-SWAP-EXPIRED             (err u1)
ERROR-SWAP-NOT-FOUND          (err u2)
ERROR-UNAUTHORIZED-ACCESS      (err u3)
ERROR-SWAP-ALREADY-FINALIZED  (err u4)
ERROR-INVALID-TOKEN-AMOUNT    (err u5)
ERROR-INSUFFICIENT-TOKEN-BALANCE (err u6)
```

## Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request