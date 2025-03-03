;; StoryWeave Contract
;; Enables collaborative storytelling through NFTs and voting

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-content (err u104))
(define-constant err-self-vote (err u105))
(define-constant err-story-complete (err u106))
(define-constant max-contributions-per-story u100)

;; Data Variables
(define-data-var next-story-id uint u1)
(define-data-var next-contribution-id uint u1)

;; Story NFT
(define-non-fungible-token story uint)

;; Data Maps
(define-map stories uint {
    title: (string-utf8 100),
    creator: principal,
    active: bool,
    contributions: uint,
    created-at: uint,
    is-complete: bool
})

(define-map contributions uint {
    story-id: uint,
    author: principal,
    content: (string-utf8 1000),
    votes: uint,
    timestamp: uint
})

(define-map story-contributors (tuple (story-id uint) (user principal)) uint)
(define-map user-votes (tuple (contribution-id uint) (voter principal)) bool)

;; Helper functions
(define-private (is-valid-content (content (string-utf8 1000)))
    (and 
        (not (is-eq (len content) u0))
        (<= (len content) u1000)
    )
)

(define-private (can-contribute (story-id uint))
    (let ((story (unwrap! (map-get? stories story-id) false)))
        (and 
            (get active story)
            (not (get is-complete story))
            (< (get contributions story) max-contributions-per-story)
        )
    )
)

;; Events
(define-public (print-story-created (story-id uint) (creator principal))
    (ok (print { type: "story-created", story-id: story-id, creator: creator }))
)

(define-public (print-contribution-added (contribution-id uint) (story-id uint) (author principal))
    (ok (print { type: "contribution-added", contribution-id: contribution-id, story-id: story-id, author: author }))
)

;; Create new story
(define-public (create-story (title (string-utf8 100)))
    (let 
        ((story-id (var-get next-story-id)))
        (asserts! (is-valid-content title) err-invalid-content)
        (try! (nft-mint? story story-id tx-sender))
        (map-set stories story-id {
            title: title,
            creator: tx-sender,
            active: true,
            contributions: u0,
            created-at: block-height,
            is-complete: false
        })
        (var-set next-story-id (+ story-id u1))
        (try! (print-story-created story-id tx-sender))
        (ok story-id)
    )
)

;; Add contribution to story
(define-public (add-contribution (story-id uint) (content (string-utf8 1000)))
    (let 
        ((contribution-id (var-get next-contribution-id))
         (story (unwrap! (map-get? stories story-id) err-not-found)))
        (asserts! (can-contribute story-id) err-unauthorized)
        (asserts! (is-valid-content content) err-invalid-content)
        (map-set contributions contribution-id {
            story-id: story-id,
            author: tx-sender,
            content: content,
            votes: u0,
            timestamp: block-height
        })
        (map-set story-contributors {story-id: story-id, user: tx-sender} contribution-id)
        (map-set stories story-id 
            (merge story {contributions: (+ (get contributions story) u1)}))
        (var-set next-contribution-id (+ contribution-id u1))
        (try! (print-contribution-added contribution-id story-id tx-sender))
        (ok contribution-id)
    )
)

;; Complete story
(define-public (complete-story (story-id uint))
    (let ((story (unwrap! (map-get? stories story-id) err-not-found)))
        (asserts! (is-eq (get creator story) tx-sender) err-unauthorized)
        (asserts! (not (get is-complete story)) err-already-exists)
        (map-set stories story-id 
            (merge story {is-complete: true, active: false}))
        (ok true)
    )
)

;; Vote on contribution
(define-public (vote-contribution (contribution-id uint))
    (let 
        ((contribution (unwrap! (map-get? contributions contribution-id) err-not-found))
         (story (unwrap! (map-get? stories (get story-id contribution)) err-not-found))
         (vote-key {contribution-id: contribution-id, voter: tx-sender}))
        (asserts! (not (get is-complete story)) err-story-complete)
        (asserts! (not (is-eq tx-sender (get author contribution))) err-self-vote)
        (asserts! (is-none (map-get? user-votes vote-key)) err-already-exists)
        (map-set user-votes vote-key true)
        (map-set contributions contribution-id 
            (merge contribution {votes: (+ (get votes contribution) u1)}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-story (story-id uint))
    (ok (unwrap! (map-get? stories story-id) err-not-found))
)

(define-read-only (get-contribution (contribution-id uint))
    (ok (unwrap! (map-get? contributions contribution-id) err-not-found))
)

(define-read-only (get-story-contributions (story-id uint))
    (ok (unwrap! (map-get? stories story-id) err-not-found))
)

(define-read-only (has-voted (contribution-id uint) (user principal))
    (is-some (map-get? user-votes {contribution-id: contribution-id, voter: user}))
)
