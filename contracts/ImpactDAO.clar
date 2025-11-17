;; ImpactDAO - Community impact tracking and verification system
;; Contributors earn impact tokens for verified community contributions and initiatives

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_DUPLICATE_VERIFICATION (err u105))
(define-constant ERR_SELF_VERIFICATION (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_IMPACT_SCORE (err u108))
(define-constant ERR_INVALID_INITIATIVE_ID (err u109))
(define-constant ERR_EMPTY_DETAILS (err u110))

;; Constants
(define-constant MAX_IMPACT_SCORE u5)
(define-constant VERIFICATION_TOKENS u13)
(define-constant INITIATIVE_BONUS u40)
(define-constant COMMUNITY_LEADER_THRESHOLD u120)

;; Data maps
(define-map contributors
  { contributor-id: principal }
  { display-name: (string-ascii 50), cause: (string-ascii 20), impact-points: uint, tokens: uint, leader: bool }
)

(define-map initiatives
  { initiative-id: uint }
  { 
    creator: principal, 
    initiative-name: (string-ascii 50), 
    impact-details: (buff 32),
    created-at: uint, 
    verified: bool,
    verification-count: uint,
    supporter-count: uint,
    impact-rating: uint,
    rating-count: uint
  }
)

(define-map initiative-verifications
  { initiative-id: uint, verifier: principal }
  { verified: bool }
)

(define-map initiative-support
  { initiative-id: uint, supporter: principal }
  { support-level: uint, supported-at: uint }
)

(define-map impact-scores
  { initiative-id: uint, scorer: principal }
  { score: uint }
)

;; Variables
(define-data-var next-initiative-id uint u1)
(define-data-var activity-log uint u0)

;; Helper functions
(define-private (is-valid-initiative-id (initiative-id uint))
  (< initiative-id (var-get next-initiative-id))
)

;; Contributor functions
(define-public (register-contributor (display-name (string-ascii 50)) (cause (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len display-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq cause "environment") (is-eq cause "education") (is-eq cause "health")) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? contributors {contributor-id: caller})) ERR_ALREADY_EXISTS)
    (ok (map-set contributors 
      {contributor-id: caller} 
      {display-name: display-name, cause: cause, impact-points: u0, tokens: u125, leader: false}))
  )
)

(define-public (update-contributor (display-name (string-ascii 50)) (cause (string-ascii 20)))
  (let ((caller tx-sender))
    (asserts! (> (len display-name) u0) ERR_EMPTY_STRING)
    (asserts! (or (is-eq cause "environment") (is-eq cause "education") (is-eq cause "health")) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? contributors {contributor-id: caller})) ERR_NOT_FOUND)
    (ok (map-set contributors 
      {contributor-id: caller} 
      (merge (unwrap! (map-get? contributors {contributor-id: caller}) ERR_NOT_FOUND)
             {display-name: display-name, cause: cause})))
  )
)

;; Initiative functions
(define-public (launch-initiative (initiative-name (string-ascii 50)) (impact-details (buff 32)))
  (let ((caller tx-sender)
        (initiative-id (var-get next-initiative-id)))
    (asserts! (> (len initiative-name) u0) ERR_EMPTY_STRING)
    (asserts! (> (len impact-details) u0) ERR_EMPTY_DETAILS)
    (asserts! (is-some (map-get? contributors {contributor-id: caller})) ERR_NOT_FOUND)
    (var-set activity-log (+ (var-get activity-log) u1))
    
    (map-set initiatives 
      {initiative-id: initiative-id} 
      { 
        creator: caller, 
        initiative-name: initiative-name, 
        impact-details: impact-details,
        created-at: (var-get activity-log), 
        verified: false,
        verification-count: u0,
        supporter-count: u0,
        impact-rating: u0,
        rating-count: u0
      })
    (var-set next-initiative-id (+ initiative-id u1))
    (ok initiative-id)
  )
)

