(define-non-fungible-token renewable-energy-certificate uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-not-found (err u102))
(define-constant err-already-retired (err u103))
(define-constant err-unauthorized-issuer (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-cert-expired (err u106))
(define-constant err-contract-paused (err u107))
(define-constant err-invalid-date (err u108))
(define-constant err-insufficient-payment (err u109))
(define-constant err-not-for-sale (err u110))
(define-constant err-invalid-price (err u111))

(define-data-var next-certificate-id uint u1)
(define-data-var total-certificates uint u0)
(define-data-var total-mwh-issued uint u0)
(define-data-var total-mwh-retired uint u0)
(define-data-var contract-paused bool false)
(define-data-var trading-volume-stx uint u0)
(define-data-var total-trades uint u0)

(define-map authorized-issuers
    principal
    bool
)
(define-map certificate-data
    uint
    {
        energy-type: (string-ascii 50),
        mwh-amount: uint,
        generation-date: uint,
        expiry-date: uint,
        location: (string-ascii 100),
        issuer: principal,
        retired: bool,
        retirement-date: (optional uint),
        retired-by: (optional principal),
    }
)

(define-map issuer-statistics
    principal
    {
        total-issued: uint,
        total-mwh: uint,
        active-certificates: uint,
    }
)

(define-map monthly-targets
    {
        year: uint,
        month: uint,
    }
    uint
)
(define-map energy-type-registry
    (string-ascii 50)
    bool
)
(define-map certificate-prices
    uint
    {
        price-ustx: uint,
        for-sale: bool,
        listed-at: uint,
    }
)
(define-map trading-history
    uint
    {
        certificate-id: uint,
        seller: principal,
        buyer: principal,
        price-ustx: uint,
        trade-timestamp: uint,
        energy-type: (string-ascii 50),
        mwh-amount: uint,
    }
)
(define-map market-statistics
    (string-ascii 50)
    {
        total-volume-stx: uint,
        total-trades: uint,
        last-sale-price: uint,
        avg-price-per-mwh: uint,
    }
)

(define-public (add-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (map-set authorized-issuers issuer true)
        (map-set issuer-statistics issuer {
            total-issued: u0,
            total-mwh: u0,
            active-certificates: u0,
        })
        (ok true)
    )
)

(define-public (remove-authorized-issuer (issuer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-issuers issuer false)
        (ok true)
    )
)

(define-public (register-energy-type (energy-type (string-ascii 50)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set energy-type-registry energy-type true)
        (ok true)
    )
)

(define-public (issue-certificate
        (recipient principal)
        (energy-type (string-ascii 50))
        (mwh-amount uint)
        (generation-date uint)
        (expiry-date uint)
        (location (string-ascii 100))
    )
    (let ((certificate-id (var-get next-certificate-id)))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (default-to false (map-get? authorized-issuers tx-sender))
            err-unauthorized-issuer
        )
        (asserts! (> mwh-amount u0) err-invalid-amount)
        (asserts! (> expiry-date generation-date) err-invalid-date)
        (asserts! (default-to false (map-get? energy-type-registry energy-type))
            err-invalid-amount
        )

        (try! (nft-mint? renewable-energy-certificate certificate-id recipient))

        (map-set certificate-data certificate-id {
            energy-type: energy-type,
            mwh-amount: mwh-amount,
            generation-date: generation-date,
            expiry-date: expiry-date,
            location: location,
            issuer: tx-sender,
            retired: false,
            retirement-date: none,
            retired-by: none,
        })

        (var-set next-certificate-id (+ certificate-id u1))
        (var-set total-certificates (+ (var-get total-certificates) u1))
        (var-set total-mwh-issued (+ (var-get total-mwh-issued) mwh-amount))

        (update-issuer-stats tx-sender mwh-amount true)

        (ok certificate-id)
    )
)

(define-public (transfer-certificate
        (certificate-id uint)
        (new-owner principal)
    )
    (let (
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! (not (get retired cert-data)) err-already-retired)

        (try! (nft-transfer? renewable-energy-certificate certificate-id current-owner
            new-owner
        ))

        (ok true)
    )
)

