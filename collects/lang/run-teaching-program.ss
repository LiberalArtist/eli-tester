#lang scheme/base

(require "stepper-language-interface.ss"           
         "debugger-language-interface.ss"
         stepper/private/shared
         scheme/class
         scheme/contract)

(provide/contract
 [run-teaching-program (-> input-port?
                           any/c
                           (-> any/c input-port? any/c)
                           any/c
                           (listof any/c)
                           (object-contract [display-results/void (-> (listof any/c) any)])
                           any)])

(define (run-teaching-program port settings reader language-module teachpacks rep)
  (let ([state 'init]
        ;; state : 'init => 'require => 'done-or-exn
        
        ;; in state 'done-or-exn, if this is an exn, we raise it
        ;; otherwise, we just return eof
        [saved-exn #f])
    
    (lambda ()
      (case state
        [(init)
         (set! state 'require)
         (with-handlers ([exn:fail?
                          (λ (x)
                            (set! saved-exn x)
                            (expand
                             (datum->syntax
                              #f
                              `(,#'module #%htdp ,language-module 
                                          ,@(map (λ (x) 
                                                   `(require ,x))
                                                 teachpacks)))))])
           (let ([body-exps 
                  (let loop ()
                    (let ([result (reader (object-name port) port)])
                      (if (eof-object? result)
                          null
                          (cons result (loop)))))])
             (for-each
              (λ (tp)
                (with-handlers ((exn:fail? (λ (x) (error 'teachpack (missing-tp-message tp)))))
                  (unless (file-exists? (build-path (apply collection-path (cddr tp))
                                                    (cadr tp)))
                    (error))))
              teachpacks)
             (rewrite-module
              settings
              (expand
               (datum->syntax
                #f
                `(,#'module #%htdp ,language-module 
                            ,@(map (λ (x) `(require ,x)) teachpacks)
                            ,@body-exps)))
              rep)))]
        [(require) 
         (set! state 'done-or-exn)
         (stepper-syntax-property
          (syntax
           (let ([done-already? #f])
             (dynamic-wind
              void
              (lambda () 
                (dynamic-require ''#%htdp #f))  ;; work around a bug in dynamic-require
              (lambda () 
                (unless done-already?
                  (set! done-already? #t)
                  (current-namespace (module->namespace ''#%htdp)))))))
          'stepper-skip-completely
          #t)]
        [(done-or-exn)
         (cond
           [saved-exn
            (raise saved-exn)]
           [else
            eof])]))))

(define (missing-tp-message x)
  (let* ([m (regexp-match #rx"/([^/]*)$" (cadr x))]
         [name (if m
                   (cadr m)
                   (cadr x))])
    (format "the teachpack '~a' was not found" name)))

;; rewrite-module : settings syntax (is-a?/c interactions-text<%>) -> syntax
;; rewrites te module to print out results of non-definitions
(define (rewrite-module settings stx rep)
  (syntax-case stx (module #%plain-module-begin)
    [(module name lang (#%plain-module-begin bodies ...))
     (with-syntax ([(rewritten-bodies ...) 
                    (rewrite-bodies (syntax->list (syntax (bodies ...))) rep)])
       #`(module name lang
           (#%plain-module-begin 
            rewritten-bodies ...)))]
    [else
     (raise-syntax-error 'htdp-languages "internal error .1")]))



;; rewrite-bodies : (listof syntax) (is-a?/c interactions-text<%>) -> syntax
(define (rewrite-bodies bodies rep)
  (let loop ([bodies bodies])
    (cond
      [(null? bodies) null]
      [else
       (let ([body (car bodies)])
         (syntax-case body (#%require define-values define-syntaxes define-values-for-syntax #%provide)
           [(define-values (new-vars ...) e)
            (cons body (loop (cdr bodies)))]
           [(define-syntaxes (new-vars ...) e)
            (cons body (loop (cdr bodies)))]
           [(define-values-for-syntax (new-vars ...) e)
            (cons body (loop (cdr bodies)))]
           [(#%require specs ...)
            (cons body (loop (cdr bodies)))]
           [(#%provide specs ...)
            (loop (cdr bodies))]
           [else 
            (let ([new-exp
                   (with-syntax ([body body]
                                 [print-results
                                  (lambda results
                                    (when rep
                                      (send rep display-results/void results)))])
                     (syntax 
                      (call-with-values
                       (lambda () body)
                       print-results)))])
              (cons new-exp (loop (cdr bodies))))]))])))