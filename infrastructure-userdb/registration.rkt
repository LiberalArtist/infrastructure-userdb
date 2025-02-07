#lang racket/base

(provide (struct-out registration-state)
         make-registration-state
         generate-registration-code!
         check-registration-code
         )

(module+ implementation
  (provide fresh-code
           codes-equal?))

(require racket/match)
(require (only-in file/sha1 bytes->hex-string))
(require "types.rkt")

(define-logger infrastructure-userdb/registration)

(struct registration-state (codes ;; mutable hash from email string to code string
                            ) #:prefab)

(define (make-registration-state)
  (registration-state (make-hash)))

(define (fresh-code)
  (bytes->hex-string
   (with-input-from-file "/dev/urandom" (lambda () (read-bytes 12)))))

(define (generate-registration-code! s email)
  (define new-code (fresh-code))
  (hash-set! (registration-state-codes s) email new-code)
  (log-infrastructure-userdb/registration-info "Generated new code ~a for ~v" new-code email)
  new-code)

(define (codes-equal? a b)
  ;; Compare case-insensitively since people are weird and might
  ;; type the thing in.
  (string-ci=? a b))

(define (check-registration-code s email given-code k-ok k-bad)
  (define expected-code (hash-ref (registration-state-codes s) email #f))
  (if (and expected-code
           (codes-equal? expected-code given-code))
      (begin
        (log-infrastructure-userdb/registration-info "Got valid code for ~v" email)
        (hash-remove! (registration-state-codes s) email)
        (k-ok))
      (begin
        (log-infrastructure-userdb/registration-info "Got invalid code for ~v" email)
        (k-bad))))
