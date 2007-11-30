(module serialize scheme/base
  (require syntax/modcollapse
	   "serialize-structs.ss")

  ;; This module implements the core serializer. The syntactic
  ;; `define-serializable-struct' layer is implemented separately
  ;; (and differently for old-style vs. new-style `define-struct').

  (provide prop:serializable
	   make-serialize-info
	   make-deserialize-info

	   ;; Checks whether a value is serializable:
	   serializable?

	   ;; The two main routines:
	   serialize
	   deserialize)

  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; serialize
  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (define (serializable? v)
    (or (serializable-struct? v)
	(boolean? v)
	(null? v)
	(number? v)
	(char? v)
	(symbol? v)
	(string? v)
	(path-for-some-system? v)
	(bytes? v)
	(vector? v)
	(pair? v)
	(mpair? v)
	(hash-table? v)
	(box? v)
	(void? v)
	(date? v)
	(arity-at-least? v)))

  ;; If a module is dynamic-required through a path,
  ;;  then it can cause simplified module paths to be paths;
  ;;  keep the literal path, but marshal it to bytes.
  (define (protect-path p)
    (if (path? p)
	(path->bytes p)
	p))
  (define (unprotect-path p)
    (if (bytes? p)
	(bytes->path p)
	p))
  
  (define (mod-to-id info mod-map cache)
    (let ([deserialize-id (serialize-info-deserialize-id info)])
      (hash-table-get 
       cache deserialize-id
       (lambda ()
	 (let ([id
		(let ([path+name
		       (cond
			[(identifier? deserialize-id)
			 (let ([b (identifier-binding deserialize-id)])
			   (cons
			    (and (list? b)
				 (if (symbol? (caddr b))
				     (caddr b)
				     (protect-path
				      (collapse-module-path-index 
				       (caddr b)
				       (build-path (serialize-info-dir info)
						   "here.ss")))))
			    (syntax-e deserialize-id)))]
			[(symbol? deserialize-id)
			 (cons #f deserialize-id)]
			[else
			 (cons
			  (if (symbol? (cdr deserialize-id))
			      (cdr deserialize-id)
			      (protect-path
			       (collapse-module-path-index 
				(cdr deserialize-id)
				(build-path (serialize-info-dir info)
					    "here.ss"))))
			  (car deserialize-id))])])
		  (hash-table-get 
		   mod-map path+name
		   (lambda ()
		     (let ([id (hash-table-count mod-map)])
		       (hash-table-put! mod-map path+name id)
		       id))))])
	   (hash-table-put! cache deserialize-id id)
	   id)))))

  (define (is-mutable? o)
    (or (and (or (mpair? o)
		 (box? o)
		 (vector? o)
		 (hash-table? o))
	     (not (immutable? o)))
	(serializable-struct? o)))

  ;; Finds a mutable object among those that make the
  ;;  current cycle.
  (define (find-mutable v cycle-stack) 
    ;; Walk back through cycle-stack to find something
    ;;  mutable. If we get to v without anything being
    ;;  mutable, then we're stuck.
    (let ([o (car cycle-stack)])
      (cond
       [(eq? o v)
	(error 'serialize "cannot serialize cycle of immutable values: ~e" v)]
       [(is-mutable? o)
	o]
       [else
	(find-mutable v (cdr cycle-stack))])))


  (define (share-id share cycle)
    (+ (hash-table-count share)
       (hash-table-count cycle)))

  ;; Traverses v to find cycles and charing. Shared
  ;;  object go in the `shared' table, and cycle-breakers go in
  ;;  `cycle'. In each case, the object is mapped to a number that is
  ;;  incremented as shared/cycle objects are discovered, so
  ;;  when the objects are deserialized, build them in reverse
  ;;  order.
  (define (find-cycles-and-sharing v cycle share)
    (let ([tmp-cycle (make-hash-table)]  ;; candidates for sharing
	  [tmp-share (make-hash-table)]  ;; candidates for cycles
	  [cycle-stack null])            ;; same as in tmpcycle, but for finding mutable
      (let loop ([v v])
	(cond
	 [(or (boolean? v)
	      (number? v)
	      (char? v)
	      (symbol? v)
	      (null? v)
	      (void? v))
	  (void)]
	 [(hash-table-get cycle v (lambda () #f))
	  ;; We already know that this value is
	  ;;  part of a cycle
	  (void)]
	 [(hash-table-get tmp-cycle v (lambda () #f))
	  ;; We've just learned that this value is
	  ;;  part of a cycle.
	  (let ([mut-v (if (is-mutable? v)
			   v
			   (find-mutable v cycle-stack))])
	    (hash-table-put! cycle mut-v (share-id share cycle))
	    (unless (eq? mut-v v)
	      ;; This value is potentially shared
	      (hash-table-put! share v (share-id share cycle))))]
	 [(hash-table-get share v (lambda () #f))
	  ;; We already know that this value is shared
	  (void)]
	 [(hash-table-get tmp-share v (lambda () #f))
	  ;; We've just learned that this value is
	  ;;  shared
	  (hash-table-put! share v (share-id share cycle))]
	 [else
	  (hash-table-put! tmp-share v #t)
	  (hash-table-put! tmp-cycle v #t)
	  (set! cycle-stack (cons v cycle-stack))
	  (cond
	   [(serializable-struct? v)
	    (let ([info (serializable-info v)])
	      (for-each loop (vector->list ((serialize-info-vectorizer info) v))))]
	   [(or (string? v)
		(bytes? v)
		(path-for-some-system? v))
	    ;; No sub-structure
	    (void)]
	   [(vector? v)
	    (for-each loop (vector->list v))]
	   [(pair? v)
	    (loop (car v)) 
	    (loop (cdr v))]
	   [(mpair? v)
	    (loop (mcar v)) 
	    (loop (mcdr v))]
	   [(box? v)
	    (loop (unbox v))]
	   [(date? v)
	    (for-each loop (cdr (vector->list (struct->vector v))))]
	   [(hash-table? v)
	    (hash-table-for-each v (lambda (k v)
				     (loop k)
				     (loop v)))]
	   [(arity-at-least? v)
	    (loop (arity-at-least-value v))]
	   [else (raise-type-error
		  'serialize
		  "serializable object"
		  v)])
	  ;; No more possibility for this object in
	  ;;  a cycle:
	  (hash-table-remove! tmp-cycle v)
	  (set! cycle-stack (cdr cycle-stack))]))))

  (define (serialize-one v share check-share? mod-map mod-map-cache)
    (define ((serial check-share?) v)
      (cond
       [(or (boolean? v)
	    (number? v)
	    (char? v)
	    (symbol? v)
	    (null? v))
	v]
       [(void? v)
	'(void)]
       [(and check-share?
	     (hash-table-get share v (lambda () #f)))
	=> (lambda (v) (cons '? v))]
       [(and (or (string? v)
		 (bytes? v))
	     (immutable? v))
	v]
       [(serializable-struct? v)
	(let ([info (serializable-info v)])
	  (cons (mod-to-id info mod-map mod-map-cache) 
		(map (serial #t)
		     (vector->list
		      ((serialize-info-vectorizer info) v)))))]
       [(or (string? v)
	    (bytes? v))
	(cons 'u v)]
       [(path-for-some-system? v)
	(list* 'p+ (path->bytes v) (path-convention-type v))]
       [(vector? v)
	(cons (if (immutable? v) 'v 'v!)
	      (map (serial #t) (vector->list v)))]
       [(pair? v)
	(let ([loop (serial #t)])
	  (cons 'c
		(cons (loop (car v)) 
		      (loop (cdr v)))))]
       [(mpair? v)
	(let ([loop (serial #t)])
	  (cons 'm
		(cons (loop (mcar v)) 
		      (loop (mcdr v)))))]
       [(box? v)
	(cons (if (immutable? v) 'b 'b!)
	      ((serial #t) (unbox v)))]
       [(hash-table? v)
	(list* 'h
	       (if (immutable? v) '- '!)
	       (append
		(if (hash-table? v 'equal) '(equal) null)
		(if (hash-table? v 'weak) '(weak) null))
	       (let ([loop (serial #t)])
		 (hash-table-map v (lambda (k v)
				     (cons (loop k)
					   (loop v))))))]
       [(date? v)
	(cons 'date
	      (map (serial #t) (cdr (vector->list (struct->vector v)))))]
       [(arity-at-least? v)
	(cons 'arity-at-least
	      ((serial #t) (arity-at-least-value v)))]
       [else (error 'serialize "shouldn't get here")]))
    ((serial check-share?) v))
  
  (define (serial-shell v mod-map mod-map-cache)
    (cond
     [(serializable-struct? v)
      (let ([info (serializable-info v)])
	(mod-to-id info mod-map mod-map-cache))]
     [(vector? v)
      (cons 'v (vector-length v))]
     [(mpair? v)
      'm]
     [(box? v)
      'b]
     [(hash-table? v)
      (cons 'h (append
		(if (hash-table? v 'equal) '(equal) null)
		(if (hash-table? v 'weak) '(weak) null)))]))

  (define (serialize v)
    (let ([mod-map (make-hash-table)]
	  [mod-map-cache (make-hash-table 'equal)]
	  [share (make-hash-table)]
	  [cycle (make-hash-table)])
      ;; First, traverse V to find cycles and sharing
      (find-cycles-and-sharing v cycle share)
      ;; To simplify, all add the cycle records to shared.
      ;;  (but keep cycle info, too).
      (hash-table-for-each cycle
			   (lambda (k v)
			     (hash-table-put! share k v)))
      (let ([ordered (map car (sort (hash-table-map share cons)
                                    (lambda (a b) (< (cdr a) (cdr b)))))])
	(let ([serializeds (map (lambda (v)
				  (if (hash-table-get cycle v (lambda () #f))
				      ;; Box indicates cycle record allocation
				      ;;  followed by normal serialization
				      (box (serial-shell v mod-map mod-map-cache))
				      ;; Otherwise, normal serialization
				      (serialize-one v share #f mod-map mod-map-cache)))
				ordered)]
	      [fixups (hash-table-map 
		       cycle
		       (lambda (v n)
			 (cons n
			       (serialize-one v share #f mod-map mod-map-cache))))]
	      [main-serialized (serialize-one v share #t mod-map mod-map-cache)]
	      [mod-map-l (map car (sort (hash-table-map mod-map cons)
                                        (lambda (a b) (< (cdr a) (cdr b)))))])
	  (list '(1) ;; serialization-format version
                (hash-table-count mod-map)
		mod-map-l
		(length serializeds)
		serializeds
		fixups
		main-serialized)))))

  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ;; deserialize
  ;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  (define (deserialize-one v share mod-map)
    (let loop ([v v])
      (cond
       [(or (boolean? v)
	    (number? v)
	    (char? v)
	    (symbol? v)
	    (null? v))
	v]
       [(string? v)
	(string->immutable-string v)]
       [(bytes? v)
	(bytes->immutable-bytes v)]
       [(number? (car v))
	;; Struct instance:
	(let ([info (vector-ref mod-map (car v))])
	  (apply (deserialize-info-maker info) (map loop (cdr v))))]
       [else
	(case (car v)
	  [(?) (vector-ref share (cdr v))]
	  [(void) (void)]
	  [(u) (let ([x (cdr v)])
		 (cond
		  [(string? x) (string-copy x)]
		  [(bytes? x) (bytes-copy x)]))]
	  [(p) (bytes->path (cdr v))]
	  [(p+) (bytes->path (cadr v) (cddr v))]
	  [(c) (cons (loop (cadr v)) (loop (cddr v)))]
	  [(c!) (cons (loop (cadr v)) (loop (cddr v)))]
	  [(m) (mcons (loop (cadr v)) (loop (cddr v)))]
	  [(v) (apply vector-immutable (map loop (cdr v)))]
	  [(v!) (list->vector (map loop (cdr v)))]
	  [(b) (box-immutable (loop (cdr v)))]
	  [(b!) (box (loop (cdr v)))]
	  [(h) (let ([al (map (lambda (p)
				(cons (loop (car p))
				      (loop (cdr p))))
			      (cdddr v))])
		 (if (eq? '! (cadr v))
		     (let ([ht (apply make-hash-table (caddr v))])
		       (for-each (lambda (p)
				   (hash-table-put! ht (car p) (cdr p)))
				 al)
		       ht)
		     (apply make-immutable-hash-table al (caddr v))))]
	  [(date) (apply make-date (map loop (cdr v)))]
	  [(arity-at-least) (make-arity-at-least (loop (cdr v)))]
	  [else (error 'serialize "ill-formed serialization")])])))

  (define (deserial-shell v mod-map fixup n)
    (cond
     [(number? v)
      ;; Struct instance
      (let* ([info (vector-ref mod-map v)])
	(let-values ([(obj fix) ((deserialize-info-cycle-maker info))])
	  (vector-set! fixup n fix)
	  obj))]
     [(pair? v)
      (case (car v)
	[(v)
	 ;; Vector 
	 (let* ([m (cdr v)]
		[v0 (make-vector m #f)])
	   (vector-set! fixup n (lambda (v)
				  (let loop ([i m])
				    (unless (zero? i)
				      (let ([i (sub1 i)])
					(vector-set! v0 i (vector-ref v i))
					(loop i))))))
	   v0)]
	[(h)
	 ;; Hash table
	 (let ([ht0 (make-hash-table)])
	   (vector-set! fixup n (lambda (ht)
				  (hash-table-for-each 
				   ht
				   (lambda (k v)
				     (hash-table-put! ht0 k v)))))
	   ht0)])]
     [else
      (case v
        [(c)
         (let ([c (cons #f #f)])
	   (vector-set! fixup n (lambda (p)
                                  (error 'deserialize "cannot restore pair in cycle")))
	   c)]
	[(m) 
	 (let ([p0 (mcons #f #f)])
	   (vector-set! fixup n (lambda (p)
				  (set-mcar! p0 (mcar p))
				  (set-mcdr! p0 (mcdr p))))
	   p0)]
	[(b)
	 (let ([b0 (box #f)])
	   (vector-set! fixup n (lambda (b)
				  (set-box! b0 (unbox b))))
	   b0)]
	[(date)
         (error 'deserialize "cannot restore date in cycle")]
	[(arity-at-least)
         (error 'deserialize "cannot restore arity-at-least in cycle")])]))

  (define (deserialize l)
    (let-values ([(vers l)
                  (if (pair? (car l))
                      (values (caar l) (cdr l))
                      (values 0 l))])
      (let ([mod-map (make-vector (list-ref l 0))]
            [mod-map-l (list-ref l 1)]
            [share-n (list-ref l 2)]
            [shares (list-ref l 3)]
            [fixups (list-ref l 4)]
            [result (list-ref l 5)])
        ;; Load constructor mapping
        (let loop ([n 0][l mod-map-l])
          (unless (null? l)
            (let* ([path+name (car l)]
                   [des (if (car path+name)
                            (dynamic-require (unprotect-path (car path+name))
                                             (cdr path+name))
                            (namespace-variable-value (cdr path+name)))])
              ;; Register maker and struct type:
              (vector-set! mod-map n des))
            (loop (add1 n) (cdr l))))
        ;; Create vector for sharing:
        (let ([share (make-vector share-n #f)]
              [fixup (make-vector share-n #f)])
          ;; Deserialize into sharing array:
          (let loop ([n 0][l shares])
            (unless (= n share-n)
              (vector-set! share n
                           (let ([v (car l)])
                             (if (box? v)
                                 (deserial-shell (unbox v) mod-map fixup n)
                                 (deserialize-one v share mod-map))))
              (loop (add1 n) (cdr l))))
          ;; Fixup shell for graphs
          (for-each (lambda (n+v)
                      (let ([v (deserialize-one (cdr n+v) share mod-map)])
                        ((vector-ref fixup (car n+v)) v)))
                    fixups)
          ;; Deserialize final result. (If there's no sharing, then
          ;;  all the work is actually here.)
          (deserialize-one result share mod-map))))))