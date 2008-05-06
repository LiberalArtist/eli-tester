#lang scheme/base

;; To include a test, add an appropriate entry in `tests' below.
;; Notes:
;; - Each test is run in its own namespace, but there is very little
;;   additional sandboxing.  (There is a timeout of 10 minutes.)
;; - Specifically, the I/O ports are not diverted -- so please keep
;;   output to a minimum, preferrably nothing if there are no errors.
;; - Tests are only running in mzscheme (*not* mred), but note that
;;   they will run with both the default 3m and the CGC executable,
;;   and with the JIT enabled and disabled.
;; - They will also run on all build platforms, some can be slow (eg,
;;   the Solaris build, or if we get an ARM build).  Many of the build
;;   machines are used by people, be polite!
;; - The tests are usually run from some temporary directory, you can
;;   create files in it, but DO NOT use any other paths: don't write
;;   into the PLT tree, don't write into the home directory (or rely
;;   on things in it), assume a fresh planet cache.
;; - To signal failures, either raise an error, or `exit' with a
;;   positive code.  Obviously, make sure that failures print some
;;   indicative text for you.
;; - A semi-related note: the PLT tree compilation should not rely on
;;   planet packages, so if you use them, make sure you add a
;;   `compile-omit-paths' in your test's info file.

;; Tests to run:
;;   Each should be a list with a mode symbol (`load' or `require'),
;;   the path to the test file (relative to this script) and module
;;   specifications for things to require into the initial namespace
;;   for the test before the test is loaded.
(define tests
  '([load "mzscheme/quiet.ss" (lib "scheme/init")]))


(require scheme/runtime-path (for-syntax scheme/base))

(define-runtime-path here ".")

(define (eprintf fmt . xs)
  (apply fprintf (current-error-port) fmt xs))

(define exit-code 0)

(for ([t tests])
  (define name (cadr t))
  (define cust (make-custodian))
  (define (echo fmt . args)
    (fprintf (current-error-port) "*** ~a: ~a\n" name (apply format fmt args)))
  (newline (current-error-port))
  (echo "running...")
  (let/ec break
    (define (abort n fmt . xs)
      (when (positive? n)
        (apply echo fmt xs)
        (set! exit-code (max exit-code n))
        (echo "BOOM!") ; used to find errors in nightly builds
        (break)))
    (thread (let ([th (current-thread)])
              (lambda () (sleep 600) (echo "Timeout!") (break-thread th))))
    (parameterize* ([exit-handler
                     (lambda (n) (abort n "exit with error code ~a" n))]
                    [uncaught-exception-handler
                     (lambda (exn) (abort 1 "error: ~a" (exn-message exn)))]
                    [current-namespace (make-base-empty-namespace)]
                    ;; [current-custodian cust] <- makes mzscheme tests stuck
                    )
      (for-each namespace-require (cddr t))
      ((case (car t) [(load) load] [(require) namespace-require])
       (build-path here name))
      (echo "all tests passed.")))
  (custodian-shutdown-all cust))

(exit exit-code)