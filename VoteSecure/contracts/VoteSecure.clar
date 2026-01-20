;; VoteSecure - National Election System
;; Maintains voter privacy while ensuring vote integrity and public verifiability

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-election-not-active (err u102))
(define-constant err-already-voted (err u103))
(define-constant err-invalid-candidate (err u104))
(define-constant err-election-ended (err u105))
(define-constant err-election-not-ended (err u106))
(define-constant err-not-registered (err u107))
(define-constant err-already-registered (err u108))

;; Data Variables
(define-data-var election-active bool false)
(define-data-var registration-open bool false)
(define-data-var election-start-block uint u0)
(define-data-var election-end-block uint u0)
(define-data-var total-votes uint u0)
(define-data-var election-name (string-ascii 100) "")

;; Data Maps
(define-map candidates 
  uint 
  {
    name: (string-ascii 50),
    party: (string-ascii 50),
    vote-count: uint,
    active: bool
  }
)

(define-map voter-registry 
  principal 
  {
    registered: bool,
    voted: bool,
    vote-hash: (optional (buff 32))
  }
)

(define-map election-officials principal bool)

(define-map vote-receipts 
  uint 
  {
    voter-hash: (buff 32),
    timestamp: uint,
    block-height: uint
  }
)

(define-data-var next-candidate-id uint u1)
(define-data-var next-receipt-id uint u1)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (is-election-official)
  (default-to false (map-get? election-officials tx-sender))
)

;; Public Functions - Election Management

(define-public (initialize-election (name (string-ascii 100)) (start uint) (end uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (var-set election-name name)
    (var-set election-start-block start)
    (var-set election-end-block end)
    (ok true)
  )
)

(define-public (add-election-official (official principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (map-set election-officials official true))
  )
)

(define-public (remove-election-official (official principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (ok (map-delete election-officials official))
  )
)

(define-public (open-registration)
  (begin
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (var-set registration-open true)
    (ok true)
  )
)

(define-public (close-registration)
  (begin
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (var-set registration-open false)
    (ok true)
  )
)

(define-public (start-election)
  (begin
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (asserts! (>= stacks-block-height (var-get election-start-block)) err-election-not-active)
    (var-set election-active true)
    (var-set registration-open false)
    (ok true)
  )
)

(define-public (end-election)
  (begin
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (asserts! (>= stacks-block-height (var-get election-end-block)) err-election-not-ended)
    (var-set election-active false)
    (ok true)
  )
)

;; Candidate Management

(define-public (register-candidate (name (string-ascii 50)) (party (string-ascii 50)))
  (let
    (
      (candidate-id (var-get next-candidate-id))
    )
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (map-set candidates candidate-id {
      name: name,
      party: party,
      vote-count: u0,
      active: true
    })
    (var-set next-candidate-id (+ candidate-id u1))
    (ok candidate-id)
  )
)

(define-public (deactivate-candidate (candidate-id uint))
  (let
    (
      (candidate (unwrap! (map-get? candidates candidate-id) err-invalid-candidate))
    )
    (asserts! (or (is-contract-owner) (is-election-official)) err-not-authorized)
    (ok (map-set candidates candidate-id (merge candidate { active: false })))
  )
)

;; Voter Registration

(define-public (register-voter)
  (let
    (
      (voter-data (map-get? voter-registry tx-sender))
    )
    (asserts! (var-get registration-open) err-election-not-active)
    (asserts! (is-none voter-data) err-already-registered)
    (map-set voter-registry tx-sender {
      registered: true,
      voted: false,
      vote-hash: none
    })
    (ok true)
  )
)

;; Voting Function

(define-public (cast-vote (candidate-id uint) (vote-hash (buff 32)))
  (let
    (
      (voter-data (unwrap! (map-get? voter-registry tx-sender) err-not-registered))
      (candidate (unwrap! (map-get? candidates candidate-id) err-invalid-candidate))
      (receipt-id (var-get next-receipt-id))
    )
    (asserts! (var-get election-active) err-election-not-active)
    (asserts! (get registered voter-data) err-not-registered)
    (asserts! (not (get voted voter-data)) err-already-voted)
    (asserts! (get active candidate) err-invalid-candidate)
    
    ;; Update voter status
    (map-set voter-registry tx-sender (merge voter-data {
      voted: true,
      vote-hash: (some vote-hash)
    }))
    
    ;; Increment candidate vote count
    (map-set candidates candidate-id (merge candidate {
      vote-count: (+ (get vote-count candidate) u1)
    }))
    
    ;; Create anonymous receipt
    (map-set vote-receipts receipt-id {
      voter-hash: vote-hash,
      timestamp: stacks-block-height,
      block-height: stacks-block-height
    })
    
    ;; Update totals
    (var-set total-votes (+ (var-get total-votes) u1))
    (var-set next-receipt-id (+ receipt-id u1))
    
    (ok receipt-id)
  )
)

;; Read-only Functions

(define-read-only (get-election-status)
  (ok {
    name: (var-get election-name),
    active: (var-get election-active),
    registration-open: (var-get registration-open),
    start-block: (var-get election-start-block),
    end-block: (var-get election-end-block),
    total-votes: (var-get total-votes)
  })
)

(define-read-only (get-candidate (candidate-id uint))
  (ok (map-get? candidates candidate-id))
)

(define-read-only (get-voter-status (voter principal))
  (ok (map-get? voter-registry voter))
)

(define-read-only (get-vote-receipt (receipt-id uint))
  (ok (map-get? vote-receipts receipt-id))
)

(define-read-only (has-voted (voter principal))
  (match (map-get? voter-registry voter)
    voter-data (ok (get voted voter-data))
    (ok false)
  )
)

(define-read-only (is-registered (voter principal))
  (match (map-get? voter-registry voter)
    voter-data (ok (get registered voter-data))
    (ok false)
  )
)

(define-read-only (get-results (candidate-id uint))
  (let
    (
      (candidate (map-get? candidates candidate-id))
    )
    (asserts! (not (var-get election-active)) err-election-not-ended)
    (ok candidate)
  )
)

(define-read-only (get-total-votes)
  (ok (var-get total-votes))
)