(define-public (retire-certificate (certificate-id uint))
    (let (
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
            (retirement-timestamp (var-get next-certificate-id))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! (not (get retired cert-data)) err-already-retired)

        (map-set certificate-data certificate-id
            (merge cert-data {
                retired: true,
                retirement-date: (some retirement-timestamp),
                retired-by: (some tx-sender),
            })
        )

        (var-set total-mwh-retired
            (+ (var-get total-mwh-retired) (get mwh-amount cert-data))
        )

        (update-issuer-stats (get issuer cert-data) (get mwh-amount cert-data)
            false
        )

        (ok true)
    )
)

(define-public (batch-retire-certificates (certificate-ids (list 50 uint)))
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (fold check-and-retire certificate-ids (ok u0))
    )
)

(define-private (check-and-retire
        (certificate-id uint)
        (prev-result (response uint uint))
    )
    (match prev-result
        success (match (retire-certificate certificate-id)
            retire-success (ok certificate-id)
            retire-error (err retire-error)
        )
        error (err error)
    )
)

(define-private (update-issuer-stats
        (issuer principal)
        (mwh-amount uint)
        (is-new bool)
    )
    (let ((current-stats (default-to {
            total-issued: u0,
            total-mwh: u0,
            active-certificates: u0,
        }
            (map-get? issuer-statistics issuer)
        )))
        (map-set issuer-statistics issuer {
            total-issued: (if is-new
                (+ (get total-issued current-stats) u1)
                (get total-issued current-stats)
            ),
            total-mwh: (if is-new
                (+ (get total-mwh current-stats) mwh-amount)
                (get total-mwh current-stats)
            ),
            active-certificates: (if is-new
                (+ (get active-certificates current-stats) u1)
                (- (get active-certificates current-stats) u1)
            ),
        })
    )
)

(define-private (update-market-stats
        (energy-type (string-ascii 50))
        (sale-price uint)
        (mwh-amount uint)
    )
    (let ((current-stats (default-to {
            total-volume-stx: u0,
            total-trades: u0,
            last-sale-price: u0,
            avg-price-per-mwh: u0,
        }
            (map-get? market-statistics energy-type)
        )))
        (map-set market-statistics energy-type {
            total-volume-stx: (+ (get total-volume-stx current-stats) sale-price),
            total-trades: (+ (get total-trades current-stats) u1),
            last-sale-price: sale-price,
            avg-price-per-mwh: (if (> mwh-amount u0)
                (/ sale-price mwh-amount)
                u0
            ),
        })
    )
)

(define-public (update-certificate-location
        (certificate-id uint)
        (new-location (string-ascii 100))
    )
    (let (
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
            (issuer (get issuer cert-data))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender issuer) err-unauthorized-issuer)
        (asserts! (not (get retired cert-data)) err-already-retired)

        (map-set certificate-data certificate-id
            (merge cert-data { location: new-location })
        )
        (ok true)
    )
)

(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused true)
        (ok true)
    )
)

(define-public (emergency-unpause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set contract-paused false)
        (ok true)
    )
)

(define-public (revoke-certificate (certificate-id uint))
    (let (
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
            (issuer (get issuer cert-data))
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender issuer) err-unauthorized-issuer)
        (asserts! (not (get retired cert-data)) err-already-retired)

        (try! (nft-burn? renewable-energy-certificate certificate-id current-owner))

        (map-delete certificate-data certificate-id)
        (var-set total-certificates (- (var-get total-certificates) u1))
        (var-set total-mwh-issued
            (- (var-get total-mwh-issued) (get mwh-amount cert-data))
        )

        (update-issuer-stats issuer (get mwh-amount cert-data) false)

        (ok true)
    )
)