(define-public (verify-initiative (initiative-id uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-initiative-id initiative-id) ERR_INVALID_INITIATIVE_ID)
    (asserts! (is-some (map-get? contributors {contributor-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? initiatives {initiative-id: initiative-id})) ERR_NOT_FOUND)
    
    (let ((initiative (unwrap! (map-get? initiatives {initiative-id: initiative-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get creator initiative))) ERR_SELF_VERIFICATION)
      (asserts! (is-none (map-get? initiative-verifications {initiative-id: initiative-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      (map-set initiative-verifications 
        {initiative-id: initiative-id, verifier: caller} 
        {verified: true})
      
      (let ((new-verification-count (+ (get verification-count initiative) u1))
            (initiative-creator (unwrap! (map-get? contributors {contributor-id: (get creator initiative)}) ERR_NOT_FOUND))
            (verifier-contrib (unwrap! (map-get? contributors {contributor-id: caller}) ERR_NOT_FOUND)))
        
        (map-set initiatives 
          {initiative-id: initiative-id} 
          (merge initiative {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u2)
          }))
        
        (map-set contributors 
          {contributor-id: caller} 
          (merge verifier-contrib {
            tokens: (+ (get tokens verifier-contrib) u8),
            impact-points: (+ (get impact-points verifier-contrib) u1)
          }))
        
        (if (and (>= new-verification-count u2) (not (get verified initiative)))
          (map-set contributors 
            {contributor-id: (get creator initiative)} 
            (merge initiative-creator {
              tokens: (+ (get tokens initiative-creator) INITIATIVE_BONUS),
              impact-points: (+ (get impact-points initiative-creator) u12),
              leader: (>= (+ (get impact-points initiative-creator) u12) COMMUNITY_LEADER_THRESHOLD)
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (support-initiative (initiative-id uint) (support-level uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-initiative-id initiative-id) ERR_INVALID_INITIATIVE_ID)
    (asserts! (> support-level u0) ERR_INVALID_INPUT)
    (asserts! (is-some (map-get? contributors {contributor-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? initiatives {initiative-id: initiative-id})) ERR_NOT_FOUND)
    
    (let ((initiative (unwrap! (map-get? initiatives {initiative-id: initiative-id}) ERR_NOT_FOUND)))
      (asserts! (get verified initiative) ERR_UNAUTHORIZED)
      
      (map-set initiative-support 
        {initiative-id: initiative-id, supporter: caller} 
        {support-level: support-level, supported-at: (var-get activity-log)})
      
      (let ((new-supporter-count (+ (get supporter-count initiative) support-level))
            (initiative-creator (unwrap! (map-get? contributors {contributor-id: (get creator initiative)}) ERR_NOT_FOUND)))
        
        (map-set initiatives 
          {initiative-id: initiative-id} 
          (merge initiative {supporter-count: new-supporter-count}))
        
        (map-set contributors 
          {contributor-id: (get creator initiative)} 
          (merge initiative-creator {
            tokens: (+ (get tokens initiative-creator) (* VERIFICATION_TOKENS support-level))
          }))
        
        (ok new-supporter-count)
      )
    )
  )
)

(define-public (rate-initiative-impact (initiative-id uint) (score uint))
  (let ((caller tx-sender))
    (asserts! (is-valid-initiative-id initiative-id) ERR_INVALID_INITIATIVE_ID)
    (asserts! (and (>= score u1) (<= score MAX_IMPACT_SCORE)) ERR_INVALID_IMPACT_SCORE)
    (asserts! (is-some (map-get? contributors {contributor-id: caller})) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? initiatives {initiative-id: initiative-id})) ERR_NOT_FOUND)
    
    (let ((initiative (unwrap! (map-get? initiatives {initiative-id: initiative-id}) ERR_NOT_FOUND)))
      (asserts! (not (is-eq caller (get creator initiative))) ERR_SELF_VERIFICATION)
      (asserts! (is-none (map-get? impact-scores {initiative-id: initiative-id, scorer: caller})) ERR_DUPLICATE_VERIFICATION)
      
      (map-set impact-scores 
        {initiative-id: initiative-id, scorer: caller} 
        {score: score})
      
      (let ((current-total-impact (* (get impact-rating initiative) (get rating-count initiative)))
            (new-rating-count (+ (get rating-count initiative) u1))
            (new-total-impact (+ current-total-impact score))
            (new-avg-impact (/ new-total-impact new-rating-count))
            (initiative-creator (unwrap! (map-get? contributors {contributor-id: (get creator initiative)}) ERR_NOT_FOUND))
            (scorer-contrib (unwrap! (map-get? contributors {contributor-id: caller}) ERR_NOT_FOUND)))
        
        (map-set initiatives 
          {initiative-id: initiative-id} 
          (merge initiative {
            impact-rating: new-avg-impact,
            rating-count: new-rating-count
          }))
        
        (map-set contributors 
          {contributor-id: caller} 
          (merge scorer-contrib {
            tokens: (+ (get tokens scorer-contrib) u3),
            impact-points: (+ (get impact-points scorer-contrib) u1)
          }))
        
        (if (>= score u4)
          (map-set contributors 
            {contributor-id: (get creator initiative)} 
            (merge initiative-creator {
              tokens: (+ (get tokens initiative-creator) u45)
            }))
          true)
        
        (ok new-avg-impact)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-contributor-profile (contributor-id principal))
  (map-get? contributors {contributor-id: contributor-id})
)

(define-read-only (get-initiative (initiative-id uint))
  (map-get? initiatives {initiative-id: initiative-id})
)

(define-read-only (get-initiative-verification (initiative-id uint) (verifier principal))
  (map-get? initiative-verifications {initiative-id: initiative-id, verifier: verifier})
)

(define-read-only (get-initiative-support (initiative-id uint) (supporter principal))
  (map-get? initiative-support {initiative-id: initiative-id, supporter: supporter})
)

(define-read-only (get-impact-score (initiative-id uint) (scorer principal))
  (map-get? impact-scores {initiative-id: initiative-id, scorer: scorer})
)

(define-read-only (get-total-initiatives)
  (- (var-get next-initiative-id) u1)
)