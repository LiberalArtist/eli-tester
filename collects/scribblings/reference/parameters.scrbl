#reader(lib "docreader.ss" "scribble")
@require["mz.ss"]

@title[#:tag "mz:parameters"]{Parameters}

See @secref["mz:parameter-model"] for basic information on the
parameter model. Parameters correspond to @defterm{preserved thread
fluids} in \first{Scsh} @cite[#:key "cite:thread-fluids" #:title
"Processes vs. User-Level Threads in Scsh" #:author "Martin Gasbichler
and Michael Sperber" #:date 2002 #:location "Scheme Workshop"].

To parameterize code in a thread- and continuation-friendly manner,
use @scheme[parameterize]. The @scheme[parameterize] form introduces a
fresh @tech{thread cell} for the dynamic extent of its body
expressions.

When a new thread is created, the @tech{parameterization} for the new
thread's initial continuation is the @tech{parameterization} of the
creator thread.  Since each parameter's @tech{thread cell} is
@tech{preserved}, the new thread ``inherits'' the parameter values of
its creating thread. When a continuation is moved from one thread to
another, settings introduced with @scheme[parameterize] effectively
move with the continuation.

In contrast, direct assignment to a parameter (by calling the
parameter procedure with a value) changes the value in a thread cell,
and therefore changes the setting only for the current
thread. Consequently, as far as the memory manager is concerned, the
value originally associated with a parameter through
@scheme[parameterize] remains reachable as long the continuation is
reachable, even if the parameter is mutated.

@defproc[(make-parameter [v any/c]
                         [guard (or/c (any/c . -> . any) false/c) #f]) 
         parameter?]{

Returns a new parameter procedure. The value of the parameter is
initialized to @scheme[v] in all threads.  If @scheme[guard] is
supplied, it is used as the parameter's guard procedure.  A guard
procedure takes one argument. Whenever the parameter procedure is
applied to an argument, the argument is passed on to the guard
procedure. The result returned by the guard procedure is used as the
new parameter value.  A guard procedure can raise an exception to
reject a change to the parameter's value. The @scheme[guard] is not
applied to the initial @scheme[v].}

@defform[(parameterize ((parameter-expr value-expr) ...)
           body ...+)]{

The result of a @scheme[parameterize] expression is the result of the
last @scheme[body]. The @scheme[parameter-expr]s determine the
parameters to set, and the @scheme[value-expr]s determine the
corresponding values to install while evaluating the
@scheme[body-expr]s. All of the @scheme[parameter-expr]s are evaluated
first (and checked with @scheme[parameter?]), then all
@scheme[value-expr]s are evaluated, and then the parameters are bound
in the continuation to preserved thread cells that contain the values
of the @scheme[value-expr]s. The last @scheme[body-expr] is in tail
position with respect to the entire @scheme[parameterize] form.

Outside the dynamic extent of a @scheme[parameterize] expression,
parameters remain bound to other thread cells. Effectively, therefore,
old parameters settings are restored as control exits the
@scheme[parameterize] expression.

If a continuation is captured during the evaluation of
@scheme[parameterize], invoking the continuation effectively
re-introduces the @tech{parameterization}, since a parameterization is
associated to a continuation via a continuation mark (see
@secref["mz:contmarks"]) using a private key.}

@examples[
(parameterize ([exit-handler (lambda (x) 'no-exit)]) 
  (exit))

(define p1 (make-parameter 1))
(define p2 (make-parameter 2))
(parameterize ([p1 3]
               [p2 (p1)]) 
  (cons (p1) (p2)))

(let ([k (let/cc out 
           (parameterize ([p1 2]) 
             (p1 3) 
             (cons (let/cc k 
                     (out k)) 
                   (p1))))]) 
  (if (procedure? k) 
      (k (p1))
      k))

(define ch (make-channel))
(parameterize ([p1 0])
  (thread (lambda ()
            (channel-put ch (cons (p1) (p2))))))
(channel-get ch)

(define k-ch (make-channel))
(define (send-k)
  (parameterize ([p1 0])
    (thread (lambda ()
              (let/ec esc
                (channel-put ch
                             ((let/cc k
                                (channel-put k-ch k)
                                (esc)))))))))
(send-k)
(thread (lambda () ((channel-get k-ch) 
                    (let ([v (p1)]) 
                      (lambda () v)))))
(channel-get ch)
(send-k)
(thread (lambda () ((channel-get k-ch) p1)))
(channel-get ch)
]

@defform[(parameterize* ((parameter-expr value-expr) ...)
           body ...+)]{

Analogous to @scheme[let*] compared to @scheme[let], @scheme[parameterize*]
is the same as a nested series of single-parameter @scheme[parameterize]
forms.}


@defproc[(make-derived-parameter [v any/c]
                                 [guard (any/c . -> . any)])
         parameter?]{

Returns a parameter procedure that sets or retrieves the same value as
@scheme[parameter], but with the additional guard @scheme[guard]
applied (before any guard associated with @scheme[parameter]).}

@defproc[(parameter? [v any/c]) boolean?]{

Returns @scheme[#t] if @scheme[v] is a parameter procedure,
@scheme[#f] otherwise.}

@defproc[(parameter-procedure=? [a parameter?][b parameter?]) boolean?]{

Returns @scheme[#t] if the parameter procedures @scheme[a] and
@scheme[b] always modify the same parameter with the same guards,
@scheme[#f] otherwise.}


@defproc[(current-parameterization) parameterization?]{Returns the
current continuation's @tech{parameterization}.}

@defproc[(call-with-parameterization [parameterization parameterization?]
                                     [thunk (-> any)]) 
         any]{
Calls @scheme[thunk] (via a tail call) with @scheme[parameterization]
as the current @tech{parameterization}.}

@defproc[(parameterization? [v any/c]) boolean?]{
Returns @scheme[#t] if @scheme[v] is a @tech{parameterization}
returned by @scheme[current-parameterization], @scheme[#f] otherwise.}