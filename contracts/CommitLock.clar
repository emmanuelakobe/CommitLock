;; ------------------------------------------------------------
;; PledgeChain+ Smart Contract
;; Enhanced Accountability & Reward System
;; ------------------------------------------------------------

;; -----------------------------
;; Error Constants
;; -----------------------------
(define-constant ERR-ZERO-STX u100)
(define-constant ERR-NOT-OWNER u101)
(define-constant ERR-NOT-ACTIVE u102)
(define-constant ERR-CHECKIN-WINDOW u103)
(define-constant ERR-ALREADY-CHECKED-IN u104)
(define-constant ERR-NOT-FOUND u105)
(define-constant ERR-INVALID-DURATION u106)
(define-constant ERR-INVALID-INTERVAL u107)
(define-constant ERR-TOO-EARLY-END u108)
(define-constant ERR-NO-COMPLETION u109)

;; -----------------------------
;; Data Variables
;; -----------------------------
(define-data-var next-id uint u1)

;; -----------------------------
;; Data Maps
;; -----------------------------
(define-map pledges uint {
  pledger: principal,
  description: (string-utf8 200),
  start-block: uint,
  duration: uint,
  interval: uint,
  next-checkin: uint,
  last-checkin: uint,
  total-checkins: uint,
  penalty-address: principal,
  amount: uint,
  status: (string-ascii 12)
})

(define-map checkins { pledge-id: uint, checkin-block: uint } bool)

;; Leaderboard: Stores streak counts
(define-map streaks principal uint)

;; -----------------------------
;; EVENTS (for front-end triggers)
;; -----------------------------
;; Events are emitted using print statements with tuples

;; -----------------------------
;; Public: Create a pledge
;; -----------------------------
(define-public (create-pledge
    (description (string-utf8 200))
    (duration uint)
    (interval uint)
    (penalty-address principal)
    (amount uint))
  (begin
    (asserts! (> amount u0) (err ERR-ZERO-STX))
    (asserts! (> duration u0) (err ERR-INVALID-DURATION))
    (asserts! (> interval u0) (err ERR-INVALID-INTERVAL))

    (let (
      (pledge-id (var-get next-id))
      (sender tx-sender)
      (current-block stacks-block-height))
      
      (try! (stx-transfer? amount sender (as-contract tx-sender)))

      (map-set pledges pledge-id {
        pledger: sender,
        description: description,
        start-block: current-block,
        duration: duration,
        interval: interval,
        next-checkin: (+ current-block interval),
        last-checkin: current-block,
        total-checkins: u0,
        penalty-address: penalty-address,
        amount: amount,
        status: "active"
      })

      (var-set next-id (+ pledge-id u1))
      (print {type: "pledge-created", id: pledge-id, sender: sender, amount: amount})
      (ok pledge-id))))

;; -----------------------------
;; Public: Check-in
;; -----------------------------
(define-public (check-in (pledge-id uint))
  (let ((pledge (unwrap! (map-get? pledges pledge-id) (err ERR-NOT-FOUND)))
        (current-block stacks-block-height))
    (begin
      (asserts! (is-eq (get pledger pledge) tx-sender) (err ERR-NOT-OWNER))
      (asserts! (is-eq (get status pledge) "active") (err ERR-NOT-ACTIVE))
      (asserts! (>= current-block (get next-checkin pledge)) (err ERR-CHECKIN-WINDOW))

      (let ((checkin-key { pledge-id: pledge-id, checkin-block: current-block }))
        (asserts! (is-none (map-get? checkins checkin-key)) (err ERR-ALREADY-CHECKED-IN))

        ;; Record checkin and update streak
        (map-set checkins checkin-key true)
        (let ((new-streak (+ (default-to u0 (map-get? streaks tx-sender)) u1)))
          (map-set streaks tx-sender new-streak)
          (map-set pledges pledge-id (merge pledge {
            last-checkin: current-block,
            next-checkin: (+ current-block (get interval pledge)),
            total-checkins: (+ (get total-checkins pledge) u1)
          }))
          (print {type: "pledge-checked-in", id: pledge-id, sender: tx-sender, streak: new-streak})
          (ok true))))))

;; -----------------------------
;; Public: End pledge & claim reward
;; -----------------------------
(define-public (end-pledge (pledge-id uint))
  (let ((pledge (map-get? pledges pledge-id))
        (now stacks-block-height))
    (match pledge 
      pledge-data
        (begin
          (asserts! (is-eq (get pledger pledge-data) tx-sender) (err ERR-NOT-OWNER))
          (asserts! (>= now (+ (get start-block pledge-data) (get duration pledge-data))) (err ERR-TOO-EARLY-END))

          ;; Must have completed at least 80% check-ins to earn reward
          (let ((required-checkins (/ (* (get duration pledge-data) u1) (get interval pledge-data))))
            (if (>= (get total-checkins pledge-data) (/ (* required-checkins u8) u10))
              (match (stx-transfer? (get amount pledge-data) (as-contract tx-sender) tx-sender)
                success
                  (begin
                    (map-set pledges pledge-id (merge pledge-data { status: "completed" }))
                    (print {type: "pledge-completed", id: pledge-id, sender: tx-sender, reward: (get amount pledge-data)})
                    (ok "Reward claimed"))
                error (err error))
              (err ERR-NO-COMPLETION))))
      (err ERR-NOT-FOUND))))

;; -----------------------------
;; Public: Penalize missed pledge
;; -----------------------------
(define-public (penalize (pledge-id uint))
  (let ((pledge (unwrap! (map-get? pledges pledge-id) (err ERR-NOT-FOUND)))
        (current-block stacks-block-height))
    (begin
      (asserts! (is-eq (get status pledge) "active") (err ERR-NOT-ACTIVE))

      ;; If user missed their check-in window, transfer funds to penalty address
      (if (> current-block (get next-checkin pledge))
        (begin
          (try! (stx-transfer? (get amount pledge) (as-contract tx-sender) (get penalty-address pledge)))
          (map-set pledges pledge-id (merge pledge { status: "penalized" }))
          (print {type: "pledge-penalized", id: pledge-id, sender: (get pledger pledge), penalty: (get amount pledge)})
          (ok "Pledge penalized"))
        (ok "No penalty needed")))))

;; -----------------------------
;; Read-only: Get pledge
;; -----------------------------
(define-read-only (get-pledge (pledge-id uint))
  (map-get? pledges pledge-id)
)

;; -----------------------------
;; Read-only: Get leaderboard
;; -----------------------------
(define-read-only (get-streak (user principal))
  (default-to u0 (map-get? streaks user)))
