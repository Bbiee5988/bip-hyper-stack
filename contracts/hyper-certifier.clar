;; hyper-certifier.clar
;; Bip Hyper Stack: Smart Contract Certification and Trust Verification Platform

;; This contract manages the certification and verification of smart contracts on the Stacks blockchain.
;; It provides functionality for:
;; 1. Registering and managing qualified auditors
;; 2. Submitting contracts for certification
;; 3. Issuing certifications with metadata
;; 4. Verifying contract certification status
;; 5. Managing auditor reputation and trust scores

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INVALID-RATING (err u103))
(define-constant ERR-ALREADY-CERTIFIED (err u104))
(define-constant ERR-NOT-CERTIFIED (err u105))
(define-constant ERR-INVALID-STATUS (err u106))
(define-constant ERR-INVALID-PARAMETERS (err u107))
(define-constant ERR-CONTRACT-NOT-FOUND (err u108))

;; Data structures

;; Platform owner
(define-data-var platform-owner principal tx-sender)

;; Auditor registry: maps auditor principal to their details and status
(define-map auditor-registry
  principal
  {
    name: (string-ascii 64),
    organization: (string-ascii 64),
    domain: (string-ascii 128),
    reputation-score: uint,
    certification-count: uint,
    status: (string-ascii 10),
    approved-timestamp: uint
  }
)

;; Certification requests made by contract owners
(define-map certification-requests
  {
    contract-id: principal,
    version: (string-ascii 16)
  }
  {
    requester: principal,
    description: (string-ascii 256),
    repository-url: (string-ascii 128),
    request-timestamp: uint,
    status: (string-ascii 10)
  }
)

;; Certifications issued by auditors
(define-map certification-records
  {
    contract-id: principal,
    version: (string-ascii 16)
  }
  {
    auditor: principal,
    security-rating: uint,
    audit-report-url: (string-ascii 128),
    certification-timestamp: uint,
    expiration-timestamp: uint,
    notes: (string-ascii 256)
  }
)

;; Auditor application tracking
(define-map auditor-applications
  principal
  {
    name: (string-ascii 64),
    organization: (string-ascii 64),
    domain: (string-ascii 128),
    credentials: (string-ascii 256),
    application-timestamp: uint
  }
)

;; Platform statistics
(define-data-var total-registered-auditors uint u0)
(define-data-var total-certifications uint u0)
(define-data-var total-certified-contracts uint u0)

;; Private utility functions

(define-private (is-platform-owner)
  (is-eq tx-sender (var-get platform-owner))
)

(define-private (is-active-auditor (auditor principal))
  (match (map-get? auditor-registry auditor)
    auditor-details (is-eq (get status auditor-details) "active")
    false
  )
)

;; Read-only functions

(define-read-only (get-auditor-details (auditor principal))
  (map-get? auditor-registry auditor)
)

(define-read-only (get-certification-details (contract-id principal) (version (string-ascii 16)))
  (map-get? certification-records { contract-id: contract-id, version: version })
)

(define-read-only (is-contract-certified (contract-id principal) (version (string-ascii 16)))
  (is-some (map-get? certification-records { contract-id: contract-id, version: version }))
)

(define-read-only (get-platform-statistics)
  {
    total-auditors: (var-get total-registered-auditors),
    total-certifications: (var-get total-certifications),
    total-certified-contracts: (var-get total-certified-contracts)
  }
)

;; Public functions

(define-public (transfer-platform-ownership (new-owner principal))
  (begin
    (asserts! (is-platform-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set platform-owner new-owner))
  )
)

(define-public (apply-as-auditor 
                (name (string-ascii 64))
                (organization (string-ascii 64))
                (domain (string-ascii 128))
                (credentials (string-ascii 256)))
  (begin
    (asserts! (is-none (map-get? auditor-applications tx-sender)) ERR-ALREADY-REGISTERED)
    (asserts! (is-none (map-get? auditor-registry tx-sender)) ERR-ALREADY-REGISTERED)
    
    (map-set auditor-applications tx-sender {
      name: name,
      organization: organization,
      domain: domain,
      credentials: credentials,
      application-timestamp: block-height
    })
    (ok true)
  )
)

(define-public (approve-auditor (auditor principal))
  (begin
    (asserts! (is-platform-owner) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? auditor-applications auditor)) ERR-NOT-REGISTERED)
    (asserts! (is-none (map-get? auditor-registry auditor)) ERR-ALREADY-REGISTERED)
    
    (let ((application (unwrap! (map-get? auditor-applications auditor) ERR-NOT-REGISTERED)))
      (map-set auditor-registry auditor {
        name: (get name application),
        organization: (get organization application),
        domain: (get domain application),
        reputation-score: u5,
        certification-count: u0,
        status: "active",
        approved-timestamp: block-height
      })
      (var-set total-registered-auditors (+ (var-get total-registered-auditors) u1))
      (map-delete auditor-applications auditor)
      (ok true)
    )
  )
)

(define-public (request-certification 
                (contract-id principal) 
                (version (string-ascii 16)) 
                (description (string-ascii 256))
                (repository-url (string-ascii 128)))
  (begin
    (asserts! (is-none (map-get? certification-requests 
                          { contract-id: contract-id, version: version })) 
              ERR-ALREADY-REGISTERED)
    
    (map-set certification-requests
      { contract-id: contract-id, version: version }
      {
        requester: tx-sender,
        description: description,
        repository-url: repository-url,
        request-timestamp: block-height,
        status: "pending"
      }
    )
    (ok true)
  )
)

(define-public (verify-contract-certification (contract-id principal) (version (string-ascii 16)))
  (ok (is-contract-certified contract-id version))
)

(define-public (get-contract-verification-details (contract-id principal) (version (string-ascii 16)))
  (match (map-get? certification-records { contract-id: contract-id, version: version })
    cert-details 
      (let ((auditor-info (default-to 
                            { 
                              name: "", 
                              organization: "", 
                              domain: "", 
                              reputation-score: u0,
                              certification-count: u0, 
                              status: "", 
                              approved-timestamp: u0
                            }
                            (map-get? auditor-registry (get auditor cert-details)))))
        (ok {
          is-certified: true,
          auditor: (get auditor cert-details),
          auditor-name: (get name auditor-info),
          auditor-organization: (get organization auditor-info),
          security-rating: (get security-rating cert-details),
          certification-timestamp: (get certification-timestamp cert-details),
          expiration-timestamp: (get expiration-timestamp cert-details),
          auditor-reputation: (get reputation-score auditor-info)
        }))
    (ok { 
      is-certified: false, 
      auditor: tx-sender, 
      auditor-name: "", 
      auditor-organization: "",
      security-rating: u0, 
      certification-timestamp: u0, 
      expiration-timestamp: u0, 
      auditor-reputation: u0 
    })
  )
)