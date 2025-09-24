(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ORPHANAGE-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-FUNDS (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ORPHANAGE-EXISTS (err u104))
(define-constant ERR-INVALID-ORPHANAGE (err u105))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u106))
(define-constant ERR-ALREADY-VOTED (err u107))
(define-constant ERR-VOTING-ENDED (err u108))
(define-constant ERR-PROPOSAL-NOT-PASSED (err u109))

(define-data-var next-orphanage-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-donations uint u0)

(define-map orphanages
    uint
    {
        name: (string-ascii 64),
        manager: principal,
        total-received: uint,
        active: bool,
        location: (string-ascii 128),
        created-at: uint,
    }
)

(define-map donations
    {
        donor: principal,
        orphanage-id: uint,
    }
    {
        amount: uint,
        timestamp: uint,
    }
)

(define-map donor-totals
    principal
    uint
)

(define-map orphanage-balances
    uint
    uint
)

(define-map funding-proposals
    uint
    {
        orphanage-id: uint,
        amount: uint,
        purpose: (string-ascii 256),
        proposer: principal,
        votes-for: uint,
        votes-against: uint,
        voting-ends: uint,
        executed: bool,
    }
)

(define-map proposal-votes
    {
        proposal-id: uint,
        voter: principal,
    }
    bool
)

(define-map authorized-managers
    principal
    bool
)

(define-read-only (get-orphanage (orphanage-id uint))
    (map-get? orphanages orphanage-id)
)

(define-read-only (get-orphanage-balance (orphanage-id uint))
    (default-to u0 (map-get? orphanage-balances orphanage-id))
)

(define-read-only (get-donation
        (donor principal)
        (orphanage-id uint)
    )
    (map-get? donations {
        donor: donor,
        orphanage-id: orphanage-id,
    })
)

(define-read-only (get-donor-total (donor principal))
    (default-to u0 (map-get? donor-totals donor))
)

(define-read-only (get-total-donations)
    (var-get total-donations)
)

(define-read-only (get-proposal (proposal-id uint))
    (map-get? funding-proposals proposal-id)
)

(define-read-only (get-vote
        (proposal-id uint)
        (voter principal)
    )
    (map-get? proposal-votes {
        proposal-id: proposal-id,
        voter: voter,
    })
)

(define-read-only (is-authorized-manager (manager principal))
    (default-to false (map-get? authorized-managers manager))
)

(define-public (register-orphanage
        (name (string-ascii 64))
        (location (string-ascii 128))
    )
    (let (
            (orphanage-id (var-get next-orphanage-id))
            (current-block burn-block-height)
        )
        (asserts! (> (len name) u0) ERR-INVALID-ORPHANAGE)
        (asserts! (> (len location) u0) ERR-INVALID-ORPHANAGE)
        (map-set orphanages orphanage-id {
            name: name,
            manager: tx-sender,
            total-received: u0,
            active: true,
            location: location,
            created-at: current-block,
        })
        (map-set authorized-managers tx-sender true)
        (map-set orphanage-balances orphanage-id u0)
        (var-set next-orphanage-id (+ orphanage-id u1))
        (ok orphanage-id)
    )
)

(define-public (donate
        (orphanage-id uint)
        (amount uint)
    )
    (let (
            (orphanage (unwrap! (map-get? orphanages orphanage-id) ERR-ORPHANAGE-NOT-FOUND))
            (current-balance (get-orphanage-balance orphanage-id))
            (current-total (get-donor-total tx-sender))
            (current-block burn-block-height)
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (get active orphanage) ERR-INVALID-ORPHANAGE)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set donations {
            donor: tx-sender,
            orphanage-id: orphanage-id,
        } {
            amount: (+ amount
                (default-to u0
                    (get amount
                        (map-get? donations {
                            donor: tx-sender,
                            orphanage-id: orphanage-id,
                        })
                    ))
            ),
            timestamp: current-block,
        })
        (map-set orphanage-balances orphanage-id (+ current-balance amount))
        (map-set donor-totals tx-sender (+ current-total amount))
        (map-set orphanages orphanage-id
            (merge orphanage { total-received: (+ (get total-received orphanage) amount) })
        )
        (var-set total-donations (+ (var-get total-donations) amount))
        (ok true)
    )
)

