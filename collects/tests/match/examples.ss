#lang scheme/base

(require scheme/match 
         (for-syntax scheme/base)
         (prefix-in m: mzlib/match))
(require (planet "test-compat2.ss" ("schematics" "schemeunit.plt" 2 10)))



(define-syntax (comp stx)
  (syntax-case stx ()
    [(mytest tst exp)
     #`(make-test-case (format "test: ~a" (syntax->datum (quote-syntax tst)))
                       #,(syntax/loc stx (assert-equal? tst exp)))]))

(define-struct X (a b c))
(define-match-expander X:
  (lambda (stx)
    (syntax-case stx ()
      [(_ . args) #'(struct X args)])))

(define (f x y)
  (match*
   (x y)
   [((box a) (box b)) (+ a b)]
   [((vector x y z) (vector _)) (* x y z)]
   [((list a b c) (list d)) (+ a b c d)]
   [((cons a b) (cons c _))  (+ a b c)]))


(define (g x)
  (match x
    [1 'one]
    [(and x (? number?)) (list x 'num)]
    [(? boolean?) 'bool]
    [_ 'neither]))


(define (split l)
  (match l
    [(list (list a b) ...) (list a b)]
    [_ 'wrong]))

(define (split2 l)
  (match l
    [(list (list a b) ..2 rest) (list a b rest)]
    [_ 'wrong]))


(define-struct empt ())


(provide new-tests)

(define new-tests
  (make-test-suite 
   "new tests for match"
   
   (comp 
    1
    (match (list 1 2 3)
      [(list x ...) (=> unmatch)
                    (if (= (car x) 1)
                        (begin (+ 100 (unmatch))
                               (error 'bad))
                        0)]
      [_ 1]))
   
   (comp 
    '(1 2 3)
    (match (vector 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 2]))
   
   (comp
    2
    (match (vector 'a 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 2]))
   
   (comp
    3
    (match (list 'a 1 2 3)
      [(vector (? number? x) ...) x]
      [_ 3]))
   
   
   (comp -1
         (match (vector 1 2 3)
           [(or (list x) x) -1]
           [(list a b c) 0]
           [(vector a) 1]
           [(vector a b) 2]
           [(vector a b c) 3]
           [(box _) 4]))
   
   (comp 12
         (match (list 12 12)
           [(list x x) x]
           [_ 13]))
   (comp 13
         (match (list 1 0)
           [(list x x) x]
           [_ 13]))
   
   
   (comp
    6
    (let ()
      (match (make-X 1 2 3)
        [(struct X (a b c)) (+ a b c)]
        [(box a) a]
        [(cons x y) (+ x y)]
        [_ 0])))
   
   (comp
    6
    (match (make-X 1 2 3)
      [(X: a b c) (+ a b c)]))
   

   
   (comp 
    '(6 3 100 6)
    (list
     (f (cons 1 2) (cons 3 4))
     (f (box 1) (box 2))
     (f (list 10 20 30) (list 40))
     (f (vector 1 2 3) (vector 4))))
   
   (comp '(one (2 num) bool neither)
         (list
          (g 1)
          (g 2)
          (g #f)
          (g "foo")))
   
   (comp
    (split (list (list 1 2) (list 'a 'b) (list 'x 'y)))
    '((1 a x) (2 b y)))
   (comp
    (split2 (list (list 1 2) (list 'a 'b) (list 'x 'y)))
    '((1 a) (2 b) (x y)))
   
   (comp
    'yes
    (match (list (box 2) 2)
      [(list (or (box x) (list x)) x) 'yes]
      [_ 'no]))
   
   (comp
    'no
    (parameterize ([match-equality-test eq?])
      (match (list (cons 1 1) (cons 1 1))
        [(list x x) 'yes]
        [_ 'no])))
   
   (comp
    'no
    (match (list (box 2) 3)
      [(list (or (box x) (list x)) x) 'yes]
      [_ 'no]))
   
   (comp
    2
    (match (list 'one 'three)
      [(list 'one 'two) 1]
      [(list 'one 'three) 2]
      [(list 'two 'three) 3]))
   (comp 
    2
    (match (list 'one 'three)
      [(cons 'one (cons 'two '())) 1]
      [(cons 'one (cons 'three '())) 2]
      [(cons 'two (cons 'three '())) 3]))
   
   (comp 'yes
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 'x 'y 'z) 'yes]
           [_ 'no]))
   
   ;; NOT WORKING YET
   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 r1 r2 r3) (list r1 r2 r3)]
           [_ 'no]))
   
   (comp '(x y z)
         (match '(1 x 2 y 3 z)
           [(list-no-order 1 2 3 rest ...) rest]
           [_ 'no]))
   
   (comp
    'yes
    (match '(a (c d))
      [(list-no-order 'a
                      (? pair?
                         (list-no-order 'c 'd)))
       'yes]
      [_ 'no]))
   
   
   (comp 
    '((1 2) (a b 1 2))
    (let ()
      (define-syntax-rule (match-lambda . cl)
        (lambda (e) (match e . cl)))
      
      (define (make-nil)
        '())
      (define nil? null?)
      
      (define make-::
        (match-lambda
          ((list-no-order (list '|1| a) (list '|2| d))
           (cons a d))))
      (define ::? pair?)
      (define (::-content p)
        (list (list '|1| (car p))
              (list '|2| (cdr p))))
      
      (define my-append
        (match-lambda
          ((list-no-order (list '|1| (? nil?))
                          (list '|2| l))
           l)
          ((list-no-order (list '|1| (? ::?
                                        (app ::-content (list-no-order (list
                                                                        '|1| h) (list '|2| t)))))
                          (list '|2| l))
           (make-:: (list (list '|1| h)
                          (list '|2| (my-append (list (list '|1| t) (list '|2|
                                                                          l)))))))))
      (list
       (my-append (list (list '|1| '())
                        (list '|2| '(1 2))))
       
       (my-append (list (list '|1| '(a b))
                        (list '|2| '(1 2)))))))
   
   
   (comp
    'yes
    (match
        (make-immutable-hasheq '((|1| . (a b))))
      [(hash-table ('|1| (app (lambda (p)
                                (make-immutable-hasheq
                                 (list (cons '|1| (car p))
                                       (cons '|2| (cdr p)))))
                              (hash-table ('|1| _) ('|2| _))))) 'yes]
      [_ 'no]))
   
   ;; examples from docs
   
   (comp 'yes
         (match '(1 2 3)
           [(list (not 4) ...) 'yes]
           [_ 'no]))
   
   (comp 'no
         (match '(1 4 3)
           [(list (not 4) ...) 'yes]
           [_ 'no]))
   
   (comp 1
         (match '(1 2)
           [(or (list a 1) (list a 2)) a]
           [_ 'bad]))
   
   (comp '(2 3)
         (match '(1 (2 3) 4)          
           [(list _ (and a (list _ ...)) _) a]
           [_ 'bad]))
   
   
   
   (comp 
    'yes
    (match "apple"
      [(regexp #rx"p+(.)" (list _ "l")) 'yes]
      [_ 'no]))
   (comp 
    'no
    (match "append"
      [(regexp #rx"p+(.)" (list _ "l")) 'yes]
      [_ 'no]))
   
   
   (comp 
    'yes
    (match "apple"
      [(regexp #rx"p+" ) 'yes]
      [_ 'no]))
   (comp 
    'no
    (match "banana"
      [(regexp #rx"p+") 'yes]
      [_ 'no]))
   
   (comp 
    '(0 1)
    (let ()
      (define-struct tree (val left right))
      
      (match (make-tree 0 (make-tree 1 #f #f) #f)   
        [(struct tree (a (struct tree (b  _ _)) _)) (list a b)]
        [_ 'no])))
   
   (comp 1
         (match #&1
           [(box a) a]
           [_ 'no]))
   (comp '(2 1)
         (match #hasheq(("a" . 1) ("b" . 2))
           [(hash-table ("b" b) ("a" a)) (list b a)]
           [_ 'no]))
   
   (comp #t
         (andmap string?
                 (match #hasheq(("b" . 2) ("a" . 1))
                   [(hash-table (key val) ...) key]
                   [_ 'no])))
   
   (comp
    (match #(1 (2) (2) (2) 5)
      [(vector 1 (list a) ..3 5) a]
      [_ 'no])
    '(2 2 2))
   
   (comp '(1 3 4 5)
         (match '(1 2 3 4 5 6)          
           [(list-no-order 6 2 y ...) y]
           [_ 'no]))
   
   (comp 1
         (match '(1 2 3)          
           [(list-no-order 3 2 x) x]))
   (comp '((1 2 3) 4)
         (match '(1 2 3 . 4)          
           [(list-rest a ... d) (list a d)]))
   
   (comp 4
         (match '(1 2 3 . 4)
           [(list-rest a b c d) d]))
   
   ;; different behavior from the way match used to be
   (comp '(2 3 4)
         (match '(1 2 3 4 5)
           [(list 1 a ..3 5) a]      
           [_ 'else]))
   
   (comp '((1 2 3 4) ())
         (match (list 1 2 3 4 5)
           [(list x ... y ... 5) (list x y)]
           [_ 'no]))
   
   (comp '((1 3 2) (4))
         (match (list 1 3 2 3 4 5)
           [(list x ... 3 y ... 5) (list x y)]
           [_ 'no]))
   
   (comp '(3 2 1)
         (match '(1 2 3)
           [(list a b c) (list c b a)]))
   
   (comp '(2 3)
         (match '(1 2 3)
           [(list 1 a ...) a]))
   
   (comp 'else
         (match '(1 2 3)
           [(list 1 a ..3) a]
           [_ 'else]))
   
   (comp '(2 3 4)
         (match '(1 2 3 4)
           [(list 1 a ..3) a]
           [_ 'else]))
   
   (comp
    '(2 2 2)
    (match '(1 (2) (2) (2) 5)
      [(list 1 (list a) ..3 5) a]
      [_ 'else]))
   
   (comp
    #t
    (match "yes"
      ["yes" #t]
      ["no" #f]))
   
   (comp 3
         (match '(1 2 3)
           [(list _ _ a) a]))
   (comp '(3 2 1)
         (match '(1 2 3)          
           [(list a b a) (list a b)]          
           [(list a b c) (list c b a)]))
   
   (comp '(2 '(x y z) 1)
         (match '(1 '(x y z) 2) 
           [(list a b a) (list a b)]          
           [(list a b c) (list c b a)]))
   
   (comp '(1 '(x y z))
         (match '(1 '(x y z) 1) 
           [(list a b a) (list a b)]          
           [(list a b c) (list c b a)]))
   
   (comp '(2 3)
         (match '(1 2 3)
           [`(1 ,a ,(? odd? b)) (list a b)]))
   
   (comp '(2 1 (1 2 3 4))
         (match-let ([(list a b) '(1 2)]                  
                     [(vector x ...) #(1 2 3 4)])        
           (list b a x)))
   
   
   
   (comp '(1 2 3 4)
         (match-let* ([(list a b) '(#(1 2 3 4) 2)]                   
                      [(vector x ...) a])   
           x))
   
   (comp 2
         (let ()
           (match-define (list a b) '(1 2))
           b))
   
   (comp 'yes
         (match '(number_1 . number_2)
           [`(variable-except ,@(list vars ...))
            'no]
           [(? list?)
            'no]
           [_ 'yes]))
   
   (comp "yes"
         (match
             '((555))
           ((list-no-order (and (list 555)
                                (list-no-order 555)))
            "yes")
           (_ "no"))) ;; prints "no"
   
   (comp "yes"
         (match
             '((555))
           ((list-no-order (and (list-no-order 555)
                                (list 555)))
            "yes")
           (_ "no"))) ;; prints "yes"
   
   (comp "yes"
         (match
             '((555))
           ((list (and (list 555)
                       (list-no-order 555)))
            "yes")
           (_ "no"))) ;; prints "yes"
   
   (comp  '("a") (match "a"  ((regexp #rx"a" x) x)))
   (comp  '(#"a") 
          (match #"a"
            ((regexp #rx"a" x) x)
            [_ 'no]))
   
   (comp 'yes (match #"a" (#"a" 'yes)))
   
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]) (expand #'(match-lambda ((a ?) #f))) 'no))
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]) (expand #'(match-lambda ((?) #f))) 'no))
   
   (comp
    'yes
    (let ()
      
      (m:define-match-expander exp1
                               #:plt-match
                               (lambda (stx)
                                 (syntax-case stx ()
                                   ((_match (x y))
                                    #'(list (list x y))))))
      
      (m:define-match-expander exp2
                               #:plt-match
                               (lambda (stx)
                                 (syntax-case stx ()
                                   ((_match x y)
                                    #'(exp1 (x y))))))
      
      (define (test tp)
        (match tp ((exp2 x y) x)))
      'yes))
   (comp '(a b c)
         (match '(a b c)
           [(list-rest foo) foo]))
   (comp 2
         (let ()
           (define (foo x) (match x [1 (+ x x)]))
           (foo 1)))
   
   
   (comp 'yes
         (match (make-empt)
           [(struct empt ()) 'yes]
           [_ 'no]))
   
   (comp 'yes
         (m:match (make-empt)
                  [($ empt) 'yes]
                  [_ 'no]))
   
   (comp 3
         (match (mcons 1 2)
           [(mcons a b) (+ a b)]
           [_ 'no]))
   
   (comp 1
         (match (box 'x) ('#&x 1) (else #f)))
   
   (comp 2
         (match (vector 1 2) ('#(1 2) 2) (else #f)))

   (comp 'yes
         (with-handlers ([exn:fail? (lambda _ 'yes)]
                         [values (lambda _ 'no)])
                (match 1)
                'no))

   ;; raises error
   (comp 'yes (with-handlers ([exn:fail:syntax? (lambda _ 'yes)]) 
                (expand (quote-syntax (match '(1 x 2 y 3 z)
                                        [(list-no-order 1 2 3 rest ... e) rest]
                                        [_ 'no])))
                'no))


   ))