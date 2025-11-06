# 🏠 Blockchain-Enabled Orphanage Fund Management

A decentralized smart contract system built on Stacks for transparent and accountable orphanage fund management. This contract enables secure donation tracking, democratic fund allocation, and comprehensive governance features.

## ✨ Features

- 🏛️ **Orphanage Registration**: Register new orphanages with location and manager details
- 💰 **Secure Donations**: Direct STX donations with complete transparency
- 📊 **Fund Tracking**: Real-time balance monitoring for each orphanage
- 🗳️ **Democratic Governance**: Donor-based voting on fund allocation proposals
- 👥 **Multi-Manager Support**: Transfer management rights between authorized users
- 🚨 **Emergency Controls**: Contract owner emergency withdrawal capabilities
- 📈 **Analytics**: Comprehensive donation statistics and reporting

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Node.js and npm for testing
- Stacks wallet for interactions

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install
   ```
3. Run tests:
   ```bash
   npm test
   ```
4. Check contract:
   ```bash
   clarinet check
   ```

## 📋 Contract Functions

### 🏛️ Orphanage Management

#### `register-orphanage`
Register a new orphanage in the system.

**Parameters:**
- `name` (string-ascii 64): Orphanage name
- `location` (string-ascii 128): Physical location

**Returns:** Orphanage ID (uint)

```clarity
(contract-call? .contract register-orphanage "Hope Children's Home" "123 Main St, City")
```

#### `deactivate-orphanage`
Deactivate an orphanage (manager or contract owner only).

**Parameters:**
- `orphanage-id` (uint): Target orphanage ID

```clarity
(contract-call? .contract deactivate-orphanage u1)
```

#### `transfer-management`
Transfer management rights to a new manager.

**Parameters:**
- `orphanage-id` (uint): Target orphanage ID
- `new-manager` (principal): New manager address

```clarity
(contract-call? .contract transfer-management u1 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

### 💰 Donation System

#### `donate`
Make a donation to a specific orphanage.

**Parameters:**
- `orphanage-id` (uint): Target orphanage ID
- `amount` (uint): Donation amount in microSTX

```clarity
(contract-call? .contract donate u1 u1000000) ;; Donate 1 STX
```

### 🗳️ Governance & Proposals

#### `create-funding-proposal`
Create a funding proposal for an orphanage (manager or owner only).

**Parameters:**
- `orphanage-id` (uint): Target orphanage ID
- `amount` (uint): Requested amount in microSTX
- `purpose` (string-ascii 256): Purpose description

**Returns:** Proposal ID (uint)

```clarity
(contract-call? .contract create-funding-proposal u1 u500000 "School supplies for 50 children")
```

#### `vote-on-proposal`
Vote on a funding proposal (donors only).

**Parameters:**
- `proposal-id` (uint): Target proposal ID
- `vote-for` (bool): true for yes, false for no

```clarity
(contract-call? .contract vote-on-proposal u1 true)
```

#### `execute-proposal`
Execute a passed proposal (manager or owner only).

**Parameters:**
- `proposal-id` (uint): Target proposal ID

```clarity
(contract-call? .contract execute-proposal u1)
```

### 📊 Query Functions

#### `get-orphanage`
Retrieve orphanage information.

```clarity
(contract-call? .contract get-orphanage u1)
```

#### `get-orphanage-balance`
Get current balance for an orphanage.

```clarity
(contract-call? .contract get-orphanage-balance u1)
```

#### `get-donation`
Get donation details for a specific donor-orphanage pair.

```clarity
(contract-call? .contract get-donation 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u1)
```

#### `get-donor-total`
Get total donations by a specific donor.

```clarity
(contract-call? .contract get-donor-total 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
```

#### `get-total-donations`
Get platform-wide total donations.

```clarity
(contract-call? .contract get-total-donations)
```

#### `get-proposal`
Retrieve proposal information.

```clarity
(contract-call? .contract get-proposal u1)
```

## 🔐 Security Features

### Access Control
- **Contract Owner**: Emergency withdrawals and system oversight
- **Orphanage Managers**: Proposal creation and execution
- **Donors**: Voting rights on proposals they've contributed to

### Safeguards
- ✅ Input validation on all parameters
- ✅ Balance checks before fund transfers
- ✅ Voting period enforcement (144 blocks ≈ 24 hours)
- ✅ One vote per donor per proposal
- ✅ Active status verification for donations

## 📈 Workflow Example

1. **Setup Phase** 🏗️
   ```clarity
   ;; Register orphanage
   (contract-call? .contract register-orphanage "Sunshine Orphanage" "456 Oak Ave, Town")
   ```

2. **Donation Phase** 💝
   ```clarity
   ;; Multiple donors contribute
   (contract-call? .contract donate u1 u2000000) ;; 2 STX
   (contract-call? .contract donate u1 u1500000) ;; 1.5 STX
   ```

3. **Proposal Phase** 📋
   ```clarity
   ;; Manager creates funding proposal
   (contract-call? .contract create-funding-proposal u1 u1000000 "Educational materials and books")
   ```

4. **Voting Phase** 🗳️
   ```clarity
   ;; Donors vote on proposal
   (contract-call? .contract vote-on-proposal u1 true)
   ```

5. **Execution Phase** ⚡
   ```clarity
   ;; Manager executes approved proposal
   (contract-call? .contract execute-proposal u1)
   ```

## 🧪 Testing

Run the comprehensive test suite:

```bash
npm test
```

Test coverage includes:
- ✅ Orphanage registration and management
- ✅ Donation processing and tracking
- ✅ Proposal creation and voting
- ✅ Access control and security
- ✅ Error handling and edge cases

## 📊 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | `ERR-NOT-AUTHORIZED` | Insufficient permissions |
| u101 | `ERR-ORPHANAGE-NOT-FOUND` | Invalid orphanage ID |
| u102 | `ERR-INSUFFICIENT-FUNDS` | Not enough balance |
| u103 | `ERR-INVALID-AMOUNT` | Invalid amount parameter |
| u104 | `ERR-ORPHANAGE-EXISTS` | Orphanage already exists |
| u105 | `ERR-INVALID-ORPHANAGE` | Invalid orphanage data |
| u106 | `ERR-PROPOSAL-NOT-FOUND` | Invalid proposal ID |
| u107 | `ERR-ALREADY-VOTED` | User already voted |
| u108 | `ERR-VOTING-ENDED` | Voting period closed |
| u109 | `ERR-PROPOSAL-NOT-PASSED` | Proposal didn't pass |



## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support


---

**Made with 💙 for a better world** 🌍



