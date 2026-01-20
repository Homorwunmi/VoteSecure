# VoteSecure - National Election Smart Contract

A comprehensive blockchain-based voting system for national elections built on the Stacks blockchain using Clarity. VoteSecure maintains voter privacy while ensuring vote integrity and public verifiability.

## Features

### 🔒 Privacy-Preserving
- **Anonymous Voting**: Votes are submitted with cryptographic hashes, separating voter identity from vote content
- **Vote Receipts**: Voters receive anonymous receipts to verify their vote was counted
- **No Vote Content Storage**: Actual vote choices are never stored on-chain, only vote counts

### ✅ Vote Integrity
- **One Vote Per Person**: Smart contract enforces single vote per registered voter
- **Immutable Records**: All votes are permanently recorded on the blockchain
- **Tamper-Proof**: Blockchain technology prevents vote manipulation

### 🔍 Public Verifiability
- **Transparent Results**: Anyone can verify election results
- **Audit Trail**: Complete history of all election activities
- **Real-time Monitoring**: Public can observe vote counts as they happen

## Architecture

### Data Structures

**Candidates**
```clarity
{
  name: string-ascii 50,
  party: string-ascii 50,
  vote-count: uint,
  active: bool
}
```

**Voter Registry**
```clarity
{
  registered: bool,
  voted: bool,
  vote-hash: optional (buff 32)
}
```

**Vote Receipts**
```clarity
{
  voter-hash: buff 32,
  timestamp: uint,
  block-height: uint
}
```

## Election Workflow

### 1. Setup Phase
1. Contract owner initializes election with name and block height range
2. Add election officials who can manage the election
3. Register candidates with their names and party affiliations

### 2. Registration Phase
1. Open voter registration
2. Voters register themselves on-chain
3. Close registration before election starts

### 3. Voting Phase
1. Start election (automatically enforced by start block height)
2. Registered voters cast votes with cryptographic hashes
3. System records votes and issues anonymous receipts

### 4. Results Phase
1. End election (automatically enforced by end block height)
2. Results become publicly available
3. Anyone can verify final vote counts

## Functions Reference

### Election Management (Owner/Officials Only)

#### `initialize-election`
```clarity
(initialize-election (name (string-ascii 100)) (start uint) (end uint))
```
Sets up a new election with name and block height timeframe.

#### `add-election-official`
```clarity
(add-election-official (official principal))
```
Authorizes an address as election official.

#### `open-registration` / `close-registration`
Opens or closes voter registration period.

#### `start-election` / `end-election`
Activates or deactivates the voting period.

### Candidate Management (Owner/Officials Only)

#### `register-candidate`
```clarity
(register-candidate (name (string-ascii 50)) (party (string-ascii 50)))
```
Registers a new candidate. Returns candidate ID.

#### `deactivate-candidate`
```clarity
(deactivate-candidate (candidate-id uint))
```
Removes a candidate from the election.

### Voter Functions

#### `register-voter`
```clarity
(register-voter)
```
Registers the transaction sender as an eligible voter.

#### `cast-vote`
```clarity
(cast-vote (candidate-id uint) (vote-hash (buff 32)))
```
Submits a vote for a candidate with cryptographic hash for privacy. Returns receipt ID.

**Vote Hash**: Generate a unique hash off-chain combining:
- Voter's choice
- Random salt/nonce
- Timestamp

Example (pseudo-code):
```javascript
voteHash = sha256(candidateId + voterSecret + timestamp)
```

### Read-Only Functions

#### `get-election-status`
Returns current election state including name, active status, and vote counts.

#### `get-candidate`
```clarity
(get-candidate (candidate-id uint))
```
Retrieves candidate information and vote count.

#### `get-voter-status`
```clarity
(get-voter-status (voter principal))
```
Checks if an address is registered and has voted (without revealing vote choice).

#### `get-vote-receipt`
```clarity
(get-vote-receipt (receipt-id uint))
```
Retrieves anonymous vote receipt details.

#### `has-voted`
```clarity
(has-voted (voter principal))
```
Returns true if address has cast a vote.

#### `is-registered`
```clarity
(is-registered (voter principal))
```
Returns true if address is registered to vote.

#### `get-results`
```clarity
(get-results (candidate-id uint))
```
Returns final results (only available after election ends).

## Security Considerations

### Privacy Protection
- Votes are submitted with hashes, not actual choices
- Vote receipts use hashes to prevent linking votes to voters
- No direct mapping between voter addresses and candidate choices

