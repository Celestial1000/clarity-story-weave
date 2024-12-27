;; StoryWeave Contract
;; Enables collaborative storytelling through NFTs and voting

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))

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
    created-at: uint
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

;; Create new story
(define-public (create-story (title (string-utf8 100)))
    (let 
        ((story-id (var-get next-story-id)))
        (try! (nft-mint? story story-id tx-sender))
        (map-set stories story-id {
            title: title,
            creator: tx-sender,
            active: true,
            contributions: u0,
            created-at: block-height
        })
        (var-set next-story-id (+ story-id u1))
        (ok story-id)
    )
)

;; Add contribution to story
(define-public (add-contribution (story-id uint) (content (string-utf8 1000)))
    (let 
        ((contribution-id (var-get next-contribution-id))
         (story (unwrap! (map-get? stories story-id) err-not-found)))
        (asserts! (get active story) err-unauthorized)
        (map-set contributions contribution-id {
            story-id: story-id,
            author: tx-sender,
            content: content,
            votes: u0,
            timestamp: block-height
        })
        (map-set story-contributors {story-id: story-id, user: tx-sender} contribution-id)
        (var-set next-contribution-id (+ contribution-id u1))
        (ok contribution-id)
    )
)

;; Vote on contribution
(define-public (vote-contribution (contribution-id uint))
    (let 
        ((contribution (unwrap! (map-get? contributions contribution-id) err-not-found))
         (vote-key {contribution-id: contribution-id, voter: tx-sender}))
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
    (ok (map-get? stories story-id))
)

(define-read-only (has-voted (contribution-id uint) (user principal))
    (is-some (map-get? user-votes {contribution-id: contribution-id, voter: user}))
)