(define-public (set-monthly-target
        (year uint)
        (month uint)
        (target-mwh uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= month u1) (<= month u12)) err-invalid-amount)
        (asserts! (>= year u2024) err-invalid-amount)
        (map-set monthly-targets {
            year: year,
            month: month,
        }
            target-mwh
        )
        (ok true)
    )
)

(define-read-only (get-certificate-data (certificate-id uint))
    (map-get? certificate-data certificate-id)
)

(define-read-only (get-certificate-owner (certificate-id uint))
    (nft-get-owner? renewable-energy-certificate certificate-id)
)

(define-read-only (is-authorized-issuer (issuer principal))
    (default-to false (map-get? authorized-issuers issuer))
)

(define-read-only (get-issuer-statistics (issuer principal))
    (map-get? issuer-statistics issuer)
)

(define-read-only (get-monthly-target
        (year uint)
        (month uint)
    )
    (default-to u0
        (map-get? monthly-targets {
            year: year,
            month: month,
        })
    )
)

(define-read-only (is-energy-type-registered (energy-type (string-ascii 50)))
    (default-to false (map-get? energy-type-registry energy-type))
)

(define-read-only (get-total-statistics)
    {
        total-certificates: (var-get total-certificates),
        total-mwh-issued: (var-get total-mwh-issued),
        total-mwh-retired: (var-get total-mwh-retired),
        active-mwh: (- (var-get total-mwh-issued) (var-get total-mwh-retired)),
        next-id: (var-get next-certificate-id),
    }
)