### Access Control
- Election management restricted to contract owner and authorized officials
- Voters can only vote once and only if registered
- Results only accessible after election ends

### Time-Based Controls
- Elections automatically enforce start/end times via block heights
- Registration must close before voting begins
- Results only available after voting ends

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| u100 | err-owner-only | Action requires contract owner |
| u101 | err-not-authorized | Caller not authorized |
| u102 | err-election-not-active | Election is not currently active |
| u103 | err-already-voted | Voter has already cast a vote |
| u104 | err-invalid-candidate | Candidate ID does not exist |
| u105 | err-election-ended | Election has already ended |
| u106 | err-election-not-ended | Election still in progress |
| u107 | err-not-registered | Voter is not registered |
| u108 | err-already-registered | Voter already registered |

## Deployment Guide

### Prerequisites
- Clarinet CLI installed
- Stacks blockchain node access
- STX tokens for deployment

### Steps

1. **Initialize Clarinet Project**
```bash
clarinet new national-election
cd national-election
```

2. **Add Contract**
```bash
# Copy VoteSecure.clar to contracts/ directory
```

3. **Test Contract**
```bash
clarinet check
clarinet test
```

4. **Deploy to Testnet**
```bash
clarinet deploy --testnet
```

5. **Deploy to Mainnet**
```bash
clarinet deploy --mainnet
```

## Usage Example

### Setup Election
```clarity
;; Initialize election for blocks 1000-2000
(contract-call? .VoteSecure initialize-election "2026 Presidential Election" u1000 u2000)

;; Add election official
(contract-call? .VoteSecure add-election-official 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Register candidates
(contract-call? .VoteSecure register-candidate "Alice Johnson" "Progressive Party")
(contract-call? .VoteSecure register-candidate "Bob Smith" "Conservative Party")
```

### Voter Registration
```clarity
;; Open registration
(contract-call? .VoteSecure open-registration)

;; Voters register (called by each voter)
(contract-call? .VoteSecure register-voter)

;; Close registration
(contract-call? .VoteSecure close-registration)
```

### Voting
```clarity
;; Start election (at or after block 1000)
(contract-call? .VoteSecure start-election)

;; Cast vote (each voter generates their own hash off-chain)
(contract-call? .VoteSecure cast-vote u1 0x1234567890abcdef...)

;; End election (at or after block 2000)
(contract-call? .VoteSecure end-election)
```

### View Results
```clarity
;; Get election status
(contract-call? .VoteSecure get-election-status)

;; Get candidate results
(contract-call? .VoteSecure get-results u1)
(contract-call? .VoteSecure get-results u2)
```

## Best Practices

### For Election Administrators
1. Set realistic block height ranges (consider ~10 min per block)
2. Test thoroughly on testnet before mainnet deployment
3. Keep multiple election officials for redundancy
4. Announce block heights publicly before election
5. Monitor election progress in real-time

### For Voters
1. Generate strong, unique vote hashes off-chain
2. Store your vote hash securely to verify your vote later
3. Keep your receipt ID to prove you voted
4. Verify your vote was counted after election ends

### For Developers
1. Implement off-chain vote hash generation with proper randomness
2. Build user-friendly interfaces for vote verification
3. Create monitoring dashboards for election transparency
4. Implement backup systems for vote hash storage
5. Conduct security audits before production use

## Limitations

- **Block Height Timing**: Block times vary, so exact start/end times cannot be guaranteed
- **Hash Management**: Voters must manage vote hashes off-chain
- **No Vote Changes**: Once cast, votes cannot be modified
- **Registration Required**: Voters must register before voting period
- **Single Election**: Each contract instance handles one election

## Future Enhancements

Potential improvements for future versions:
- Multi-election support within single contract
- Delegated voting mechanisms
- Weighted voting systems
- District/constituency-based voting
- Voter identity verification integration
- Mobile wallet integration
- Automated election scheduling

## Contributing

Contributions are welcome! Please consider:
- Security improvements
- Gas optimization
- Additional verification methods
- Enhanced privacy features
- Better error handling

## Disclaimer

This smart contract is provided as-is for educational and demonstration purposes. Any use in actual elections should undergo thorough security audits and legal review. The authors are not responsible for any issues arising from production use.

## Support

For issues, questions, or contributions:
- Review the code in `contracts/VoteSecure.clar`
- Test thoroughly before deployment
- Consider professional security audit for production use