#reader(lib "docreader.ss" "scribble")
@require["mz.ss"]

@title[#:tag "mzlib:contract" #:style 'toc]{Contracts}

A @defterm{contract} controls the flow of values to ensure that the
expectations of one party are met by another party.  The
@scheme[provide/contract] form is the primary mechanism for
associating a contract with a binding.

@local-table-of-contents[]

@; ----------------------------------------

@section{Flat Contracts}

A @deftech{flat contract} can be fully checked immediately for
a given value.

@defproc[(flat-contract [predicate (any/c . -> . any/c)]) flat-contract?]{

Constructs a @tech{flat contract} from @scheme[predicate]. A value
satisfies the contract if the predicate returns a true value.}


@defproc[(flat-named-contract [type-name string?][predicate (any/c . -> . any/c)])
         flat-contract?]{

Like @scheme[flat-contract], but the first argument must be a string
used for error reporting. The string describes the type that the
predicate checks for.}

@defthing[any/c flat-contract?]{

A flat contract that accepts any value.

When using this contract as the result portion of a function contract,
consider using @scheme[any] instead; using @scheme[any] leads to
better memory performance, but it also allows multiple results.}


@defthing[none/c flat-contract?]{

A @tech{flat contract} that accepts no values.}


@defproc[(or/c [contract (or/c contract? (any/c . -> . any/c))] ...)
         contract?]{

Takes any number of predicates and higher-order contracts and returns
a contract that accepts any value that any one of the contracts
accepts, individually.

If all of the arguments are procedures or @tech{flat contracts}, the
result is a @tech{flat contract}. If only one of the arguments is a
higher-order contract, the result is a contract that just checks the
flat contracts and, if they don't pass, applies the higher-order
contract.

If there are multiple higher-order contracts, @scheme[or/c] uses
@scheme[contract-first-order-passes?] to distinguish between
them. More precisely, when an @scheme[or/c] is checked, it first
checks all of the @tech{flat contracts}. If none of them pass, it
calls @scheme[contract-first-order-passes?] with each of the
higher-order contracts. If only one returns true, @scheme[or/c] uses
that contract. If none of them return true, it signals a contract
violation. If more than one returns true, it signals an error
indicating that the @scheme[or/c] contract is malformed.

The @scheme[or/c] result tests any value by applying the contracts in
order, from left to right, with the exception that it always moves the
non-@tech{flat contracts} (if any) to the end, checking them last.}
 
\scmutilsectiono{and/c}{contract}{contract}

@defproc[(and/c [contract (or/c contract? (any/c . -> . any/c))] ...)
         contract?]{

Takes any number of contracts and returns a contract that checks that
accepts any value that satisfies all of the contracts, simultaneously.

If all of the arguments are procedures or @tech{flat contracts},
the result is a @tech{flat contract}.

The contract produced by @scheme[and/c] tests any value by applying
the contracts in order, from left to right.}


@defproc[(not/c [flat-contract (or/c flat-contract? (any/c . -> . any/c))]) 
         flat-contract?]{

Accepts a flat contracts or a predicate and returns a flat contract
that checks the inverse of the argument.}


@defproc[(=/c [z number?]) flat-contract?]{

Returns a flat contract that requires the input to be a number and
@scheme[=] to @scheme[z].}


@defproc[(</c [n real?]) flat-contract?]{

Returns a flat contract that requires the input to be a number and
@scheme[<] to @scheme[n].}


@defproc[(>/c [n number?]) flat-contract?]{
Like @scheme[</c], but for @scheme[>].}


@defproc[(<=/c [n number?]) flat-contract?]{
Like @scheme[</c], but for @scheme[<=].}


@defproc[(>=/c [n number?]) flat-contract?]{
Like @scheme[</c], but for @scheme[>=].}


@defproc[(real-in [n real?][m meal?]) flat-contract?]{

Returns a flat contract that requires the input to be a real number
between @scheme[n] and @scheme[m], inclusive.}


@defproc[(integer-in [j exact-integer?][k exact-integer?]) flat-contract?]

Returns a flat contract that requires the input to be an exact integer
between @scheme[j] and @scheme[k], inclusive.}