(define-read-only (get-certificate-status (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data
        {
            exists: true,
            retired: (get retired cert-data),
            mwh-amount: (get mwh-amount cert-data),
            energy-type: (get energy-type cert-data),
            location: (get location cert-data),
            issuer: (get issuer cert-data),
            generation-date: (get generation-date cert-data),
            expiry-date: (get expiry-date cert-data),
        }
        {
            exists: false,
            retired: false,
            mwh-amount: u0,
            energy-type: "",
            location: "",
            issuer: contract-owner,
            generation-date: u0,
            expiry-date: u0,
        }
    )
)

(define-read-only (validate-certificate (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data (ok {
            valid: (not (get retired cert-data)),
            issuer: (get issuer cert-data),
            generation-date: (get generation-date cert-data),
            location: (get location cert-data),
            mwh-amount: (get mwh-amount cert-data),
            energy-type: (get energy-type cert-data),
        })
        err-not-found
    )
)

(define-read-only (verify-certificate-authenticity (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data
        {
            authentic: true,
            issuer-authorized: (default-to false
                (map-get? authorized-issuers (get issuer cert-data))
            ),
            not-retired: (not (get retired cert-data)),
            valid-amount: (> (get mwh-amount cert-data) u0),
            valid-dates: (> (get expiry-date cert-data) (get generation-date cert-data)),
        }
        {
            authentic: false,
            issuer-authorized: false,
            not-retired: false,
            valid-amount: false,
            valid-dates: false,
        }
    )
)

(define-read-only (get-certificate-chain (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data
        {
            certificate-id: certificate-id,
            current-owner: (nft-get-owner? renewable-energy-certificate certificate-id),
            original-issuer: (get issuer cert-data),
            creation-data: (get generation-date cert-data),
            retirement-data: (get retirement-date cert-data),
            status: (if (get retired cert-data)
                "retired"
                "active"
            ),
        }
        {
            certificate-id: certificate-id,
            current-owner: none,
            original-issuer: contract-owner,
            creation-data: u0,
            retirement-data: none,
            status: "not-found",
        }
    )
)

(define-public (fractional-retire
        (certificate-id uint)
        (mwh-to-retire uint)
    )
    (let (
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
            (cert-mwh (get mwh-amount cert-data))
            (new-cert-id (var-get next-certificate-id))
            (remaining-mwh (- cert-mwh mwh-to-retire))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! (not (get retired cert-data)) err-already-retired)
        (asserts! (> mwh-to-retire u0) err-invalid-amount)
        (asserts! (< mwh-to-retire cert-mwh) err-invalid-amount)

        (map-set certificate-data certificate-id
            (merge cert-data { mwh-amount: remaining-mwh })
        )

        (try! (nft-mint? renewable-energy-certificate new-cert-id current-owner))

        (map-set certificate-data new-cert-id
            (merge cert-data {
                mwh-amount: mwh-to-retire,
                retired: true,
                retirement-date: (some (var-get next-certificate-id)),
                retired-by: (some tx-sender),
            })
        )

        (var-set next-certificate-id (+ new-cert-id u1))
        (var-set total-certificates (+ (var-get total-certificates) u1))
        (var-set total-mwh-retired (+ (var-get total-mwh-retired) mwh-to-retire))

        (ok new-cert-id)
    )
)

(define-public (bulk-transfer-certificates
        (certificate-id-1 uint)
        (new-owner-1 principal)
        (certificate-id-2 uint)
        (new-owner-2 principal)
        (certificate-id-3 uint)
        (new-owner-3 principal)
    )
    (begin
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (try! (transfer-certificate certificate-id-1 new-owner-1))
        (try! (transfer-certificate certificate-id-2 new-owner-2))
        (try! (transfer-certificate certificate-id-3 new-owner-3))
        (ok true)
    )
)

(define-public (list-certificate-for-sale
        (certificate-id uint)
        (price-ustx uint)
    )
    (let (
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)
        (asserts! (not (get retired cert-data)) err-already-retired)
        (asserts! (> price-ustx u0) err-invalid-price)

        (map-set certificate-prices certificate-id {
            price-ustx: price-ustx,
            for-sale: true,
            listed-at: burn-block-height,
        })
        (ok true)
    )
)

(define-public (delist-certificate (certificate-id uint))
    (let ((current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
            err-not-found
        )))
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (is-eq tx-sender current-owner) err-not-token-owner)

        (map-delete certificate-prices certificate-id)
        (ok true)
    )
)

(define-public (purchase-certificate (certificate-id uint))
    (let (
            (current-owner (unwrap! (nft-get-owner? renewable-energy-certificate certificate-id)
                err-not-found
            ))
            (cert-data (unwrap! (map-get? certificate-data certificate-id) err-not-found))
            (price-data (unwrap! (map-get? certificate-prices certificate-id)
                err-not-for-sale
            ))
            (trade-id (var-get total-trades))
        )
        (asserts! (not (var-get contract-paused)) err-contract-paused)
        (asserts! (get for-sale price-data) err-not-for-sale)
        (asserts! (not (is-eq tx-sender current-owner)) err-not-token-owner)
        (asserts! (not (get retired cert-data)) err-already-retired)

        (try! (stx-transfer? (get price-ustx price-data) tx-sender current-owner))
        (try! (nft-transfer? renewable-energy-certificate certificate-id current-owner
            tx-sender
        ))

        (map-set trading-history trade-id {
            certificate-id: certificate-id,
            seller: current-owner,
            buyer: tx-sender,
            price-ustx: (get price-ustx price-data),
            trade-timestamp: burn-block-height,
            energy-type: (get energy-type cert-data),
            mwh-amount: (get mwh-amount cert-data),
        })

        (var-set total-trades (+ trade-id u1))
        (var-set trading-volume-stx
            (+ (var-get trading-volume-stx) (get price-ustx price-data))
        )

        (update-market-stats (get energy-type cert-data)
            (get price-ustx price-data) (get mwh-amount cert-data)
        )
        (map-delete certificate-prices certificate-id)

        (ok true)
    )
)

(define-read-only (get-market-summary)
    (let (
            (active-mwh (- (var-get total-mwh-issued) (var-get total-mwh-retired)))
            (total-issued (var-get total-mwh-issued))
        )
        {
            total-certificates: (var-get total-certificates),
            active-mwh: active-mwh,
            retired-mwh: (var-get total-mwh-retired),
            retirement-rate: (if (> total-issued u0)
                (/ (* (var-get total-mwh-retired) u100) total-issued)
                u0
            ),
            next-certificate-id: (var-get next-certificate-id),
        }
    )
)

(define-read-only (calculate-user-portfolio (user principal))
    (fold sum-user-certificates
        (list
            u1             u2             u3             u4             u5
                        u6             u7             u8             u9             u10
                        u11             u12             u13             u14             u15
                        u16             u17             u18             u19
            u20
        )
        u0
    )
)

(define-private (sum-user-certificates
        (certificate-id uint)
        (total-mwh uint)
    )
    (match (nft-get-owner? renewable-energy-certificate certificate-id)
        owner (if (is-eq owner tx-sender)
            (match (map-get? certificate-data certificate-id)
                cert-data (if (get retired cert-data)
                    total-mwh
                    (+ total-mwh (get mwh-amount cert-data))
                )
                total-mwh
            )
            total-mwh
        )
        total-mwh
    )
)

(define-read-only (get-retirement-history (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data (if (get retired cert-data)
            (ok {
                retired: true,
                retirement-date: (get retirement-date cert-data),
                retired-by: (get retired-by cert-data),
                mwh-retired: (get mwh-amount cert-data),
            })
            (ok {
                retired: false,
                retirement-date: none,
                retired-by: none,
                mwh-retired: u0,
            })
        )
        err-not-found
    )
)

(define-read-only (is-contract-paused)
    (var-get contract-paused)
)

(define-read-only (get-contract-info)
    {
        owner: contract-owner,
        paused: (var-get contract-paused),
        next-id: (var-get next-certificate-id),
        stats: (get-total-statistics),
    }
)

(define-read-only (get-certificate-summary (certificate-id uint))
    (match (map-get? certificate-data certificate-id)
        cert-data
        {
            id: certificate-id,
            energy-type: (get energy-type cert-data),
            mwh-amount: (get mwh-amount cert-data),
            location: (get location cert-data),
            issuer: (get issuer cert-data),
            owner: (nft-get-owner? renewable-energy-certificate certificate-id),
            retired: (get retired cert-data),
            vintage: (get generation-date cert-data),
        }
        {
            id: certificate-id,
            energy-type: "",
            mwh-amount: u0,
            location: "",
            issuer: contract-owner,
            owner: none,
            retired: false,
            vintage: u0,
        }
    )
)

(define-read-only (get-certificate-price (certificate-id uint))
    (map-get? certificate-prices certificate-id)
)

(define-read-only (get-trade-history (trade-id uint))
    (map-get? trading-history trade-id)
)

(define-read-only (get-market-stats (energy-type (string-ascii 50)))
    (default-to {
        total-volume-stx: u0,
        total-trades: u0,
        last-sale-price: u0,
        avg-price-per-mwh: u0,
    }
        (map-get? market-statistics energy-type)
    )
)

(define-read-only (get-trading-overview)
    {
        total-volume-stx: (var-get trading-volume-stx),
        total-trades: (var-get total-trades),
        market-active: (not (var-get contract-paused)),
    }
)

(define-read-only (get-certificate-with-price (certificate-id uint))
    (let (
            (cert-data (map-get? certificate-data certificate-id))
            (price-data (map-get? certificate-prices certificate-id))
        )
        (match cert-data
            cert
            {
                certificate: (some cert),
                owner: (nft-get-owner? renewable-energy-certificate certificate-id),
                price-info: price-data,
                for-sale: (match price-data
                    price (get for-sale price)
                    false
                ),
            }
            {
                certificate: none,
                owner: none,
                price-info: none,
                for-sale: false,
            }
        )
    )
)

(begin
    (map-set authorized-issuers contract-owner true)
    (map-set issuer-statistics contract-owner {
        total-issued: u0,
        total-mwh: u0,
        active-certificates: u0,
    })
    (map-set energy-type-registry "solar" true)
    (map-set energy-type-registry "wind" true)
    (map-set energy-type-registry "hydro" true)
    (map-set energy-type-registry "biomass" true)
    (map-set energy-type-registry "geothermal" true)
)
