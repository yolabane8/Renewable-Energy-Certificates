(define-constant ERR_OWNER_ONLY u900)
(define-constant ERR_NOT_VERIFIER u901)
(define-constant ERR_OWNER_ALREADY_SET u902)
(define-constant ERR_OWNER_NOT_SET u903)

(define-data-var owner (optional principal) none)

(define-map verifiers
  principal
  bool
)
(define-map attestations
  {
    certificate-id: uint,
    verifier: principal,
  }
  {
    verdict: bool,
    uri: (string-utf8 256),
    timestamp: uint,
  }
)
(define-map certificate-summary
  uint
  {
    approvals: uint,
    rejections: uint,
    last-updated: uint,
  }
)

(define-read-only (get-owner)
  (var-get owner)
)

(define-read-only (is-verifier (v principal))
  (default-to false (map-get? verifiers v))
)

(define-public (set-owner (who principal))
  (let ((current (var-get owner)))
    (asserts! (is-none current) (err ERR_OWNER_ALREADY_SET))
    (var-set owner (some who))
    (ok who)
  )
)

(define-public (add-verifier (v principal))
  (let ((o (var-get owner)))
    (asserts! (is-some o) (err ERR_OWNER_NOT_SET))
    (asserts! (is-eq (some tx-sender) o) (err ERR_OWNER_ONLY))
    (map-set verifiers v true)
    (ok true)
  )
)

(define-public (remove-verifier (v principal))
  (let ((o (var-get owner)))
    (asserts! (is-some o) (err ERR_OWNER_NOT_SET))
    (asserts! (is-eq (some tx-sender) o) (err ERR_OWNER_ONLY))
    (map-set verifiers v false)
    (ok true)
  )
)

(define-public (attest
    (certificate-id uint)
    (verdict bool)
    (uri (string-utf8 256))
  )
  (let (
      (isv (default-to false (map-get? verifiers tx-sender)))
      (key {
        certificate-id: certificate-id,
        verifier: tx-sender,
      })
      (now burn-block-height)
      (sum (default-to {
        approvals: u0,
        rejections: u0,
        last-updated: u0,
      }
        (map-get? certificate-summary certificate-id)
      ))
    )
    (asserts! isv (err ERR_NOT_VERIFIER))
    (match (map-get? attestations key)
      prev (let (
          (prev-verdict (get verdict prev))
          (ap (let (
              (dec (if (and (not verdict) prev-verdict)
                u1
                u0
              ))
              (inc (if (and verdict (not prev-verdict))
                u1
                u0
              ))
            )
            (+ (- (get approvals sum) dec) inc)
          ))
          (rej (let (
              (dec (if (and verdict (not prev-verdict))
                u1
                u0
              ))
              (inc (if (and (not verdict) prev-verdict)
                u1
                u0
              ))
            )
            (+ (- (get rejections sum) dec) inc)
          ))
        )
        (begin
          (map-set attestations key {
            verdict: verdict,
            uri: uri,
            timestamp: now,
          })
          (map-set certificate-summary certificate-id {
            approvals: ap,
            rejections: rej,
            last-updated: now,
          })
          (ok true)
        )
      )
      (begin
        (map-set attestations key {
          verdict: verdict,
          uri: uri,
          timestamp: now,
        })
        (map-set certificate-summary certificate-id {
          approvals: (if verdict
            (+ (get approvals sum) u1)
            (get approvals sum)
          ),
          rejections: (if verdict
            (get rejections sum)
            (+ (get rejections sum) u1)
          ),
          last-updated: now,
        })
        (ok true)
      )
    )
  )
)

(define-read-only (get-attestation
    (certificate-id uint)
    (verifier principal)
  )
  (map-get? attestations {
    certificate-id: certificate-id,
    verifier: verifier,
  })
)

(define-read-only (get-summary (certificate-id uint))
  (default-to {
    approvals: u0,
    rejections: u0,
    last-updated: u0,
  }
    (map-get? certificate-summary certificate-id)
  )
)