@defthing[natural-number/c flat-contract?]{

A flat contract that requires the input to be an exact non-negative integer.}


@defproc[(string/len [len nonnegative-exact-integer?]) flat-contract?]{

Returns a flat contract that recognizes strings that have fewer than
@scheme[len] characters.}


@defthing[false/c flat-contract?]{

A flat contract that recognizes @scheme[#f].}


@defthing[printable/c flat-contract?]{

A flat contract that recognizes values that can be written out and
read back in with @scheme[write] and @scheme[read].}


@defproc[(one-of/c [v any/c] ...+) flat-contract?]{

Accepts any number of atomic values and returns a flat contract that
recognizes those values, using @scheme[eqv?]  as the comparison
predicate.  For the purposes of @scheme[one-of/c], atomic values are
defined to be: characters, symbols, booleans, null keywords, numbers,
void, and undefined.}


@defproc[(symbols/c [sym symbol?] ...+) flat-contract?]{

Accepts any number of symbols and returns a flat contract that
recognizes those symbols.}


@defproc[(is-a?/class [type? (or/c class? interface?)]) flat-contract?]{

Accepts a class or interface and returns a flat contract that
recognizes objects that instantiate the class/interface.}


@defproc[(implementation?/c [interface interface?]) flat-contract?]{

Returns a flat contract that recognizes classes that implement
@scheme[interface].}


@defproc[(subclass?/c [class class?]) flat-contract?]{

Returns a flat-contract that recognizes classes that
are subclasses of @scheme[class].}


@defproc[(vectorof [c (or/c flat-contract? (any/c . -> . any/c))]) flat-contract?]{

Accepts a @tech{flat contract} (or a predicate that is converted to a
flat contract via @scheme[flat-contract]) and returns a flat contract
that checks for vectors whose elements match the original contract.}


@defproc[(vector-immutableof [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Like @scheme[vectorof], but the contract needs not be a @tech{flat
contract}. Beware that when this contract is applied to a
value, the result is not @scheme[eq?] to the input.}


@defproc[(vector/c [c (or/c flat-contract? (any/c . -> . any/c))] ...) flat-contract?]{

Accepts any number of flat contracts (or predicates that are converted
to flat contracts via @scheme[flat-contract]) and returns a
flat-contract that recognizes vectors. The number of elements in the
vector must match the number of arguments supplied to
@scheme[vector/c], and each element of the vector must match the
corresponding flat contract.}


@defproc[(vector-immutable/c [c (or/c contract? (any/c . -> . any/c))] ...) contract?]{

Like @scheme[vector/c], but the individual contracts need not be
@tech{flat contracts}. Beware that when this contract is applied to a
value, the result is not @scheme[eq?] to the input.}


@defproc[(box/c [c (or/c flat-contract? (any/c . -> . any/c))]) flat-contract?]{

Returns a flat-contract that recognizes boxes. The content of the box
must match @scheme[c].}


@defproc[(box-immutable/c [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Like @scheme[box/c], but @scheme[c] need not be @tech{flat
contract}. Beware that when this contract is applied to a value, the
result is not @scheme[eq?] to the input.}


@defproc[(list-mutableof [c (or/c flat-contract? (any/c . -> . any/c))]) flat-contract?]{

Accepts a @tech{flat contract} (or a predicate that is converted to a
flat contract via @scheme[flat-contract]) and returns a flat contract
that checks for lists and mutable lists whose elements match the
original contract.}


@defproc[(listof [c (or/c contract? (any/c . -> . any/c))]) contract?]{

Like @scheme[list-mutableof], but does recognize mutable lists, and
the contract need not be a @tech{flat contract}. Beware that when this
contract is applied to a value, the result is not @scheme[eq?] to the
input.}


@defproc[(cons-mutable/c [car-c flat-contract?][cdr-c flat-contract?]) flat-contract?]{

Returns a flat contract that recognizes apirs or mutable pairs whose
first and second elements match @scheme[car-c] and @scheme[cdr-c],
respectively.}

@defproc[(cons/c [car-c contract?][cdr-c contract?]) contract?]{

Like @scheme[cons-mutable/c], but does recognize mutable pairs, and
the contracts need not be @tech{flat contracts}. Beware that when this
contract is applied to a value, the result is not @scheme[eq?] to the
input.}


@defproc[(list-mutable/c [c (or/c flat-contract? (any/c . -> . any/c))] ...) flat-contract?]{

Accepts any number of flat contracts (or predicates that are converted
to flat contracts via @scheme[flat-contract]) and returns a
flat-contract that recognizes mutable and immutable lists. The number
of elements in the list must match the number of arguments supplied to
@scheme[vector/c], and each element of the list must match the
corresponding flat contract.}


@defproc[(list/c [c (or/c contract? (any/c . -> . any/c))] ...) contract?]{

Like @scheme[list-mutable/c], but does not recognize mutable lists,
and the individual contracts need not be @tech{flat contracts}. Beware
that when this contract is applied to a value, the result is not
@scheme[eq?] to the input.}


@defproc[(syntax/c [c flat-contract?]) flat-contract?]{

Produces a flat contract that recognizes syntax objects whose
@scheme[syntax-e] content matches @scheme[c].}


@defform[(struct/c struct-id flat-contract-expr ...)]{

Produces a flat contract that recognizes instances of the structure
type named by @scheme[struct-id], and whose field values match the
@tech{flat contracts} produced by the @scheme[flat-contract-expr]s.}


@defproc[(parameter/c [c contract?]) contract?]{

Produces a contract on parameters whose values must match
@scheme[contract].}


@defform[(flat-rec-contract id flat-contract-expr ...)]

Constructs a recursive @tech{flat contract}. A
@scheme[flat-contract-expr] can refer to @scheme[id] to refer
recursively to the generated contract.

For example, the contract

@schemeblock[
   (flat-rec-contract sexp
     (cons/c sexp sexp)
     number?
     symbol?)
]

is a flat contract that checks for (a limited form of)
S-expressions. It says that an @scheme[sexp] is either two
@scheme[sexp] combined with @scheme[cons], or a number, or a symbol.

Note that if the contract is applied to a circular value, contract
checking will not terminate.}


@defform[(flat-murec-contract ([id flat-contract-expr ...] ...) body ...+)]{

A generalization of @scheme[flat-rec-contracts] for defining several
mutually recursive flat contracts simultaneously. Each @scheme[id] is
visible in the entire @scheme[flat-murec-contract] form, and the
result of the final @scheme[body] is the result of the entire form.}


@defidform[any]{

The @scheme[any] form can only be used in a result position of
contracts like @scheme[->]. Using @scheme[any] elsewhere is a syntax
error.}


@; ------------------------------------------------------------------------

@section{Function Contracts}

A @deftech{function contract} wraps a procedure to delay
checks for its arguments and results.

@defform*[#:literals (any)
          [(-> expr ... res-expr)
           (-> expr ... any)]]{

Produces a contract for a function that accepts a fixed number of
arguments and returns either a single result or an unspecified number
of results (the latter when @scheme[any] is specified).

Each @scheme[expr] is a contract on the argument to a function, and
either @scheme[res-expr] or @scheme[any] specifies the result
contract. Each @scheme[expr] or @scheme[res-expr] must produce a
contract or a predicate.

For example,

@schemeblock[(integer? boolean? . -> . integer?)] 

produces a contract on functions of two arguments. The first argument
must be an integer, and the second argument must be a boolean. The
function must produce an integer. (This example uses Scheme's infix
notation so that the @scheme[->] appears in a suggestive place; see
@secref["mz:parse-pair"]).

If @scheme[any] is used as the last argument to @scheme[->], no
contract checking is performed on the result of the function, and
tail-recursion is preserved. Note that the function may return
multiple values in that case.}


@defform*[#:literals (any)
          [(->* (expr ...) (res-expr ...))
           (->* (expr ...) rest-expr (res-expr ...))
           (->* (expr ...) any)
           (->* (expr ...) rest-expr any)]]{

Like @scheme[->], but for functions that return multiple results
and/or have ``rest'' arguments. The @scheme[expr]s specify contracts
on the initial arguments, and @scheme[rest-expr] (if supplied)
specifies a contract on an additional ``rest'' argument, which is
always a list. Each @scheme[res-expr] specifies a contract on a
result from the function.

For example, a function that accepts one or more integer arguments and
returns one boolean would have the following contract:

@schemeblock[
((integer?) (listof integer?) . ->* . (boolean?))
]}


@defform[(->d expr ... res-gen-expr)]{

Like @scheme[->], but instead of a @scheme[_res-expr] to produce a
result contract, @scheme[res-gen-expr] should produce a function
that accepts that arguments and returns as many contracts as the
function should produce values; each contract is associated with the
corresponding result.

For example, the following contract is satisfied by @scheme[sqrt] when
@scheme[sqrt] is applied to small numbers:

@schemeblock[
(number?
 . ->d .
 (lambda (in)
   (lambda (out)
     (and (number? out)
          (< (abs (- (* out out) in)) 0.01)))))
]

This contract says that the input must be a number and that the
difference between the square of the result and the original number is
less than @scheme[0.01].}

@defform*[[(->d* (expr ...) expr res-gen-expr)
           (->d* (expr ...) res-gen-expr)]]{

Like @scheme[->*], but with @scheme[res-gen-expr] like @scheme[->d].}


@defform*[#:literals (any values)
          [(->r ([id expr] ...) res-expr)
           (->r ([id expr] ...) any)
           (->r ([id expr] ...) (values [res-id res-expr] ...))
           (->r ([id expr] ...) id rest-expr res-expr)
           (->r ([id expr] ...) id rest-expr any)
           (->r ([id expr] ...) id rest-expr (values [res-id res-expr] ...))]]{
              

Produces a contract where allowed arguments to a function may all
depend on each other, and where the allowed result of the function may
depend on all of the arguments. The cases with a @scheme[rest-expr]
are analogous to @scheme[->*] to support rest arguments.

Each of the @scheme[id]s names one of the actual arguments to the
function with the contract, an each @scheme[id] is bound in all
@scheme[expr]s, the @scheme[res-expr] (if supplied), and
@scheme[res-expr]s (if supplied). An @scheme[any] result
specification is treated as in @scheme[->]. A @scheme[values] result
specification indicates multiple result values, each with the
corresponding contract; the @scheme[res-id]s are bound only in the
@scheme[res-expr]s to the corresponding results.

For example, the following contract specifies a function that accepts
three arguments where the second argument and the result must both be
between the first:

@schemeblock[
(->r ([x number?] [y (and/c (>=/c x) (<=/c z))] [z number?])
     (and/c number? (>=/c x) (<=/c z)))
]

The contract

@schemeblock[
(->r () (values [x number?]
                [y (and/c (>=/c x) (<=/c z))]
                [z number?]))
]

matches a function that accepts no arguments and that returns three
numeric values that are in ascending order.}


@defform*[[(->pp ([id expr] ...) pre-expr expr res-id post-expr)
           (->pp ([id expr] ...) pre-expr any)
           (->pp ([id expr] ...) pre-expr (values [id expr] ...) post-expr)]]{

Generalizes @scheme[->r] (without ``rest'' arguments) to support pre-
and post-condition expression. The @scheme[id]s are bound in
@scheme[pre-expr] and @scheme[post-expr], and @scheme[res-id] (if
specified) corresponds to the result value and is bound in
@scheme[post-id].

If @scheme[pre-expr] evaluates to @scheme[#f], the caller is blamed.
If @scheme[post-expr] evaluates to @scheme[#f], the function itself is
blamed.}

@defform*[[(->pp-rest ([id expr] ...) id expr pre-expr res-expr res-id post-expr)
           (->pp-rest ([id expr] ...) id expr pre-expr any)
           (->pp-rest ([id expr] ...) id expr pre-expr 
                      (values [id expr] ...) post-expr)]]{

Like @scheme[->pp], but for the ``rest''-argument cases of
@scheme[->r].}


@defform[(case-> arrow-contract-expr ...)]{

Constructs a contract for a @scheme[case-lambda] procedure. Its
arguments must all be function contracts, built by one of @scheme[->],
@scheme[->d], @scheme[->*], @scheme[->d*], @scheme[->r],
@scheme[->pp], or @scheme[->pp-rest].}


@defform*[#:literals (any)
          [(opt-> (req-expr ...) (opt-expr ...) res-expr)
           (opt-> (req-expr ...) (opt-expr ...) any)]]{

Like @scheme[->], but for a function with a fixed number of optional
by-position arguments. Each @scheme[req-expr] corresponds to a
required argument, and each @scheme[opt-expr] corresponds to an
optional argument.}


@defform*[#:literals (any)
          [(opt->* (req-expr ...) (opt-expr ...) (res-expr ...))
           (opt->* (req-expr ...) (opt-expr ...) any)]]{

Like @scheme[opt->], but with support for multiple results as in
@scheme[->*].}


@defform[(unconstrained-domain-> res-expr ...)]{

Constructs a contract that accepts a function, but makes no constraint
on the function's domain. The @scheme[res-expr]s determine the number
of results and the contract for each result.

Generally, this contract must be combined with another contract to
ensure that the domain is actually known to be able to safely call the
function itself.

For example, the contract

@schemeblock[
(provide/contract 
 [f (->r ([size natural-number/c]
          [proc (and/c (unconstrained-domain-> number?)
                       (lambda (p) 
                         (procedure-arity-includes? p size)))])
         number?)])
]

says that the function @scheme[f] accepts a natural number
and a function. The domain of the function that @scheme[f]
accepts must include a case for @scheme[size] arguments,
meaning that @scheme[f] can safely supply @scheme[size]
arguments to its input.

For example, the following is a definition of @scheme[f] that cannot
be blamed using the above contract:

@schemeblock[
(define (f i g) 
  (apply g (build-list i add1)))
]}


@defform[(promise/c expr)]{

Constructs a contract on a promise. The contract does not force the
promise, but when the promise is forced, the contract checks that the
result value meets the contract produced by @scheme[expr].}

@; ------------------------------------------------------------------------

@section{Lazy Data-structure Contracts}

@defform[
(define-contract-struct id (field-id ...))
]{

Like @scheme[define-struct], but with two differences: it does not
define field mutators, and it does define two contract constructors:
@scheme[id]@schemeidfont{/c} and @scheme[id]@schemeidfont{/dc}. The
first is a procedure that accepts as many arguments as there are
fields and returns a contract for struct values whose fields match the
arguments. The second is a syntactic form that also produces contracts
on the structs, but the contracts on later fields may depend on the
values of earlier fields. 

The generated contract combinators are @italic{lazy}: they only verify
the contract holds for the portion of some data structure that is
actually inspected. More precisely, a lazy data structure contract is
not checked until a selector extracts a field of a struct.

@specsubform/subs[
(#,(elem (scheme id) (schemeidfont "/dc")) field-spec ...)

([field-spec
  [field-id contract-expr]
  [field-id (field-id ...) contract-expr]])
]{

In each @scheme[field-spec] case, the first @scheme[field-id]
specifies which field the contract applies to; the fields must be
specified in the same order as the original
@scheme[define-contract-struct]. The first case is for when the
contract on the field does not depend on the value of any other
field. The second case is for when the contract on the field does
depend on some other fields, and the parenthesized @scheme[field-id]s
indicate which fields it depends on; these dependencies can only be to
earlier fields.}

As an example, consider the following module:

@begin[
#reader(lib "comment-reader.ss" "scribble")
[schemeblock
(module product mzscheme
  (require (lib "contract.ss"))

  (define-contract-struct kons (hd tl))
  
  ;; @scheme[sorted-list/gt : number -> contract]
  ;; produces a contract that accepts
  ;; sorted kons-lists whose elements
  ;; are all greater than @scheme[num].
  (define (sorted-list/gt num)
    (or/c null?
          (kons/dc [hd (>=/c num)]
                   [tl (hd) (sorted-list/gt hd)])))
  
  ;; @scheme[product : kons-list -> number]
  ;; computes the product of the values
  ;; in the list. if the list contains
  ;; zero, it avoids traversing the rest
  ;; of the list.
  (define (product l)
    (cond
      [(null? l) 1]
      [else
       (if (zero? (kons-hd l))
           0
           (* (kons-hd l) 
              (product (kons-tl l))))]))
  
  (provide kons? make-kons kons-hd kons-tl)
  (provide/contract [product (-> (sorted-list/gt -inf.0) number?)]))
]]

The module provides a single function, @scheme[product] whose contract
indicates that it accepts sorted lists of numbers and produces
numbers. Using an ordinary flat contract for sorted lists, the product
function cannot avoid traversing having its entire argument be
traversed, since the contract checker will traverse it before the
function is called. As written above, however, when the product
function aborts the traversal of the list, the contract checking also
stops, since the @scheme[kons/dc] contract constructor generates a
lazy contract.}

@; ------------------------------------------------------------------------

@section{Object and Class Contracts}

@defform/subs[
#:literals (field opt-> opt->* case-> -> ->* ->d ->d* ->r ->pp ->pp-rest)

(object-contract member-spec ...)

([member-spec
  (method-id method-contract)
  (field field-id contract-expr)]

 [method-contract
   (opt-> (required-contract-expr ...)
          (optional-contract-expr ...)
          any)
   (opt-> (required-contract-expr ...)
          (optional-contract-expr ...)
          result-contract-expr)
   (opt->* (required-contract-expr ...)
           (optional-contract-expr ...)
           (result-contract-expr ...))
   (case-> arrow-contract ...)
   arrow-contract]

 [arrow-contract
   (-> expr ... res-expr)
   (-> expr ... (values res-expr ...))
   (->* (expr ...) (res-expr ...))
   (->* (expr ...) rest-expr (res-expr ...))
   (->d expr ... res-proc-expr)
   (->d* (expr ...) res-proc-expr)
   (->d* (expr ...) rest-expr res-gen-expr)
   (->r ((id expr) ...) expr)
   (->r ((id expr) ...) id expr expr)
   (->pp ((id expr) ...) pre-expr 
              res-expr res-id post-expr)
   (->pp ((id expr) ...) pre-expr any)
   (->pp ((id expr) ...) pre-expr 
              (values (id expr) ...) post-expr)
   (->pp-rest ((id expr) ...) id expr pre-expr 
              res-expr res-id post-expr)
   (->pp-rest ((id expr) ...) id expr pre-expr any)
   (->pp-rest ((id expr) ...) id expr pre-expr 
              (values (id expr) ...) post-expr)])]{

Produces a contract for an object (see @secref["mzlib:class"]).

Each of the contracts for a method has the same semantics as the
corresponding function contract, but the syntax of the method contract
must be written directly in the body of the object-contract---much
like the way that methods in class definitions use the same syntax as
regular function definitions, but cannot be arbitrary procedures.  The
only exception is that the @scheme[->r], @scheme[->pp], and
@scheme[->pp-rest] contracts implicitly bind @scheme[this] to the
object itself.}


@defthing[mixin-contract contract?]{

A @tech{function contract} that recognizes mixins. It guarantees that
the input to the function is a class and the result of the function is
a subclass of the input.}

@defproc[(make-mixin-contract [type (or/c class? interface?)] ...) contract?]{

Produces a @tech{function contract} that guarantees the input to the
function is a class that implements/subclasses each @scheme[type], and
that the result of the function is a subclass of the input.}

@; ------------------------------------------------------------------------

@section{Attaching Contracts to Values}

@defform/subs[
#:literals (struct rename)
(provide/contract p/c-item ...)
([p/c-item
  (struct id ((id contract-expr) ...))
  (struct (id identifier) ((id contract-expr) ...))
  (rename orig-id id contract-expr)
  (id contract-expr)])]{

Can only appear at the top-level of a @scheme[module]. As with
@scheme[provide], each @scheme[id] is provided from the module. In
addition, clients of the module must live up to the contract specified
by @scheme[contract-expr] for each export.

The @scheme[provide/contract] form treats modules as units of
blame. The module that defines the provided variable is expected to
meet the positive (co-variant) positions of the contract. Each module
that imports the provided variable must obey the negative
(contra-variant) positions of the contract.

Only uses of the contracted variable outside the module are
checked. Inside the module, no contract checking occurs.

The @scheme[rename] form of a @scheme[provide/contract] exports the
first variable (the internal name) with the name specified by the
second variable (the external name).

The @scheme[struct] form of a @scheme[provide/contract] clause
provides a structure definition, and each field has a contract that
dictates the contents of the fields. The struct definition must come
before the provide clause in the module's body. If the struct has a
parent, the second @scheme[struct] form (above) must be used, with the
first name referring to the struct itself and the second name
referring to the parent struct. Unlike @scheme[define-struct],
however, all of the fields (and their contracts) must be listed. The
contract on the fields that the sub-struct shares with its parent are
only used in the contract for the sub-struct's maker, and the selector
or mutators for the super-struct are not provided.}

@defform[(define/contract id contract-expr init-value-expr)]{

Attaches the contract @scheme[contract-expr] to
@scheme[init-value-expr] and binds that to @scheme[id].

The @scheme[define/contract] form treats individual definitions as
units of blame. The definition itself is responsible for positive
(co-variant) positions of the contract and each reference to
@scheme[id] (including those in the initial value expression) must
meet the negative positions of the contract.

Error messages with @scheme[define/contract] are not as clear as those
provided by @scheme[provide/contract], because
@scheme[define/contract] cannot detect the name of the definition
where the reference to the defined variable occurs. Instead, it uses
the source location of the reference to the variable as the name of
that definition.}

@defform*[[(contract contract-expr to-protect-expr
                     positive-blame-expr negative-blame-expr)
           (contract contract-expr to-protect-expr 
                     positive-blame-expr negative-blame-expr
                     contract-source-expr)]]{

The primitive mechanism for attaching a contract to a value. The
purpose of @scheme[contract] is as a target for the expansion of some
higher-level contract specifying form.

The @scheme[contract] expression adds the contract specified by
@scheme[contract-expr] to the value produced by
@scheme[to-protect-expr]. The result of a @scheme[contract] expression
is the result of the @scheme[to-protect-expr] expression, but with the
contract specified by @scheme[contract-expr] enforced on
@scheme[to-protect-expr].

The values of @scheme[positive-blame-expr] and
@scheme[negative-blame-expr] must be symbols indicating how to assign
blame for positive and negative positions of the contract specified by
@scheme[contract-expr]. 

If specified, @scheme[contract-source-expr], indicates where the
contract was assumed. Its value must be a syntax object specifying the
source location of the location where the contract was assumed. If the
syntax object wraps a symbol, the symbol is used as the name of the
primitive whose contract was assumed. If absent, it defaults to the
source location of the @scheme[contract] expression.}