(define-public (create-funding-proposal
        (orphanage-id uint)
        (amount uint)
        (purpose (string-ascii 256))
    )
    (let (
            (proposal-id (var-get next-proposal-id))
            (orphanage (unwrap! (map-get? orphanages orphanage-id) ERR-ORPHANAGE-NOT-FOUND))
            (current-block burn-block-height)
        )
        (asserts!
            (or (is-eq tx-sender (get manager orphanage)) (is-eq tx-sender CONTRACT-OWNER))
            ERR-NOT-AUTHORIZED
        )
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        (asserts! (<= amount (get-orphanage-balance orphanage-id))
            ERR-INSUFFICIENT-FUNDS
        )
        (asserts! (> (len purpose) u0) ERR-INVALID-AMOUNT)
        (map-set funding-proposals proposal-id {
            orphanage-id: orphanage-id,
            amount: amount,
            purpose: purpose,
            proposer: tx-sender,
            votes-for: u0,
            votes-against: u0,
            voting-ends: (+ current-block u144),
            executed: false,
        })
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (vote-on-proposal
        (proposal-id uint)
        (vote-for bool)
    )
    (let (
            (proposal (unwrap! (map-get? funding-proposals proposal-id)
                ERR-PROPOSAL-NOT-FOUND
            ))
            (current-block burn-block-height)
            (voter-donation-key {
                donor: tx-sender,
                orphanage-id: (get orphanage-id proposal),
            })
            (voter-donation (map-get? donations voter-donation-key))
        )
        (asserts! (is-some voter-donation) ERR-NOT-AUTHORIZED)
        (asserts! (< current-block (get voting-ends proposal)) ERR-VOTING-ENDED)
        (asserts!
            (is-none (map-get? proposal-votes {
                proposal-id: proposal-id,
                voter: tx-sender,
            }))
            ERR-ALREADY-VOTED
        )
        (map-set proposal-votes {
            proposal-id: proposal-id,
            voter: tx-sender,
        }
            vote-for
        )
        (if vote-for
            (map-set funding-proposals proposal-id
                (merge proposal { votes-for: (+ (get votes-for proposal) u1) })
            )
            (map-set funding-proposals proposal-id
                (merge proposal { votes-against: (+ (get votes-against proposal) u1) })
            )
        )
        (ok true)
    )
)

(define-public (execute-proposal (proposal-id uint))
    (let (
            (proposal (unwrap! (map-get? funding-proposals proposal-id)
                ERR-PROPOSAL-NOT-FOUND
            ))
            (orphanage (unwrap! (map-get? orphanages (get orphanage-id proposal))
                ERR-ORPHANAGE-NOT-FOUND
            ))
            (current-block burn-block-height)
            (current-balance (get-orphanage-balance (get orphanage-id proposal)))
        )
        (asserts! (>= current-block (get voting-ends proposal)) ERR-VOTING-ENDED)
        (asserts! (not (get executed proposal)) ERR-PROPOSAL-NOT-FOUND)
        (asserts! (> (get votes-for proposal) (get votes-against proposal))
            ERR-PROPOSAL-NOT-PASSED
        )
        (asserts!
            (or (is-eq tx-sender (get manager orphanage)) (is-eq tx-sender CONTRACT-OWNER))
            ERR-NOT-AUTHORIZED
        )
        (try! (as-contract (stx-transfer? (get amount proposal) tx-sender (get manager orphanage))))
        (map-set orphanage-balances (get orphanage-id proposal)
            (- current-balance (get amount proposal))
        )
        (map-set funding-proposals proposal-id
            (merge proposal { executed: true })
        )
        (ok true)
    )
)

(define-public (deactivate-orphanage (orphanage-id uint))
    (let ((orphanage (unwrap! (map-get? orphanages orphanage-id) ERR-ORPHANAGE-NOT-FOUND)))
        (asserts!
            (or (is-eq tx-sender (get manager orphanage)) (is-eq tx-sender CONTRACT-OWNER))
            ERR-NOT-AUTHORIZED
        )
        (map-set orphanages orphanage-id (merge orphanage { active: false }))
        (ok true)
    )
)

(define-public (transfer-management
        (orphanage-id uint)
        (new-manager principal)
    )
    (let ((orphanage (unwrap! (map-get? orphanages orphanage-id) ERR-ORPHANAGE-NOT-FOUND)))
        (asserts! (is-eq tx-sender (get manager orphanage)) ERR-NOT-AUTHORIZED)
        (map-set orphanages orphanage-id
            (merge orphanage { manager: new-manager })
        )
        (map-set authorized-managers new-manager true)
        (ok true)
    )
)

(define-public (emergency-withdraw
        (orphanage-id uint)
        (amount uint)
    )
    (let (
            (orphanage (unwrap! (map-get? orphanages orphanage-id) ERR-ORPHANAGE-NOT-FOUND))
            (current-balance (get-orphanage-balance orphanage-id))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount current-balance) ERR-INSUFFICIENT-FUNDS)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
        (map-set orphanage-balances orphanage-id (- current-balance amount))
        (ok true)
    )
)
