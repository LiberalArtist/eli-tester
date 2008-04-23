#lang scheme/base

(provide go)

(require (planet schematics/schemeunit/test)
         (planet schematics/schemeunit/text-ui)
         (planet schematics/schemeunit/graphical-ui)
         mzlib/etc
         scheme/match
         "unit-tests/all-tests.ss")

(define (scheme-file? s)
  (regexp-match ".*[.](ss|scm)" (path->string s)))

(define-namespace-anchor a)

(define (exn-matches . args)
  (values
   (lambda (val)
     (and (exn? val)
          (for/and ([e args])
                   (if (procedure? e)
                       (e val)
                       (begin
                         (regexp-match e (exn-message val)))))))
   args))
  
(define (exn-pred p)
  (let ([sexp (with-handlers
                  ([values (lambda _ #f)])
                (let ([prt (open-input-file p)])
                  (begin0 (begin (read-line prt 'any) 
                                 (read prt))
                          (close-input-port prt))))])   
    (match sexp
      [(list-rest 'exn-pred e)
       (eval `(exn-matches . ,e) (namespace-anchor->namespace a))]
      [_ (exn-matches ".*typecheck.*" exn:fail:syntax?)])))

(define (mk-tests dir loader test)
  (lambda ()
    (define path (build-path (this-expression-source-directory) dir))  
    (define tests
      (for/list ([p (directory-list path)]
                 #:when (scheme-file? p))
        (test-case
         (path->string p)
         (test
          (build-path path p)
          (lambda ()
            (parameterize ([read-accept-reader #t]
                           [current-load-relative-directory 
                            path])
              (with-output-to-file "/dev/null" #:exists 'append
                (lambda () (loader p)))))))))
    (apply test-suite dir
           tests)))

(define succ-tests (mk-tests "succeed" 
                             (lambda (p) (dynamic-require `(file ,(path->string p)) #f))
                             (lambda (p thnk) (check-not-exn thnk))))
(define fail-tests (mk-tests "fail"
                             (lambda (p) (dynamic-require `(file ,(path->string p)) #f)) 
                             (lambda (p thnk)
                               (define-values (pred info) (exn-pred p))
                               (with-check-info
                                (['predicates info])
                                (check-exn pred thnk)))))

(define int-tests
  (test-suite "Integration tests"
              (succ-tests)
              (fail-tests)))

(define tests
  (test-suite "Typed Scheme Tests"
              unit-tests int-tests))

(define (go) (test/graphical-ui tests))

