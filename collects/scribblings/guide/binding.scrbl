#reader(lib "docreader.ss" "scribble")
@require[(lib "manual.ss" "scribble")]
@require[(lib "eval.ss" "scribble")]
@require["guide-utils.ss"]

@title{Identifiers and Binding}

The context of an expression determines the meaning of identifiers
that appear in the expression. In particular, starting a module with
the language @schememodname[big], as in

@schememod[big]

means that, within the module, the identifiers described in this guide
have the the meaning described here: @scheme[cons] refers to the
procedure that creates a pair, @scheme[car] refers to the procedure
that extracts the first element of a pair, and so on.

@margin-note{For information on the syntax of identifiers, see
@secref["guide:symbols"].}

Forms like @scheme[define], @scheme[lambda], and @scheme[let]
associate a meaning with one or more identifiers; that is, they
@defterm{bind} identifier. The part of the program for which the
binding applies is the @defterm{scope} of the binding. The set of
bindings in effect for a given expression is the expression's
@defterm{environment}.

For example, in

@schememod[
big

(define f
  (lambda (x)
    (let ([y 5])
      (+ x y))))

(f 10)
]

the @scheme[define] is a binding of @scheme[f], the @scheme[lambda]
has a binding for @scheme[x], and the @scheme[let] has a binding for
@scheme[y]. The scope of the binding for @scheme[f] is the entire
module; the scope of the @scheme[x] binding is @scheme[(let ([y 5]) (+
x y))]; and the scope of the @scheme[y] binding is just @scheme[(+ x
y)]. The environment of @scheme[(+ x y)] includes bindings for
@scheme[y], @scheme[x], and @scheme[f], as well as everything in
@schememodname[big].

A module-level @scheme[define] can bind only identifiers that are not
already bound within the module. For example, @scheme[(define cons 1)]
is a syntax error in a @schememodname[big] module, since @scheme[cons]
is provided by @schememodname[big]. A local @scheme[define] or other
binding forms, however, can give a new local binding for an identifier
that already has a binding; such a binding @defterm{shadows} the
existing binding.

@defexamples[
(define f
  (lambda (append)
    (define cons (append "ugly" "confusing"))
    (let ([append 'this-was])
      (list append cons))))
(f list)
]

Even identifiers like @scheme[define] and @scheme[lambda] get their
meanings from bindings, though they have @defterm{transformer}
bindings (whcih means that they define syntactic forms) instead of
value bindings. Since @scheme[define] has a transformer binding, the
identifier @schemeidfont{define} cannot be used by itself to get a
value. However, the normal binding for @schemeidfont{define} can be
shadowed.

@examples[
define
(eval:alts (let ([#, @schemeidfont{define} 5]) #, @schemeidfont{define}) (let ([define 5]) define))
]

Shadowing standard bindings in this way is rarely a good idea, but the
possibility is an inherent part of Scheme's flexibility.