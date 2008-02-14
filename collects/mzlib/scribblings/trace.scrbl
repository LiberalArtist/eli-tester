#lang scribble/doc
@(require "common.ss"
          (for-label mzlib/trace))

@mzlib[#:mode title trace]

The @schememodname[mzlib/trace] library mimics the tracing facility
available in Chez Scheme.

@defform[(trace id ...)]{

Each @scheme[id] must be bound to a procedure in the environment of
the @scheme[trace] expression.  Each @scheme[id] is @scheme[set!]ed to
a new procedure that traces procedure calls and returns by printing
the arguments and results of the call.  If multiple values are
returned, each value is displayed starting on a separate line.

When traced procedures invoke each other, nested invocations are shown
by printing a nesting prefix. If the nesting depth grows to ten and
beyond, a number is printed to show the actual nesting depth.

The @scheme[trace] form can be used on an identifier that is already
traced.  In this case, assuming that the variable's value has not been
changed, @scheme[trace] has no effect.  If the variable has been
changed to a different procedure, then a new trace is installed.

Tracing respects tail calls to preserve loops, but its effect may be
visible through continuation marks. When a call to a traced procedure
occurs in tail position with respect to a previous traced call, then
the tailness of the call is preserved (and the result of the call is
not printed for the tail call, because the same result will be printed
for an enclosing call). Otherwise, however, the body of a traced
procedure is not evaluated in tail position with respect to a call to
the procedure.

The result of a @scheme[trace] expression is @|void-const|.}

@defform[(untrace id ...)]{

Undoes the effects of the @scheme[trace] form for each @scheme[id],
@scheme[set!]ing each @scheme[id] back to the untraced procedure, but
only if the current value of @scheme[id] is a traced procedure.  If
the current value of a @scheme[id] is not a procedure installed by
@scheme[trace], then the variable is not changed.

The result of an @scheme[untrace] expression is @|void-const|.}

