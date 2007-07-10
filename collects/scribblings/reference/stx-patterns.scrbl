#reader(lib "docreader.ss" "scribble")
@require["mz.ss"]
@require["ellipses.ss"]

@title{Pattern-Based Syntax Matching}

@defform/subs[(syntax-case stx-expr (literal-id ...)
                clause ...)
              ([clause [pattern result-expr]
                       [pattern fender-expr result-expr]]
               [pattern _
                        id
                        (pattern ...)
                        (pattern ...+ . pattern)
                        (pattern ... pattern ellipses pattern ...)
                        (pattern ... pattern ellipses pattern ... . pattern)
                        (code:line #,(tt "#")(pattern ...))
                        (code:line #,(tt "#")(pattern ... pattern ellipses pattern ...))
                        (ellipses stat-pattern)
                        const]
               [stat-pattern id
                             (stat-pattern ...)
                             (stat-pattern ...+ . stat-pattern)
                             (code:line #,(tt "#")(stat-pattern ...))
                             const]
               [ellipses #,ellipses-id])]{

Finds the first @scheme[pattern] that matches the syntax object
produced by @scheme[stx-expr], and for which the corresponding
@scheme[fender-expr] (if any) produces a true value; the result is from
the corresponding @scheme[result-expr], which is in tail position for
the @scheme[syntax-case] form. If no @scheme[clause] matches, then the
@exnraise[exn:fail:syntax].

A syntax object matches a @scheme[pattern] as follows:

 @specsubform[_]{

 A @scheme[_] pattern (i.e., an identifier with the same binding as
 @scheme[_]) matches any syntax object.}

 @specsubform[id]{

 An @scheme[id] matches any syntax object when it is not bound to
 @|ellipses-id| or @scheme[_] and does not have the same binding as
 any @scheme[literal-id]. The @scheme[id] is further bound as
 @deftech{pattern variable} for the corresponding @scheme[fender-expr]
 (if any) and @scheme[result-expr]. A pattern-variable binding is a
 transformer binding; the pattern variable can be reference only
 through forms like @scheme[syntax]. The binding's value is the syntax
 object that matched the pattern with a @deftech{depth marker} of
 @math{0}.

 An @scheme[id] that has the same binding as a @scheme[literal-id]
 matches a syntax object that is an identifier with the same binding
 in the sense of @scheme[free-identifier=?].  The match does not
 introduce any @tech{pattern variables}.}

 @specsubform[(pattern ...)]{

 A @scheme[(pattern ...)] pattern matches a syntax object whose datum
 form (i.e., without lexical information) is a list with as many
 elements as sub-@scheme[pattern]s in the pattern, and where each
 syntax object that corresponding to an element of the list matches
 the corresponding sub-@scheme[pattern].

 Any @tech{pattern variables} bound by the sub-@scheme[pattern]s are
 bound by the complete pattern; the bindings must all be distinct.}

 @specsubform[(pattern ...+ . pattern)]{

 The last @scheme[pattern] must not be a @scheme[(pattern ...)],
 @scheme[(pattern ...+ . pattern)], @scheme[(pattern ... pattern
 ellipses pattern ...)], or @scheme[(pattern ... pattern ellipses
 pattern ... . pattern)] form.

 Like the previous kind of pattern, but matches syntax objects that
 are not necessarily lists; for @math{n} sub-@scheme[pattern]s before
 the last sub-@scheme[pattern], the syntax object's datum must be a
 pair such that @math{n-1} @scheme[cdr]s produce pairs. The last
 sub-@scheme[pattern] is matched against the syntax object
 corresponding to the @math{n}th @scheme[cdr] (or the
 @scheme[datum->syntax] coercion of the datum using the nearest
 enclosing syntax object's lexical context and source location).}

 @specsubform[(pattern ... pattern ellipses pattern ...)]{

 Like the @scheme[(pattern ...)] kind of pattern, but matching a
 syntax object with any number (zero or more) elements that match the
 sub-@scheme[pattern] followed by @scheme[ellipses] in the
 corresponding position relative to other sub-@scheme[pattern]s.

 For each pattern variable bound by the sub-@scheme[pattern] followed
 by @scheme[ellipses], the larger pattern binds the same pattern
 variable to a list of values, one for each element of the syntax
 object matched to the sub-@scheme[pattern], with an incremented
 @tech{depth marker}. (The sub-@scheme[pattern] itself may contain
 @scheme[ellipses], leading to a pattern variables bound to lists of
 lists of syntax objects with a @tech{depth marker} of @math{2}, and
 so on.)}

 @specsubform[(pattern ... pattern ellipses pattern ... . pattern)]{

 Like the previous kind of pattern, but with a final
 sub-@scheme[pattern] as for @scheme[(pattern ...+ . pattern)].  The
 final @scheme[pattern] never matches a syntax object whose datum is a
 list.}

 @specsubform[(code:line #,(tt "#")(pattern ...))]{

 Like a @scheme[(pattern ...)] pattern, but matching a vector syntax object
 whose elements match the corresponding sub-@scheme[pattern]s.}

 @specsubform[(code:line #,(tt "#")(pattern ... pattern ellipses pattern ...))]{

 Like a @scheme[(pattern ... pattern ellipses pattern ...)] pattern,
 but matching a vector syntax object whose elements match the
 corresponding sub-@scheme[pattern]s.}

 @specsubform[(ellipses stat-pattern)]{

 Matches the same as @scheme[stat-pattern], which is like a @scheme[pattern],
 but identifiers with the binding @scheme[...] are treated the same as
 other @scheme[id]s.}

 @specsubform[const]{

 A @scheme[const] is any datum that does not match one of the
 preceeding forms; a syntax object matches a @scheme[const] pattern
 when its datum is @scheme[equal?] to the @scheme[quote]d
 @scheme[const].}

}

@defform[(syntax-case* stx-expr (literal-id ...) id-compare-expr
           clause ...)]{

Like @scheme[syntax-case], but @scheme[id-compare-expr] must produce a
procedure that accepts two arguments. A @scheme[literal-id] in a
@scheme[_pattern] matches an identifier for which the procedure 
returns true when given the identifier to match (as the first argument)
and the identifier in the @scheme[_pattern] (as the second argument).

In other words, @scheme[syntax-case] is like @scheme[syntax-case*] with
an @scheme[id-compare-expr] that produces @scheme[free-identifier=?].}


@defform[(with-syntax ([pattern stx-expr] ...)
           body ...+)]{

Similar to @scheme[syntax-case], in that it matches a @scheme[pattern]
to a syntax object. Unlike @scheme[syntax-case], all @scheme[pattern]s
are matched, each to the result of a corresponding @scheme[stx-expr],
and the pattern variables from all matches (which must be distinct)
are bound with a single @scheme[body] sequence. The result of the
@scheme[with-syntax] form is the result of the last @scheme[body],
which is in tail position with respect to the @scheme[with-syntax]
form.

If any @scheme[pattern] fails to match the corresponding
@scheme[stx-expr], the @exnraise[exn:fail:syntax].

A @scheme[with-syntax] form is roughly equivalent to the following
@scheme[syntax-case] form:

@schemeblock[
(syntax-case (list stx-expr ...) ()
  [(pattern ...) (let () body ...+)])
]

However, if any individual @scheme[stx-expr] produces a
non-@tech{syntax object}, then it is converted to one using
@scheme[datum->syntax] and the lexical context and source location of
the individual @scheme[stx-expr].}


@defform/subs[(syntax template)
              ([template id
                         (template-elem ...)
                         (template-elem ...+ . template)
                         (code:line #,(tt "#")(template-elem ...))
                         (ellipses stat-template)
                         const]
               [template-elem (code:line template ellipses ...)]
               [stat-template id
                              (stat-template ...)
                              (stat-template ... . stat-template)
                              (code:line #,(tt "#")(stat-template ...))
                              const]
               [ellipses #,ellipses-id])]{

Constructs a syntax object based on a @scheme[template],which can
inlude @tech{pattern variables} bound by @scheme[syntax-case] or
@scheme[with-syntax].

Template forms produce a syntax object as follows:

 @specsubform[id]{

 If @scheme[id] is bound as a @tech{pattern variable}, then
 @scheme[id] as a template produces the @tech{pattern variable}'s
 match result. Unless the @scheme[id] is a sub-@scheme[template] that is
 replicated by @scheme[ellipses] in a larger @scheme[template], the
 @tech{pattern variable}'s value must be a syntax object with a
 @tech{depth marker} of @math{0} (as opposed to a list of
 matches).

 More generally, if the @tech{pattern variable}'s value has a depth
 marker @math{n}, then it can only appear within a template where it
 is replicated by at least @math{n} @scheme[ellipses]es. In that case,
 the template will be replicated enough times to use each match result
 at least once.

 If @scheme[id] is not bound as a pattern variable, then @scheme[id]
 as a template produces @scheme[(quote-syntax id)].}

 @specsubform[(template-elem ...)]{

 Produces a syntax object whose datum is a list, and where the
 elements of the list correspond to syntax objects producesd by the
 @scheme[template-elem]s.

 A @scheme[template-elem] is a sub-@scheme[template] replicated by any
 number of @scheme[ellipses]es:

 @itemize{

  @item{If the sub-@scheme[template] is replicated by no
   @scheme[ellipses]es, then it generates a single syntax object to
   incorporate into the result syntax object.}

  @item{If the sub-@scheme[template] is replicated by one
   @scheme[ellipses], then it generates a sequence of syntax objects
   that is ``inlined'' into the resulting syntax object.

   The number of generated elements depends the values of
   @tech{pattern variables} referenced within the
   sub-@scheme[template]. There must be at least one @tech{pattern
   variable} whose value is has a @tech{depth marker} less than the
   number of @scheme[ellipses]es after the pattern variable within the
   sub-@scheme[template].

   If a @tech{pattern variable} is replicated by more
   @scheme[ellipses]es in a @scheme[template] than the @tech{depth
   marker} of its binding, then the @tech{pattern variable}'s result
   is determined normally for inner @scheme[ellipses]es (up to the
   binding's @tech{depth marker}), and then the result is replicated
   as necessary to satisfy outer @scheme[ellipses]es.}

 @item{For each @scheme[ellipses] after the first one, the preceding
   element (with earlier replicating @scheme[ellipses]s) is
   conceptually wrapped with parentheses for generating output, and
   then the wrapping parentheses are removed in the resulting syntax
   object.}}}

 @specsubform[(template-elem ... . template)]{

  Like the previous form, but the result is not necessarily a list;
  instead, the place of the empty list in resulting syntax object's
  datum is taken by the syntax object produced by @scheme[template].}

 @specsubform[(code:line #,(tt "#")(template-elem ...))]{

   Like the @scheme[(template-elem ...)] form, but producing a syntax
   object whose datum is a vector instead of a list.}

 @specsubform[(ellipses stat-template)]{

  Produces the same result as @scheme[stat-template], which is like a
  @scheme[template], but @|ellipses-id| is treated like a @scheme[id]
  (with no pattern binding).}

 @specsubform[const]{

  A @scheme[const] template is any form that does not match the
  preceding cases, and it produces the result @scheme[(quote-syntac
  const)].}

A @scheme[(#,(schemekeywordfont "syntax") template)] form is normally
abbreviated as @scheme[#'template]; see also
@secref["mz:parse-quote"]. If @scheme[template] contains no pattern
variables, then @scheme[#'template] is equivalent to
@scheme[(quote-syntax template)].}


@defform[(quasisyntax template)]{

Like @scheme[syntax], but @scheme[(#,(schemekeywordfont "unsyntax")
_expr)] and @scheme[(#,(schemekeywordfont "unsyntax-splicing") _expr)]
escape to an expression within the @scheme[template].

The @scheme[_expr] must produce a syntax object (or syntax list) to be
substituted in place of the @scheme[unsyntax] or
@scheme[unsyntax-splicing] form within the quasiquoting template, just
like @scheme[unquote] and @scheme[unquote-splicing] within
@scheme[quasiquote]. (If the escaped expression does not generate a
syntax object, it is converted to one in the same was as for the
right-hand sides of @scheme[with-syntax].)  Nested
@scheme[quasisyntax]es introduce quasiquoting layers in the same way
as nested @scheme[quasiquote]s.

Also analogous @scheme[quasiquote], the reader converts @litchar{#`}
to @scheme[quasisyntax], @litchar{#,} to @scheme[unsyntax], and
@litchar["#,@"] to @scheme[unsyntax-splicing]. See also
@secref["mz:parse-quote"].}



@defform[(unsyntax expr)]{

Illegal as an expression form. The @scheme[unsyntax] form is for use
only with a @scheme[quasisyntax] template.}


@defform[(unsyntax-splicing expr)]{

Illegal as an expression form. The @scheme[unsyntax-splicing] form is
for use only with a @scheme[quasisyntax] template.}


@defform[(syntax/loc stx-expr template)]{

Like @scheme[syntax], except that the immediate resulting syntax
object takes its source-location information from the result of
@scheme[stx-expr] (which must produce a syntax object), unless the
@scheme[template] is just a pattern variable.}


@defform[(quasisyntax/loc stx-expr template)]{

Like @scheme[quasisyntax], but with source-location assignment like
@scheme[syntax/loc].}


@defform[(syntax-rules (literal-id ...)
           [(id . pattern) template] ...)]{

Equivalent to

@schemeblock[
(lambda (stx)
  (syntax-case stx (literal-id ...)
    [(_generated-id . pattern) (syntax template)] ...))
]

where each @scheme[_generated-id] binds no identifier in the
corresponding @scheme[template].}


@defform[(syntax-id-rules (literal-id ...)
           [pattern template] ...)]{

Equivalent to

@schemeblock[
(lambda (stx)
  (make-set!-transformer
   (syntax-case stx (literal-id ...)
     [pattern (syntax template)] ...)))
]}


@ellipses-defn{

The @|ellipses-id| transformer binding prohibits @|ellipses-id| from being
used as an expression. This binding useful only in syntax patterns and
templates, where it indicates repetitions of a pattern or
template. See @scheme[syntax-case] and @scheme[syntax].}

@defidform[_]{

The @scheme[_] transformer binding prohibits @scheme[_] from being
used as an expression. This binding useful only in syntax patterns,
where it indicates a pattern that matches any syntax object. See
@scheme[syntax-case].}