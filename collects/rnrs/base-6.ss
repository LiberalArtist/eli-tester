#lang scheme/base

(require (for-syntax scheme/base
                     r6rs/private/identifier-syntax)
         (prefix-in r5rs: r5rs)
         (only-in r6rs/private/readtable rx:number)
         scheme/bool)

(provide 
 ;; PLT Scheme pre-requisites:
 (rename-out [datum #%datum])
 #%app

 ;; 11.2
 (rename-out [r5rs:define define]
             [r5rs:define-syntax define-syntax])

 ;; 11.4.1
 quote

 ;; 11.4.2
 (rename-out [r5rs:lambda lambda])

 ;; 11.4.3
 (rename-out [r5rs:if if])

 ;; 11.4.4
 set!

 ;; 11.4.5
 cond else => case
 and or
 
 ;; 11.4.6
 let let*
 (rename-out [r5rs:letrec letrec]
             [letrec letrec*])
 let-values let*-values
 
 ;; 11.4.7
 begin

 ;; 11.5
 eqv? eq? equal?

 ;; 11.6
 procedure?
 
 ;; 11.7.4
 number? complex?
 (rename-out [r6rs:real? real?]
             [r6rs:rational? rational?]
             [r6rs:integer? integer?]
             [real? real-valued?]
             [rational? rational-valued?]
             [integer? integer-valued?])
 exact? inexact?
 (rename-out [inexact->exact exact]
             [exact->inexact inexact])
 = < > <= >=
 zero? positive? negative? odd?
 even? finite? infinite? nan?
 min max
 + * - /
 abs gcd lcm
 numerator denominator
 floor ceiling truncate round
 rationalize
 exp log sin cos tan asin acos atan
 sqrt (rename-out [integer-sqrt/remainder exact-integer-sqrt])
 expt
 make-rectangular make-polar real-part imag-part magnitude angle
 (rename-out [r6rs:number->string number->string]
             [r6rs:string->number string->number])

 ;; 11.8
 not boolean?

 ;; 11.9
 (rename-out [r5rs:pair? pair?]
             [r5rs:cons cons]
             [r5rs:car car]
             [r5rs:cdr cdr]
             [r5rs:caar caar]
             [r5rs:cadr cadr]
             [r5rs:cdar cdar]
             [r5rs:cddr cddr]
             [r5rs:caaar caaar]
             [r5rs:caadr caadr]
             [r5rs:cadar cadar]
             [r5rs:caddr caddr]
             [r5rs:cdaar cdaar]
             [r5rs:cdadr cdadr]
             [r5rs:cddar cddar]
             [r5rs:cdddr cdddr]
             [r5rs:caaaar caaaar]
             [r5rs:caaadr caaadr]
             [r5rs:caadar caadar]
             [r5rs:caaddr caaddr]
             [r5rs:cadaar cadaar]
             [r5rs:cadadr cadadr]
             [r5rs:caddar caddar]
             [r5rs:cadddr cadddr]
             [r5rs:cdaaar cdaaar]
             [r5rs:cdaadr cdaadr]
             [r5rs:cdadar cdadar]
             [r5rs:cdaddr cdaddr]
             [r5rs:cddaar cddaar]
             [r5rs:cddadr cddadr]
             [r5rs:cdddar cdddar]
             [r5rs:cddddr cddddr]
             [r5rs:null? null?]
             [r5rs:list? list?]
             [r5rs:list list]
             [r5rs:length length]
             [r5rs:append append]
             [r5rs:reverse reverse]
             [r5rs:list-tail list-tail]
             [r5rs:list-ref list-ref]
             [r5rs:map map]
             [r5rs:for-each for-each])

 ;; 11.10
 symbol? symbol=?
 string->symbol symbol->string
 
 ;; 11.11
 char? char=? char<? char>? char<=? char>=?

 ;; 11.12
 string?
 make-string string
 string-length string-ref
 string=? string<? string>? string<=? string>=?
 substring string-append
 (rename-out [r5rs:string->list string->list]
             [r5rs:list->string list->string])
 string-for-each string-copy

 ;; 11.13
 vector? make-vector vector
 vector-length vector-ref vector-set!
 (rename-out [r5rs:vector->list vector->list]
             [r5rs:list->vector list->vector])
 vector-fill! 
 vector-map
 vector-for-each

 ;; 11.14
 (rename-out [r6rs:error error])
 assertion-violation assert

 ;; 11.15
 apply
 call-with-current-continuation call/cc
 values call-with-values
 dynamic-wind

 ;; 11.17
 (rename-out [r5rs:quasiquote quasiquote]) ;; FIXME: need the R6RS extension
 unquote unquote-splicing

 ;; 11.18
 let-syntax letrec-syntax

 ;; 11.19
 (for-syntax syntax-rules
             identifier-syntax)

 )

;; ----------------------------------------

(define (r6rs:real? n)
  (and (real? n)
       (exact? (imag-part n))))

(define (r6rs:rational? n)
  (and (rational? n)
       (r6rs:real? n)
       (not (and (inexact? n)
                 (or (eqv? n +inf.0)
                     (eqv? n -inf.0)
                     (eqv? n +nan.0))))))

(define (r6rs:integer? n)
  (and (integer? n)
       (r6rs:rational? n)))

(define (finite? n)
  (r6rs:real? n))

(define (infinite? n)
  (or (eqv? n +inf.0)
      (eqv? n -inf.0)))

(define (nan? n)
  (eqv? n +nan.0))

(define (r6rs:number->string z [radix 10] [precision #f])
  (number->string z radix))

(define (r6rs:string->number s [radix 10])
  (and (regexp-match? rx:number s)
       (string->number (regexp-replace* #rx"|[0-9]+" s "") radix)))

(define-syntax-rule (make-mapper what for for-each in-val val-length val->list)
  (case-lambda
   [(proc val) (for ([c (in-val val)])
                 (proc c))]
   [(proc val1 val2) 
    (if (= (val-length val1)
           (val-length val2))
        (for ([c1 (in-val val1)]
              [c2 (in-val val2)])
          (proc c1 c2))
        (error 'val-for-each "~as have different lengths: ~e and: ~e"
               what
               val1 val2))]
   [(proc val1 . vals)
    (let ([len (val-length val1)])
      (for-each (lambda (s)
                  (unless (= (val-length s) len)
                    (error 'val-for-each "~a have different lengths: ~e and: ~e"
                           what
                           val1 s)))
                vals)
      (apply for-each 
             proc 
             (val->list val1)
             (map val->list vals)))]))

(define string-for-each
  (make-mapper "string" for for-each in-string string-length string->list))

(define vector-for-each
  (make-mapper "vector" for for-each in-vector vector-length vector->list))

(define vector-map
  (make-mapper "vector" for/list map in-vector vector-length vector->list))


(define-struct (exn:fail:r6rs exn:fail) (who irritants))
(define-struct (exn:fail:contract:r6rs exn:fail:contract) (who irritants))

(define (r6rs:error who msg . irritants)
  (make-exn:fail:r6rs
   (format "~a: ~a" who msg)
   (current-continuation-marks)
   who
   irritants))

(define (assertion-violation who msg . irritants)
  (make-exn:fail:r6rs
   (format "~a: ~a" who msg)
   (current-continuation-marks)
   who
   irritants))

(define-syntax-rule (assert expr)
  (unless expr
    (assrtion-violation #f "assertion failed")))

;; ----------------------------------------
;; Datum

(define-syntax (datum stx)
  (syntax-case stx ()
    [(_ . thing)
     (if (vector? (syntax-e #'thing))
         (raise-syntax-error 'r6rs
                             "a vector is not an expression"
                             #'thing)
         #`(quote thing))]))
