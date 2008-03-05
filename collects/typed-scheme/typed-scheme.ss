#lang scheme/base

(require "private/prims.ss" 
         "private/init-envs.ss"
         "private/extra-procs.ss"
         "private/internal-forms.ss"
         "private/base-env.ss"
         (for-syntax 
          scheme/base
          "private/type-utils.ss"
          "private/typechecker.ss" 
          "private/type-rep.ss"
          "private/provide-handling.ss"
          "private/type-environments.ss" "private/tc-utils.ss"
          "private/type-env.ss" "private/type-name-env.ss"
          "private/type-alias-env.ss"
          "private/utils.ss"
          "private/internal-forms.ss"
          "private/init-envs.ss"
          "private/type-effect-convenience.ss"
          "private/effect-rep.ss"
          "private/rep-utils.ss"
          "private/type-contract.ss"
          "private/nest.ss"
          syntax/kerncase
          scheme/match))


(provide 
 ;; provides syntax such as define: and define-typed-struct
 (all-from-out "private/prims.ss")
 ;; provides some pointless procedures - should be removed
 (all-from-out "private/extra-procs.ss"))

(provide-tnames)
(provide-extra-tnames)


(provide (rename-out [module-begin #%module-begin]
                     [with-handlers: with-handlers]
                     [top-interaction #%top-interaction]
                     [#%plain-lambda lambda]
                     [#%plain-app #%app]
                     [require require]))

(define-for-syntax catch-errors? #f)


(define-syntax (module-begin stx)
  (define module-name (syntax-property stx 'enclosing-module-name))
  ;(printf "BEGIN: ~a~n" (syntax->datum stx))
  (with-logging-to-file 
   (log-file-name (syntax-src stx) module-name)
   (syntax-case stx ()
     [(mb forms ...)
      (nest
          ([begin (set-box! typed-context? #t)
                  (start-timing module-name)]
           [with-handlers
               ([(lambda (e) (and catch-errors? (exn:fail? e) (not (exn:fail:syntax? e))))
                 (lambda (e) (tc-error "Internal error: ~a" e))])]
           [parameterize (;; this parameter is for parsing types
                          [current-tvars initial-tvar-env]
                          ;; this parameter is just for printing types
                          ;; this is a parameter to avoid dependency issues
                          [current-type-names
                           (lambda ()
                             (append 
                              (type-name-env-map (lambda (id ty)
                                                   (cons (syntax-e id) ty)))
                              (type-alias-env-map (lambda (id ty)
                                                    (cons (syntax-e id) ty)))))]
                          ;; reinitialize seen type variables
                          [type-name-references null])]
           [begin (do-time "Initialized Envs")]
           ;; local-expand the module
           ;; pmb = #%plain-module-begin                            
           [with-syntax ([new-mod 
                          (local-expand #`(#%plain-module-begin 
                                           forms ...)
                                        'module-begin 
                                        null
                                        #;stop-list)])]
           [with-syntax ([(pmb body2 ...) #'new-mod])]
           [begin (do-time "Local Expand Done")]
           [with-syntax ([after-code (parameterize ([orig-module-stx stx]
                                                    [expanded-module-stx #'new-mod])
                                       (type-check #'(body2 ...)))]
                         [check-syntax-help (syntax-property #'(void) 'disappeared-use (type-name-references))]
                         [(transformed-body ...) (remove-provides #'(body2 ...))])]
           [with-syntax ([(transformed-body ...) (change-contract-fixups #'(transformed-body ...))])])
        (do-time "Typechecked")
        (printf "checked ~a~n" module-name)
        #;(printf "created ~a types~n" (count!))
        #;(printf "tried to create ~a types~n" (all-count!))
        #;(printf "created ~a union types~n" (union-count!))
        ;; reconstruct the module with the extra code
        #'(#%module-begin transformed-body ... after-code check-syntax-help))])))

(define-syntax (top-interaction stx)
  (syntax-case stx ()
    [(_ . (module . rest))
     (eq? 'module (syntax-e #'module))
     #'(module . rest)]
    [(_ . form)     
     (nest
         ([begin (set-box! typed-context? #t)]
          [parameterize (;; this paramter is for parsing types
                         [current-tvars initial-tvar-env]
                         ;; this parameter is just for printing types
                         ;; this is a parameter to avoid dependency issues
                         [current-type-names
                          (lambda () 
                            (append 
                             (type-name-env-map (lambda (id ty)
                                                  (cons (syntax-e id) ty)))
                             (type-alias-env-map (lambda (id ty)
                                                   (cons (syntax-e id) ty)))))])]
         ;(do-time "Initialized Envs")
          ;; local-expand the module
          [let ([body2 (local-expand #'(#%top-interaction . form) 'top-level null)])]
          [parameterize ([orig-module-stx #'form]
                         [expanded-module-stx body2])]
          ;; typecheck the body, and produce syntax-time code that registers types
          [let ([type (tc-toplevel-form body2)])])
       (kernel-syntax-case body2 #f
         [(head . _)
          (or (free-identifier=? #'head #'define-values)
              (free-identifier=? #'head #'define-syntaxes)
              (free-identifier=? #'head #'require)
              (free-identifier=? #'head #'provide)
              (free-identifier=? #'head #'begin)
              (type-equal? -Void (tc-result-t type)))
          body2]
         ;; construct code to print the type
         [_           
          (nest
              ([with-syntax ([b body2]
                             [ty-str (match type
                                       [(tc-result: t)
                                        (format "- : ~a\n" t)]
                                       [x (int-err "bad type result: ~a" x)])])])
            #`(let ([v b] [type 'ty-str])
                (begin0 
                  v
                  (printf type))))]))]))


