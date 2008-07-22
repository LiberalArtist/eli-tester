#lang typed-scheme

(define x
  (plambda: (a ...) ([x : Number] . [y : Number ... a])
    (ormap zero? (map add1 y))))

(define y
  (plambda: (a ...) ([x : Number] . [y : a ... a])
    (ormap null? (map list y))))