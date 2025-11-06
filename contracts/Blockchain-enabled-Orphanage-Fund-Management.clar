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
(define-constant ERR-BADGE-NOT-EARNED (err u110))
(define-constant ERR-BADGE-ALREADY-CLAIMED (err u111))

(define-data-var next-orphanage-id uint u1)
(define-data-var next-proposal-id uint u1)
(define-data-var total-donations uint u0)
(define-data-var next-badge-id uint u1)
(define-data-var next-receipt-id uint u1)

(define-non-fungible-token donation-receipt uint)

(define-map donation-receipts
    uint
    {
        donor: principal,
        orphanage-id: uint,
        amount: uint,
        timestamp: uint,
    }
)

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

;; Donor Recognition System Maps
(define-map donor-badges
    {
        donor: principal,
        badge-type: (string-ascii 32),
    }
    {
        badge-id: uint,
        earned-at: uint,
        claimed: bool,
        badge-value: uint,
    }
)

(define-map badge-definitions
    (string-ascii 32)
    {
        min-donation: uint,
        badge-name: (string-ascii 64),
        description: (string-ascii 128),
        reward-multiplier: uint,
    }
)

(define-map donor-recognition-stats
    principal
    {
        total-badges: uint,
        highest-badge-tier: uint,
        recognition-score: uint,
        vip-status: bool,
    }
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

(define-read-only (get-receipt (receipt-id uint))
    (let (
            (owner (nft-get-owner? donation-receipt receipt-id))
            (meta (map-get? donation-receipts receipt-id))
        )
        (match owner
            owner-p
                (match meta
                    m (some {
                        owner: owner-p,
                        orphanage-id: (get orphanage-id m),
                        amount: (get amount m),
                        timestamp: (get timestamp m),
                    })
                    none
                )
            none
        )
    )
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

;; Donor Recognition System Read-Only Functions
(define-read-only (get-donor-badge
        (donor principal)
        (badge-type (string-ascii 32))
    )
    (map-get? donor-badges {
        donor: donor,
        badge-type: badge-type,
    })
)

(define-read-only (get-badge-definition (badge-type (string-ascii 32)))
    (map-get? badge-definitions badge-type)
)

(define-read-only (get-donor-recognition-stats (donor principal))
    (map-get? donor-recognition-stats donor)
)

(define-read-only (is-vip-donor (donor principal))
    (match (map-get? donor-recognition-stats donor)
        stats (get vip-status stats)
        false
    )
)

(define-read-only (calculate-recognition-score (donor principal))
    (let (
            (total-donated (get-donor-total donor))
            (stats (map-get? donor-recognition-stats donor))
        )
        (match stats
            recognition-data (+ (get recognition-score recognition-data) 
                               (* total-donated u10))
            (* total-donated u10)
        )
    )
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
        (let ((rid (var-get next-receipt-id)))
            (try! (nft-mint? donation-receipt rid tx-sender))
            (map-set donation-receipts rid {
                donor: tx-sender,
                orphanage-id: orphanage-id,
                amount: amount,
                timestamp: current-block,
            })
            (var-set next-receipt-id (+ rid u1))
        )
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

;; Donor Recognition System Public Functions
(define-public (initialize-badge-system)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        ;; Bronze Badge - 1000 STX minimum
        (map-set badge-definitions "bronze" {
            min-donation: u1000000,
            badge-name: "Bronze Supporter",
            description: "Donated 1000+ STX to orphanages",
            reward-multiplier: u110,
        })
        ;; Silver Badge - 5000 STX minimum
        (map-set badge-definitions "silver" {
            min-donation: u5000000,
            badge-name: "Silver Guardian",
            description: "Donated 5000+ STX to orphanages",
            reward-multiplier: u125,
        })
        ;; Gold Badge - 10000 STX minimum
        (map-set badge-definitions "gold" {
            min-donation: u10000000,
            badge-name: "Gold Champion",
            description: "Donated 10000+ STX to orphanages",
            reward-multiplier: u150,
        })
        ;; Platinum Badge - 25000 STX minimum
        (map-set badge-definitions "platinum" {
            min-donation: u25000000,
            badge-name: "Platinum Hero",
            description: "Donated 25000+ STX to orphanages",
            reward-multiplier: u200,
        })
        (ok true)
    )
)

(define-public (check-and-award-badges (donor principal))
    (let (
            (total-donated (get-donor-total donor))
            (current-stats (map-get? donor-recognition-stats donor))
            (current-block burn-block-height)
            (badge-id (var-get next-badge-id))
        )
        (begin
            ;; Check for Platinum badge (highest tier)
            (if (>= total-donated u25000000)
                (if (unwrap-panic (award-badge-if-new donor "platinum" badge-id current-block u4))
                    (var-set next-badge-id (+ badge-id u1))
                    true
                )
                ;; Check for Gold badge
                (if (>= total-donated u10000000)
                    (if (unwrap-panic (award-badge-if-new donor "gold" badge-id current-block u3))
                        (var-set next-badge-id (+ badge-id u1))
                        true
                    )
                    ;; Check for Silver badge
                    (if (>= total-donated u5000000)
                        (if (unwrap-panic (award-badge-if-new donor "silver" badge-id current-block u2))
                            (var-set next-badge-id (+ badge-id u1))
                            true
                        )
                        ;; Check for Bronze badge
                        (if (>= total-donated u1000000)
                            (if (unwrap-panic (award-badge-if-new donor "bronze" badge-id current-block u1))
                                (var-set next-badge-id (+ badge-id u1))
                                true
                            )
                            true
                        )
                    )
                )
            )
            (unwrap-panic (update-recognition-stats donor))
            (ok true)
        )
    )
)

(define-private (award-badge-if-new
        (donor principal)
        (badge-type (string-ascii 32))
        (badge-id uint)
        (current-block uint)
        (tier uint)
    )
    (let ((existing-badge (get-donor-badge donor badge-type)))
        (if (is-none existing-badge)
            (begin
                (map-set donor-badges {
                    donor: donor,
                    badge-type: badge-type,
                } {
                    badge-id: badge-id,
                    earned-at: current-block,
                    claimed: false,
                    badge-value: tier,
                })
                (ok true)
            )
            (ok false)
        )
    )
)

(define-private (update-recognition-stats (donor principal))
    (let (
            (total-donated (get-donor-total donor))
            (current-stats (map-get? donor-recognition-stats donor))
            (recognition-score (calculate-recognition-score donor))
            (badge-count (count-donor-badges donor))
            (highest-tier (get-highest-badge-tier donor))
            (is-vip (>= total-donated u25000000))
        )
        (map-set donor-recognition-stats donor {
            total-badges: badge-count,
            highest-badge-tier: highest-tier,
            recognition-score: recognition-score,
            vip-status: is-vip,
        })
        (ok true)
    )
)

(define-private (count-donor-badges (donor principal))
    (let (
            (bronze (get-donor-badge donor "bronze"))
            (silver (get-donor-badge donor "silver"))
            (gold (get-donor-badge donor "gold"))
            (platinum (get-donor-badge donor "platinum"))
        )
        (+ (if (is-some bronze) u1 u0)
           (if (is-some silver) u1 u0)
           (if (is-some gold) u1 u0)
           (if (is-some platinum) u1 u0))
    )
)

(define-private (get-highest-badge-tier (donor principal))
    (let (
            (bronze (get-donor-badge donor "bronze"))
            (silver (get-donor-badge donor "silver"))
            (gold (get-donor-badge donor "gold"))
            (platinum (get-donor-badge donor "platinum"))
        )
        (if (is-some platinum) u4
            (if (is-some gold) u3
                (if (is-some silver) u2
                    (if (is-some bronze) u1 u0))))
    )
)

(define-public (claim-badge-benefits
        (badge-type (string-ascii 32))
    )
    (let (
            (badge (unwrap! (get-donor-badge tx-sender badge-type) ERR-BADGE-NOT-EARNED))
            (badge-def (unwrap! (get-badge-definition badge-type) ERR-BADGE-NOT-EARNED))
        )
        (asserts! (not (get claimed badge)) ERR-BADGE-ALREADY-CLAIMED)
        (map-set donor-badges {
            donor: tx-sender,
            badge-type: badge-type,
        }
            (merge badge { claimed: true })
        )
        (ok {
            badge-name: (get badge-name badge-def),
            reward-multiplier: (get reward-multiplier badge-def),
            badge-tier: (get badge-value badge),
        })
    )
)
