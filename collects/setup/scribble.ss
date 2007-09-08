
(module scribble mzscheme
  (require (lib "getinfo.ss" "setup")
           (lib "dirs.ss" "setup")
           (lib "class.ss")
           (lib "file.ss")
           (lib "main-collects.ss" "setup")
           (lib "base-render.ss" "scribble")
           (lib "struct.ss" "scribble")
           (lib "manual.ss" "scribble") ; really shouldn't be here... see dynamic-require-doc
           (prefix html: (lib "html-render.ss" "scribble"))
           (prefix latex: (lib "latex-render.ss" "scribble")))

  (provide setup-scribblings
           verbose)

  (define verbose (make-parameter #t))

  (define-struct doc (src-dir src-file dest-dir flags))
  (define-struct info (doc sci provides undef deps 
                           build? time out-time need-run? 
                           need-in-write? need-out-write?
                           vers rendered?))

  (define (setup-scribblings only-dirs latex-dest)
    (let* ([dirs (find-relevant-directories '(scribblings))]
           [infos (map get-info/full dirs)]
           [docs (apply
                  append
                  (map (lambda (i dir)
                         (let ([s (i 'scribblings)])
                           (if (and (list? s)
                                    (andmap (lambda (v)
                                              (and (list? v)
                                                   (<= 1 (length v) 3)
                                                   (string? (car v))
                                                   (relative-path? (car v))
                                                   (or (null? (cdr v))
                                                       (and (and (list? (cadr v))
                                                                 (andmap (lambda (i)
                                                                           (member i '(main-doc 
                                                                                       multi-page)))
                                                                         (cadr v)))
                                                            (or (null? (cddr v))
                                                                (and (path-string? (caddr v))
                                                                     (relative-path? (caddr v))))))))
                                            s))
                               (map (lambda (d)
                                      (let ([flags (if (pair? (cdr d))
                                                       (cadr d)
                                                       null)])
                                        (make-doc dir
                                                  (build-path dir (car d))
                                                  (let ([name (if (and (pair? (cdr d))
                                                                       (pair? (cddr d))
                                                                       (caddr d))
                                                                  (cadr d)
                                                                  (let-values ([(base name dir?) (split-path (car d))])
                                                                    (path-replace-suffix name #"")))])
                                                    (if (memq 'main-doc flags)
                                                        (build-path (find-doc-dir) name)
                                                        (build-path dir "compiled" "doc" name)))
                                                  flags)))
                                    s)
                               (begin
                                 (fprintf (current-error-port)
                                          " bad 'scribblings info: ~e from: ~e\n"
                                          s
                                          dir)
                                 null))))
                       infos dirs))])
      (when (ormap (can-build? only-dirs) docs)
        (let ([infos (map (get-doc-info only-dirs latex-dest) docs)])
          (let loop ([first? #t][iter 0])
            (let ([ht (make-hash-table 'equal)])
              ;; Collect definitions
              (for-each (lambda (info)
                          (for-each (lambda (k)
                                      (let ([prev (hash-table-get ht k #f)])
                                        (when (and first? prev)
                                          (fprintf (current-error-port)
                                                   "DUPLICATE tag: ~s\n  in: ~a\n and: ~a\n"
                                                   k
                                                   (doc-src-file (info-doc prev))
                                                   (doc-src-file (info-doc info))))
                                        (hash-table-put! ht k info)))
                                    (info-provides info)))
                        infos)
              ;; Build deps:
              (let ([src->info (make-hash-table 'equal)])
                (for-each (lambda (i)
                            (hash-table-put! src->info (doc-src-file (info-doc i)) i))
                          infos)
                (for-each (lambda (info)
                            (when (info-build? info)
                              (let ([one? #f]
                                    [added? #f]
                                    [deps (make-hash-table)])
                                (set-info-deps! info
                                                (map (lambda (d)
                                                       (let ([i (if (info? d)
                                                                    d
                                                                    (hash-table-get src->info d #f))])
                                                         (or i d)))
                                                     (info-deps info)))
                                (for-each (lambda (d)
                                            (let ([i (if (info? d)
                                                         d
                                                         (hash-table-get src->info d #f))])
                                              (if i
                                                  (hash-table-put! deps i #t)
                                                  (begin
                                                    (set! added? #t)
                                                    (when (verbose)
                                                      (printf " [Removed Dependency: ~a]\n"
                                                              (doc-src-file (info-doc info))))))))
                                          (info-deps info))
                                (for-each (lambda (k)
                                            (let ([i (hash-table-get ht k #f)])
                                              (if i
                                                  (when (not (hash-table-get deps i #f))
                                                    (set! added? #t)
                                                    (hash-table-put! deps i #t))
                                                  (when first?
                                                    (unless one?
                                                      (fprintf (current-error-port)
                                                               "In ~a:\n"
                                                               (doc-src-file (info-doc info)))
                                                      (set! one? #t))
                                                    (fprintf (current-error-port)
                                                             "  undefined tag: ~s\n"
                                                             k)))))
                                          (info-undef info))
                                (when added?
                                  (when (verbose)
                                    (printf " [Added Dependency: ~a]\n"
                                            (doc-src-file (info-doc info))))
                                  (set-info-deps! info (hash-table-map deps (lambda (k v) k)))
                                  (set-info-need-run?! info #t)))))
                          infos))
              ;; If a dependency changed, then we need a re-run:
              (for-each (lambda (i)
                          (unless (or (info-need-run? i)
                                      (not (info-build? i)))
                            (let ([ch (ormap (lambda (i2)
                                               (and (>= (info-out-time i2) 
                                                        (info-time i))
                                                    i2))
                                             (info-deps i))])
                              (when ch
                                (when (verbose)
                                  (printf " [Dependency: ~a\n  <- ~a]\n"
                                          (doc-src-file (info-doc i))
                                          (doc-src-file (info-doc ch))))
                                (set-info-need-run?! i #t)))))
                        infos)
              ;; Iterate, if any need to run:
              (when (and (ormap info-need-run? infos)
                         (iter . < . 30))
                ;; Build again, using dependencies
                (for-each (lambda (i)
                            (when (info-need-run? i)
                              (set-info-need-run?! i #f)
                              (build-again! latex-dest i)))
                          infos)
                (loop #f (add1 iter)))))
          ;; cache info to disk
          (unless latex-dest
            (for-each (lambda (i)
                        (when (info-need-in-write? i)
                          (write-in i)))
                      infos))))))

  (define (make-renderer latex-dest doc)
    (if latex-dest
        (new (latex:render-mixin render%)
             [dest-dir latex-dest])
        (new ((if (memq 'multi-page (doc-flags doc))
                  html:render-multi-mixin
                  values)
              (html:render-mixin render%))
             [dest-dir (if (memq 'multi-page (doc-flags doc))
                           (let-values ([(base name dir?) (split-path (doc-dest-dir doc))])
                             base)
                           (doc-dest-dir doc))])))

  (define (pick-dest latex-dest doc)
    (if latex-dest
        (build-path latex-dest (let-values ([(base name dir?) (split-path (doc-src-file doc))])
                                 (path-replace-suffix name #".tex")))
        (if (memq 'multi-page (doc-flags doc))
            (doc-dest-dir doc)
            (build-path (doc-dest-dir doc) "index.html"))))

  (define ((can-build? only-dirs) doc)
    (or (not only-dirs)
        (ormap (lambda (d)
                 (let ([d (path->directory-path d)])
                   (let loop ([dir (path->directory-path (doc-src-dir doc))])
                     (or (equal? dir d)
                         (let-values ([(base name dir?) (split-path dir)])
                           (and (path? base)
                                (loop base)))))))
               only-dirs)))

  (define (ensure-doc-prefix! src-file v)
    (let ([p (format "~a" 
                     (path->main-collects-relative src-file))])
      (if (part-tag-prefix v)
          (unless (equal? p
                          (part-tag-prefix v))
            (error 'setup 
                   "bad tag prefix: ~e for: ~a expected: ~e"
                   (part-tag-prefix v)
                   src-file
                   p))
          (set-part-tag-prefix! v p))))

  (define ((get-doc-info only-dirs latex-dest) doc)
    (let ([info-out-file (build-path (or latex-dest (doc-dest-dir doc)) "xref-out.ss")]
          [info-in-file (build-path (or latex-dest (doc-dest-dir doc)) "xref-in.ss")]
          [out-file (build-path (doc-dest-dir doc) "index.html")]
          [src-zo (let-values ([(base name dir?) (split-path (doc-src-file doc))])
                    (build-path base "compiled" (path-replace-suffix name ".zo")))]
          [renderer (make-renderer latex-dest doc)]
          [can-run? ((can-build? only-dirs) doc)])
      (let ([my-time (file-or-directory-modify-seconds out-file #f (lambda () -inf.0))]
            [info-out-time (file-or-directory-modify-seconds info-out-file #f (lambda () #f))]
            [info-in-time (file-or-directory-modify-seconds info-in-file #f (lambda () #f))]
            [vers (send renderer get-serialize-version)])
        (let ([up-to-date?
               (and info-out-time
                    info-in-time
                    (or (not can-run?)
                        (my-time
                         . >= . 
                         (file-or-directory-modify-seconds src-zo #f (lambda () +inf.0)))))])
          (printf " [~a ~a]\n"
                  (if up-to-date? "Using" "Running")
                  (doc-src-file doc))
          (if up-to-date?
              ;; Load previously calculated info:
              (with-handlers ([exn? (lambda (exn)
                                      (fprintf (current-error-port)
                                               "~a\n"
                                               (exn-message exn))
                                      (delete-file info-out-file)
                                      (delete-file info-in-file)
                                      ((get-doc-info only-dirs latex-dest) doc))])
                (let* ([v-in (with-input-from-file info-in-file read)]
                       [v-out (with-input-from-file info-out-file read)])
                  (unless (and (equal? (car v-in) (list vers (doc-flags doc)))
                               (equal? (car v-out) (list vers (doc-flags doc))))
                    (error "old info has wrong version or flags"))
                  (make-info doc
                             (list-ref v-out 1) ; sci
                             (list-ref v-out 2) ; provides
                             (list-ref v-in 1)  ; undef
                             (map string->path (list-ref v-in 2)) ; deps, in case we don't need to build...
                             can-run?
                             my-time info-out-time #f
                             #f #f
                             vers
                             #f)))
              ;; Run the doc once:
              (parameterize ([current-directory (doc-src-dir doc)])
                (let ([v (dynamic-require-doc (doc-src-file doc))]
                      [dest-dir (pick-dest latex-dest doc)])
                  (ensure-doc-prefix! (doc-src-file doc) v)
                  (let* ([ci (send renderer collect (list v) (list dest-dir))])
                    (let ([ri (send renderer resolve (list v) (list dest-dir) ci)]
                          [out-v (and info-out-time
                                      (with-handlers ([exn? (lambda (exn) #f)])
                                        (let ([v (with-input-from-file info-out-file read)])
                                          (unless (equal? (car v) (list vers (doc-flags doc)))
                                            (error "old info has wrong version or flags"))
                                          v)))])
                      (let ([sci (send renderer serialize-info ri)]
                            [defs (send renderer get-defined ci)])
                        (let ([need-out-write?
                               (or (not (equal? (list (list vers (doc-flags doc)) sci defs)
                                                out-v))
                                   (info-out-time . > . (current-seconds)))])
                          (when (verbose)
                            (when need-out-write?
                              (fprintf (current-error-port)
                                       " [New out ~a]\n"
                                       (doc-src-file doc))))
                          (make-info doc
                                     sci
                                     defs
                                     (send renderer get-undefined ri)
                                     null ; no deps, yet
                                     can-run?
                                     -inf.0
                                     (if need-out-write?
                                         (/ (current-inexact-milliseconds) 1000)
                                         info-out-time)
                                     #t
                                     can-run? need-out-write?
                                     vers
                                     #f))))))))))))
  
  (define (build-again! latex-dest info)
    (let* ([doc (info-doc info)]
           [renderer (make-renderer latex-dest doc)])
      (printf " [R~aendering ~a]\n" 
              (if (info-rendered? info)
                  "e-r"
                  "")
              (doc-src-file doc))
      (set-info-rendered?! info #t)
      (parameterize ([current-directory (doc-src-dir doc)])
        (let ([v (dynamic-require-doc (doc-src-file doc))]
              [dest-dir (pick-dest latex-dest doc)])
          (ensure-doc-prefix! (doc-src-file doc) v)
          (let* ([ci (send renderer collect (list v) (list dest-dir))])
            (for-each (lambda (i)
                        (send renderer deserialize-info (info-sci i) ci))
                      (info-deps info))
            (let ([ri (send renderer resolve (list v) (list dest-dir) ci)])
              (let ([sci (send renderer serialize-info ri)]
                    [defs (send renderer get-defined ci)]
                    [undef (send renderer get-undefined ri)])
                (let ([in-delta? (not (equal? undef (info-undef info)))]
                      [out-delta? (not (equal? (list sci defs)
                                               (list (info-sci info)
                                                     (info-provides info))))])
                  (when (verbose)
                    (printf " [~a~afor ~a]\n" 
                            (if in-delta?
                                "New in "
                                "")
                            (if out-delta?
                                "New out "
                                (if in-delta?
                                    ""
                                    "No change "))
                            (doc-src-file doc)))
                  (when out-delta?
                    (set-info-out-time! info (/ (current-inexact-milliseconds) 1000)))
                  (set-info-sci! info sci)
                  (set-info-provides! info defs)
                  (set-info-undef! info undef)
                  (when in-delta?
                    (set-info-deps! info null)) ; recompute deps outside
                  (when (or out-delta?
                            (info-need-out-write? info))
                    (unless latex-dest
                      (write-out info))
                    (set-info-need-out-write?! info #f))
                  (when in-delta?
                    (set-info-need-in-write?! info #t))
                  (unless latex-dest
                    (let ([dir (doc-dest-dir doc)])
                      (unless (directory-exists? dir)
                        (make-directory dir))
                      (for-each (lambda (f)
                                  (when (regexp-match? #"[.]html$" (path-element->bytes f))
                                    (delete-file (build-path dir f))))
                                (directory-list dir))))
                  (send renderer render (list v) (list dest-dir) ri)
                  (set-info-time! info (/ (current-inexact-milliseconds) 1000))
                  (void)))))))))

  (define (dynamic-require-doc path)
    ;; Use a separate namespace so that we don't end up with all the documentation
    ;;  loaded at once.
    ;; Use a custodian to compensate for examples executed during the build
    ;;  that may not be entirely clean (e.g., leaves a stuck thread).
    (let ([p (make-namespace)]
          [c (make-custodian)]
          [ch (make-channel)])
      (parameterize ([current-custodian c])
        (namespace-attach-module (current-namespace) '(lib "base-render.ss" "scribble") p)
        (namespace-attach-module (current-namespace) '(lib "html-render.ss" "scribble") p)
        ;; This is here for de-serialization; we need a better repair than
        ;;  hard-wiring the "manual.ss" library:
        (namespace-attach-module (current-namespace) '(lib "manual.ss" "scribble") p)
        (parameterize ([current-namespace p])
          (call-in-nested-thread
           (lambda () 
             (dynamic-require path 'doc)))))))

  (define (write- info name sel)
    (let* ([doc (info-doc info)]
           [info-file (build-path (doc-dest-dir doc) name)])
      (when (verbose)
        (printf " [Caching ~a]\n" info-file))
      (with-output-to-file info-file
        (lambda ()
          (write ((sel (lambda ()
                        (list (list (info-vers info) (doc-flags doc))
                              (info-sci info)
                              (info-provides info)))
                      (lambda ()
                        (list
                         (list (info-vers info) (doc-flags doc))
                         (info-undef info)
                         (map (lambda (i)
                                (path->string (doc-src-file (info-doc i))))
                              (info-deps info))))))))
        'truncate/replace)))

  (define (write-out info)
    (make-directory* (doc-dest-dir (info-doc info)))
    (write- info "xref-out.ss" (lambda (o i) o)))
  (define (write-in info)
    (make-directory* (doc-dest-dir (info-doc info)))
    (write- info "xref-in.ss" (lambda (o i) i)))

  )