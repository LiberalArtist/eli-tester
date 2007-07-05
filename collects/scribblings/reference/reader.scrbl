#reader(lib "docreader.ss" "scribble")
@require["mz.ss"]
@require[(lib "bnf.ss" "scribble")]
@require["reader-example.ss"]
@begin[
(define (ilitchar s)
  (litchar s))
(define (nunterm s)
  (nonterm s (subscript "n")))
(define (sub n) (subscript n))
(define (nonalpha)
  @elem{; the next character must not be @schemelink[char-alphabetic?]{alphabetic}.})
]
@define[(graph-tag) @kleenerange[1 8]{@nonterm{digit@sub{10}}}]
@define[(graph-defn) @elem{@litchar{#}@graph-tag[]@litchar{=}}]
@define[(graph-ref) @elem{@litchar{#}@graph-tag[]@litchar{#}}]

@title[#:tag "mz:reader" #:style 'quiet]{The Reader}

Scheme's reader is a recursive-descent parser that can be configured
through a @seclink["mz:readtables"]{readtable} and various other
@tech{parameters}. This section describes the reader's parsing when
using the default readtable.

Reading from a stream produces one @deftech{datum}. If the result
datum is a compound value, then reading the datum typically requires
the reader to call itself recursively to read the component data.

The reader can be invoked in either of two modes: @scheme[read] mode,
or @scheme[read-syntax] mode. In @scheme[read-syntax] mode, the result
is always a @techlink{syntax object} that includes
source-location and (initially empty) lexical information wrapped
around the sort of datum that @scheme[read] mode would produce. In the
case of pairs, vectors, and boxes, morever, the content is also
wrapped recursively as a syntax object. Unless specified otherwise,
this section describes the reader's behavior in @scheme[read] mode,
and @scheme[read-syntax] mode does the same modulo wrapping the final
result.

Reading is defined in terms of Unicode characters; see
@secref["mz:ports"] for information on how a byte stream is converted
to a character stream.

@local-table-of-contents[]

@;------------------------------------------------------------------------
@section[#:tag "mz:default-readtable-dispatch"]{Delimiters and Dispatch}

Along with @schemelink[char-whitespace?]{whitespace}, the following
characters are @defterm{delimiters}:

@t{
  @hspace[2] @ilitchar{(} @ilitchar{)} @ilitchar{[} @ilitchar{]}
  @ilitchar["["] @ilitchar["]"]
  @ilitchar{"} @ilitchar{,} @ilitchar{'} @ilitchar{`}
  @ilitchar{;}
}

A delimited sequence that starts with any other character is typically
parsed as either a symbol or number, but a few non-delimiter
characters play special roles:

@itemize{

 @item{@litchar{#} has a special meaning as an initial character in a
       delimited sequence; its meaning depends on the characters that
       follow; see below.}

 @item{@as-index{@litchar["|"]} starts a subsequence of characters to
       be included verbatim in the delimited sequence (i.e,. they are
       never treated as delimiters, and they are not case-folded when
       case-insensitivity is enabled); the subsequence is terminated
       by another @litchar["|"], and neither the initial nor
       terminating @litchar["|"] is part of the subsequence.}

 @item{@as-index{@litchar["\\"]} outside of a @litchar["|"] pair causes
       the folowing character to be included verbatim in a delimited
       sequence.}

}

More precisely, after skipping whitespace, the reader dispatches based
on the next character or characters in the input stream as follows:

@dispatch-table[

  @dispatch[@litchar{(}]{starts a pair or list; see @secref["mz:parse-pair"]}
  @dispatch[@litchar{[}]{starts a pair or list; see @secref["mz:parse-pair"]}
  @dispatch[@litchar["{"]]{starts a pair or list; see @secref["mz:parse-pair"]}

  @dispatch[@litchar{)}]{matches @litchar{(} or raises @Exn{exn:fail:read}}
  @dispatch[@litchar{]}]{matches @litchar{[} or raises @Exn{exn:fail:read}}
  @dispatch[@litchar["}"]]{matches @litchar["{"] or raises @Exn{exn:fail:read}}

  @dispatch[@litchar{"}]{starts a string; see @secref["mz:parse-string"]}
  @dispatch[@litchar{,}]{starts a quote; see @secref["mz:parse-quote"]}
  @dispatch[@litchar{`}]{starts a quasiquote; see @secref["mz:parse-quote"]}
  @dispatch[@litchar{,}]{starts an unquote or splicing unquote; see @secref["mz:parse-quote"]}

  @dispatch[@litchar{;}]{starts a line comment; see @secref["mz:parse-comment"]}

  @dispatch[@cilitchar{#t}]{true; see @secref["mz:parse-boolean"]}
  @dispatch[@cilitchar{#f}]{false; see @secref["mz:parse-boolean"]}

  @dispatch[@litchar{#(}]{starts a vector; see @secref["mz:parse-vector"]}
  @dispatch[@litchar{#[}]{starts a vector; see @secref["mz:parse-vector"]}
  @dispatch[@litchar["#{"]]{starts a vector; see @secref["mz:parse-vector"]}

  @dispatch[@litchar["#\\"]]{starts a character; see @secref["mz:parse-character"]}

  @dispatch[@litchar{#"}]{starts a byte string; see @secref["mz:parse-string"]}
  @dispatch[@litchar{#%}]{starts a symbol; see @secref["mz:parse-symbol"]}
  @dispatch[@litchar{#:}]{starts a keyword; see @secref["mz:parse-keyword"]}
  @dispatch[@litchar{#&}]{starts a box; see @secref["mz:parse-box"]}

  @dispatch[@litchar["#|"]]{starts a block comment; see @secref["mz:parse-comment"]}
  @dispatch[@litchar["#;"]]{starts an S-expression comment; see @secref["mz:parse-comment"]}
  @dispatch[@litchar{#,}]{starts a syntax quote; see @secref["mz:parse-quote"]}
  @dispatch[@litchar["#! "]]{starts a line comment; see @secref["mz:parse-comment"]}
  @dispatch[@litchar["#!/"]]{starts a line comment; see @secref["mz:parse-comment"]}
  @dispatch[@litchar{#`}]{starts a syntax quasiquote; see @secref["mz:parse-quote"]}
  @dispatch[@litchar{#,}]{starts an syntax unquote or splicing unquote; see @secref["mz:parse-quote"]}
  @dispatch[@litchar["#~"]]{starts compiled code; see @secref["compilation"]}

  @dispatch[@cilitchar{#i}]{starts a number; see @secref["mz:parse-number"]}
  @dispatch[@cilitchar{#e}]{starts a number; see @secref["mz:parse-number"]}
  @dispatch[@cilitchar{#x}]{starts a number; see @secref["mz:parse-number"]}
  @dispatch[@cilitchar{#o}]{starts a number; see @secref["mz:parse-number"]}
  @dispatch[@cilitchar{#d}]{starts a number; see @secref["mz:parse-number"]}
  @dispatch[@cilitchar{#b}]{starts a number; see @secref["mz:parse-number"]}

  @dispatch[@cilitchar["#<<"]]{starts a string; see @secref["mz:parse-string"]}

  @dispatch[@litchar{#rx}]{starts a regular expression; see @secref["mz:parse-regexp"]}
  @dispatch[@litchar{#px}]{starts a regular expression; see @secref["mz:parse-regexp"]}

  @dispatch[@cilitchar{#ci}]{switches case sensitivity; see @secref["mz:parse-symbol"]}
  @dispatch[@cilitchar{#cs}]{switches case sensitivity; see @secref["mz:parse-symbol"]}

  @dispatch[@cilitchar["#sx"]]{starts a Scheme expression; see @secref["mz:parse-honu"]}

  @dispatch[@litchar["#hx"]]{starts a Honu expression; see @secref["mz:parse-honu"]}
  @dispatch[@litchar["#honu"]]{starts a Honu module; see @secref["mz:parse-honu"]}

  @dispatch[@litchar["#hash"]]{starts a hash table; see @secref["mz:parse-hashtable"]}

  @dispatch[@litchar["#reader"]]{starts a reader extension use; see @secref["mz:parse-reader"]}

  @dispatch[@elem{@litchar{#}@kleeneplus{@nonterm{digit@sub{10}}}@litchar{(}}]{starts a vector; see @secref["mz:parse-vector"]}
  @dispatch[@elem{@litchar{#}@kleeneplus{@nonterm{digit@sub{10}}}@litchar{[}}]{starts a vector; see @secref["mz:parse-vector"]}
  @dispatch[@elem{@litchar{#}@kleeneplus{@nonterm{digit@sub{10}}}@litchar["{"]}]{starts a vector; see @secref["mz:parse-vector"]}
  @dispatch[@graph-defn[]]{binds a graph tag; see @secref["mz:parse-graph"]}
  @dispatch[@graph-ref[]]{uses a graph tag; see @secref["mz:parse-graph"]}

  @dispatch[@italic{otherwise}]{starts a symbol; see @secref["mz:parse-symbol"]}

]


@section[#:tag "mz:parse-symbol"]{Reading Symbols}

@guideintro["guide:symbols"]{the syntax of symbols}

A sequence that does not start with a delimiter or @litchar{#} is
parsed as either a symbol or a number (see
@secref["mz:parse-number"]), except that @litchar{.} by itself is
never parsed as a symbol or character (unless the
@scheme[read-accept-dot] parameter is set to @scheme[#f]). A
@as-index{@litchar{#%}} also starts a symbol. A successful number
parse takes precedence over a symbol parse.

When the @scheme[read-case-sensitive] @tech{parameter} is set to @scheme[#f],
characters in the sequence that are not quoted by @litchar["|"] or
@litchar["\\"] are first case-normalized. If the reader encounters
@as-index{@litchar{#ci}}, @litchar{#CI}, @litchar{#Ci}, or @litchar{#cI},
then it recursively reads the following datum in
case-insensitive mode. If the reader encounters @as-index{@litchar{#cs}},
@litchar{#CS}, @litchar{#Cs}, or @litchar{#cS}, then recursively reads
the following datum in case-sensitive mode.

@reader-examples[#:symbols? #f
"Apple"
"Ap#ple"
"Ap ple"
"Ap| |ple"
"Ap\\ ple"
"#ci Apple"
"#ci |A|pple"
"#ci \\Apple"
"#ci#cs Apple"
"#%Apple"
]

@section[#:tag "mz:parse-number"]{Reading Numbers}

@guideintro["guide:numbers"]{the syntax of numbers}

@index['("numbers" "parsing")]{A} sequence that does not start with a
delimiter is parsed as a number when it matches the following grammar
case-insenstively for @nonterm{number@sub{10}} (decimal), where
@metavar{n} is a meta-meta-variable in the grammar.

A number is optionally prefixed by an exactness specifier,
@as-index{@litchar{#e}} (exact) or @as-index{@litchar{#i}} (inexact),
which specifies its parsing as an exact or inexact number; see
@secref["mz:numbers"] for information on number exactness. As the
non-terminal names suggest, a number that has no exactness specifier
and matches only @nunterm{inexact-number} is normally parsed as an
inexact number, otherwise it is parsed as an excat number. If the
@scheme[read-decimal-as-inexact] @tech{parameter} is set to @scheme[#f], then
all numbers without an exactness specifier are instead parsed as
exact.

If the reader encounters @as-index{@litchar{#b}} (binary),
@as-index{@litchar{#o}} (octal), @as-index{@litchar{#d}} (decimal), or
@as-index{@litchar{#x}} (hexadecimal), it must be followed by a
sequence that is terminated by a delimiter or end-of-file, and that
matches the @nonterm{general-number@sub{2}},
@nonterm{general-number@sub{8}}, @nonterm{general-number@sub{10}}, or
@nonterm{general-number@sub{16}} grammar, respectively.

An @nunterm{exponent-mark} in an inexact number serves both to specify
an exponent and specify a numerical precision. If single-precision
IEEE floating point is supported (see @secref["mz:numbers"]), the marks
@litchar{f} and @litchar{s} specifies single-precision. Otherwise, or
with any other mark, double-precision IEEE floating point is used.

@BNF[(list @nunterm{number} @BNF-alt[@nunterm{exact}
                                     @nunterm{inexact}])
     (list @nunterm{exact} @BNF-alt[@nunterm{exact-integer}
                                    @nunterm{exact-rational}]
                                  @nunterm{exact-complex})
     (list @nunterm{exact-integer} @BNF-seq[@optional{@nonterm{sign}} @nunterm{digits}])
     (list @nunterm{digits} @kleeneplus{@nunterm{digit}})
     (list @nunterm{exact-rational} @BNF-seq[@nunterm{exact-integer} @litchar{/} @nunterm{unsigned-integer}])
     (list @nunterm{exact-complex} @BNF-seq[@nunterm{exact-rational} @nonterm{sign} @nunterm{exact-rational} @litchar{i}])
     (list @nunterm{inexact} @BNF-alt[@nunterm{inexact-real}
                                      @nunterm{inexact-complex}])
     (list @nunterm{inexact-real} @BNF-seq[@optional{@nonterm{sign}} @nunterm{inexact-normal}]
                                  @BNF-seq[@nonterm{sign} @nunterm{inexact-special}])
     (list @nunterm{inexact-unsigned} @BNF-alt[@nunterm{inexact-normal}
                                               @nunterm{inexact-special}])
     (list @nunterm{inexact-normal} @BNF-seq[@nunterm{inexact-simple} @optional{@nunterm{exp-mark}
                                                                                @optional[@nonterm{sign}] @nunterm{digits#}}])
     (list @nunterm{inexact-simple} @BNF-seq[@nunterm{digits#} @optional{@litchar{.}} @kleenestar{@litchar{#}}]
                                    @BNF-seq[@optional{@nunterm{exact-integer}} @litchar{.} @nunterm{digits#}]
                                    @BNF-seq[@nunterm{digits#} @litchar{/} @nunterm{digits#}])
     (list @nunterm{inexact-special} @BNF-alt[@litchar{inf.0} @litchar{nan.0}])
     (list @nunterm{digits#} @BNF-seq[@kleeneplus{@nunterm{digit}} @kleenestar{@litchar{#}}])
     (list @nunterm{inexact-complex} @BNF-seq[@optional{@nunterm{inexact-real}} @nonterm{sign} @nunterm{inexact-unsigned} @litchar{i}]
                                     @BNF-seq[@nunterm{inexact-real} @litchar["@"] @nunterm{inexact-real}])


     (list @nonterm{sign} @BNF-alt[@litchar{+}
                                   @litchar{-}])
     (list @nonterm{digit@sub{16}} @BNF-alt[@nonterm{digit@sub{10}} @litchar{a} @litchar{b} @litchar{c} @litchar{d}
                                            @litchar{e} @litchar{f}])
     (list @nonterm{digit@sub{10}} @BNF-alt[@nonterm{digit@sub{8}} @litchar{8} @litchar{9}])
     (list @nonterm{digit@sub{8}} @BNF-alt[@nonterm{digit@sub{2}} @litchar{2} @litchar{3}
                                           @litchar{4} @litchar{5} @litchar{6} @litchar{7}])
     (list @nonterm{digit@sub{2}} @BNF-alt[@litchar{0} @litchar{1}])
     (list @nonterm{exp-mark@sub{16}} @BNF-alt[@litchar{s} @litchar{d} @litchar{l}])
     (list @nonterm{exp-mark@sub{10}} @BNF-alt[@nonterm{exp-mark@sub{16}} @litchar{e} @litchar{f}])
     (list @nonterm{exp-mark@sub{8}} @nonterm{exp-mark@sub{10}})
     (list @nonterm{exp-mark@sub{2}} @nonterm{exp-mark@sub{10}})
     (list @nunterm{general-number} @BNF-seq[@optional{@nonterm{exactness}} @nunterm{number}])
     (list @nonterm{exactness} @BNF-alt[@litchar{#e} @litchar{#i}])
     ]

@reader-examples[
"-1"
"1/2"
"1.0"
"1+2i"
"1/2+3/4i"
"1.0+3.0e7i"
"2e5"
"#i5"
"#e2e5"
"#x2e5"
"#b101"
]

@section[#:tag "mz:parse-boolean"]{Reading Booleans}

A @as-index{@litchar{#t}} or @as-index{@litchar{#T}} is the complete
input syntax for the boolean constant true, and
@as-index{@litchar{#f}} or @as-index{@litchar{#F}} is the complete
input syntax for the boolean constant false.

@section[#:tag "mz:parse-pair"]{Reading Pairs and Lists}

When the reader encounters a @as-index{@litchar{(}},
@as-index{@litchar["["]}, or @as-index{@litchar["{"]}, it starts
parsing a pair or list; see @secref["mz:pairs"] for information on pairs
and lists.

To parse the pair or list, the reader recursively reads data
until a matching @as-index{@litchar{)}}, @as-index{@litchar{]}}, or
@as-index{@litchar["}"]} (respectively) is found, and it specially handles
a delimited @litchar{.}.  Pairs @litchar{()}, @litchar{[]}, and
@litchar["{}"] are treated the same way, so the remainder of this
section simply uses ``parentheses'' to mean any of these pair.

If the reader finds no delimited @as-index{@litchar{.}} among the elements
between parentheses, then it produces a list containing the results of
the recursive reads.

If the reader finds two data between the matching parentheses
that are separated by a delimited @litchar{.}, then it creates a
pair. More generally, if it finds two or more data where the
last is preceeded by a delimited @litchar{.}, then it constructs
nested pairs: the next-to-last element is paired with the last, then
the third-to-last is paired with that pair, and so on.

If the reader finds three or more data between the matching
parentheses, and if a pair of delimited @litchar{.}s surrounds any
other than the first and last elements, the result is a list
containing the element surrounded by @litchar{.}s as the first
element, followed by the others in the read order. This convention
supports a kind of @index["infix"]{infix} notation at the reader
level.

In @scheme[read-syntax] mode, the recursive reads for the pair/list
elements are themselves in @scheme[read-syntax] mode, so that the
result is list or pair of syntax objects that it itself wrapped as a
syntax object. If the reader constructs nested pairs because the input
included a single delimited @litchar{.}, then only the innermost pair
and outtermost pair are wrapped as syntax objects. Whether wrapping a
pair or list, if the pair or list was formed with @litchar{[} and
@litchar{]}, then a @scheme['paren-shape] property is attached to the
result with the value @scheme[#\[];if the list or pair was formed with
@litchar["{"] and @litchar["}"], then a @scheme['paren-shape] property
is attached to the result with the value @scheme[#\{].

If a delimited @litchar{.} appears in any other configuration, then
the @exnraise[exn:fail:read]. Similarly, if the reader encounters a
@litchar{)}, @litchar["]"], or @litchar["}"] that does not end a list
being parsed, then the @exnraise[exn:fail:read].

@reader-examples[
"()"
"(1 2 3)"
"{1 2 3}"
"[1 2 3]"
"(1 (2) 3)"
"(1 . 3)"
"(1 . (3))"
"(1 . 2 . 3)"
]

If the @scheme[read-square-bracket-as-paren] @tech{parameter} is set to
@scheme[#f], then when then reader encounters @litchar{[} and
@litchar{]}, the @exnraise{exn:fail:read}. Similarly, If the
@scheme[read-curly-brace-as-paren] @tech{parameter} is set to @scheme[#f],
then when then reader encounters @litchar["{"] and @litchar["}"], the
@exnraise{exn:fail:read}.

If the @scheme[read-accept-dot] @tech{parameter} is set to
@scheme[#f], then a delimited @scheme{.} is not treated specially; it
is instead parsed a s symbol. If the @scheme[read-accept-infix-dot]
@tech{parameter} is set to @scheme[#f], then multiple delimited
@litchar{.}s trigger a @scheme[exn:fail:read], instead of the infix
conversion.

@section[#:tag "mz:parse-string"]{Reading Strings}

@guideintro["guide:strings"]{the syntax of strings}

@index['("strings" "parsing")]{When} the reader encouters
@as-index{@litchar{"}}, it begins parsing characters to form a string. The
string continues until it is terminated by another @litchar{"} (that
is not escaped by @litchar["\\"]).

Within a string sequence, the following escape sequences are
 recognized:

@itemize{

 @item{@as-index{@litchar["\\a"]}: alarm (ASCII 7)}
 @item{@as-index{@litchar["\\b"]}: backspace (ASCII 8)}
 @item{@as-index{@litchar["\\t"]}: tab (ASCII 9)}
 @item{@as-index{@litchar["\\n"]}: linefeed (ASCII 10)}
 @item{@as-index{@litchar["\\v"]}: vertical tab (ASCII 11)}
 @item{@as-index{@litchar["\\f"]}: formfeed (ASCII 12)}
 @item{@as-index{@litchar["\\r"]}: return (ASCII 13)}
 @item{@as-index{@litchar["\\e"]}: escape (ASCII 27)}

 @item{@as-index{@litchar["\\\""]}: double-quotes (without terminating the string)}
 @item{@as-index{@litchar["\\'"]}: quote (i.e., the backslash has no effect)}
 @item{@as-index{@litchar["\\\\"]}: backslash (i.e., the second is not an escaping backslash)}

 @item{@as-index{@litchar["\\"]@kleenerange[1 3]{@nonterm{digit@sub{8}}}}:
       Unicode for the octal number specified by @kleenerange[1
       3]{digit@sub{8}} (i.e., 1 to 3 @nonterm{digit@sub{8}}s) where
       each @nonterm{digit@sub{8}} is @litchar{0}, @litchar{1},
       @litchar{2}, @litchar{3}, @litchar{4}, @litchar{5},
       @litchar{6}, or @litchar{7}. A longer form takes precedence
       over a shorter form, and the resulting octal number must be
       between 0 and 255 decimal, otherwise the
       @exnraise[exn:fail:read].}

 @item{@as-index{@litchar["\\x"]@kleenerange[1
       2]{@nonterm{digit@sub{16}}}}: Unicode for the hexadecimal
       number specified by @kleenerange[1 2]{@nonterm{digit@sub{16}}},
       where each @nonterm{digit@sub{16}} is @litchar{0}, @litchar{1},
       @litchar{2}, @litchar{3}, @litchar{4}, @litchar{5},
       @litchar{6}, @litchar{7}, @litchar{8}, @litchar{9},
       @litchar{a}, @litchar{b}, @litchar{c}, @litchar{d},
       @litchar{e}, or @litchar{f} (case-insensitive). The longer form
       takes precedence over the shorter form.}

 @item{@as-index{@litchar["\\u"]@kleenerange[1
       4]{@nonterm{digit@sub{16}}}}: like @litchar["\\x"], but with up
       to four hexadecimal digits (longer sequences take precedence).
       The resulting hexadecimal number must be a valid argument to
       @scheme[integer->char], otherwise the
       @exnraise[exn:fail:read].}

 @item{@as-index{@litchar["\\U"]@kleenerange[1
       8]{@nonterm{digit@sub{16}}}}: like @litchar["\\x"], but with up
       to eight hexadecimal digits (longer sequences take precedence).
       The resulting hexadecimal number must be a valid argument to
       @scheme[integer->char], otherwise the
       @exnraise[exn:fail:read].}

 @item{@as-index{@litchar["\\"]@nonterm{newline}}: elided, where
       @nonterm{newline} is either a linefeed, carriage return, or
       carriage return--linefeed combination. This convetion allows
       single-line strings to span multiple lines in the source.}

}

If the reader encounteres any other use of a backslash in a string
constant, the @exnraise[exn:fail:read].

@guideintro["guide:bytestrings"]{the syntax of byte strings}

@index['("byte strings" "parsing")]{A} string constant preceded by
@litchar{#} is parsed as a byte-string. (That is, @as-index{@litchar{#"}} starts
a byte-string literal.) See @secref["mz:bytestrings"] for
information on byte strings. Byte string constants support the same
escape sequences as character strings, except @litchar["\\u"] and
@litchar["\\U"].

When the reader encounters @as-index{@litchar{#<<}}, it starts parsing a
@pidefterm{here string}. The characters following @litchar{#<<} until
a newline character define a terminator for the string. The content of
the string includes all characters between the @litchar{#<<} line and
a line whose only content is the specified terminator. More precisely,
the content of the string starts after a newline following
@litchar{#<<}, and it ends before a newline that is followed by the
terminator, where the terminator is itself followed by either a
newline or end-of-file. No escape sequences are recognized between the
starting and terminating lines; all characters are included in the
string (and terminator) literally. A return character is not treated
as a line separator in this context. If no characters appear between
@litchar{#<<} and a newline or end-of-file, or if an end-of-file is
encountered before a terminating line, the @exnraise[exn:fail:read].

@reader-examples[
"\"Apple\""
"\"\\x41pple\""
"\"\\\"Apple\\\"\""
"\"\\\\\""
"#\"Apple\""
]

@section[#:tag "mz:parse-quote"]{Reading Quotes}

When the reader enounters @as-index{@litchar{'}}, then it recursively
reads one datum, and it forms a new list containing the symbol
@scheme['quote] and the following datum. This convention is mainly
useful for reading Scheme code, where @scheme['s] can be used as a
shorthand for @scheme[(code:quote s)].

Several other sequences are recognized and transformed in a similar
way. Longer prefixes take precedence over short ones:

@read-quote-table[(list @litchar{'} @scheme[quote])
                  (list @as-index{@litchar{`}} @scheme[quasiquote])
                  (list @as-index{@litchar{,}} @scheme[unquote])
                  (list @as-index{@litchar[",@"]} @scheme[unquote-splicing])
                  (list @as-index{@litchar{#'}} @scheme[syntax])
                  (list @as-index{@litchar{#`}} @scheme[quasisyntax])
                  (list @as-index{@litchar{#,}} @scheme[unsyntax])
                  (list @as-index{@litchar["#,@"]} @scheme[unsyntax-splicing])]

@reader-examples[
"'apple"
"`(1 ,2)"
]

The @litchar{`}, @litchar{,}, and @litchar[",@"] forms are disabled when
the @scheme[read-accept-quasiquote] @tech{parameter} is set to
@scheme[#f], in which case the @exnraise[exn:fail:read], instead.

@section[#:tag "mz:parse-comment"]{Reading Comments}

A @as-index{@litchar{;}} starts a line comment. When the reader
encounters @litchar{;}, then it skips past all characters until the
next linefeed or carriage return.

A @litchar["#|"] starts a nestable block comment.  When the reader
encounters @litchar["#|"], then it skips past all characters until a
closing @litchar["|#"]. Pairs of matching @litchar["#|"] and
@litchar["|#"] can be nested.

A @litchar{#;} starts an S-expression comment. Then the reader
encounters @litchar{#;}, it recursively reads one datum, and then
discards the datum (continuing on to the next datum for the read
result).

A @litchar{#! } (which is @litchar{#!} followed by a space) or
@litchar{#!/} starts a line comment that can be continued to the next
line by ending a line with @litchar["\\"]. This form of comment
normally appears at the beginning of a Unix script file.

@reader-examples[
"; comment"
"#| a |# 1"
"#| #| a |# 1 |# 2"
"#;1 2"
"#!/bin/sh"
"#! /bin/sh"
]

@section[#:tag "mz:parse-vector"]{Reading Vectors}

When the reader encounters a @litchar{#(}, @litchar{#[}, or
@litchar["#{"], it starts parsing a vector; see @secref["vectors"] for
information on vectors.

The elements of the vector are recursively read until a matching
@litchar{)}, @litchar{]}, or @litchar["}"] is found, just as for
lists (see @secref["mz:parse-pair"]). A delimited @litchar{.} is not
allowed among the vector elements.

An optional vector length can be specified between the @litchar{#} and
@litchar["("], @litchar["["], or @litchar["{"]. The size is specified
using a sequence of decimal digits, and the number of elements
provided for the vector must be no more than the specified size. If
fewer elements are provided, the last provided element is used for the
remaining vector slots; if no elements are provided, then @scheme[0]
is used for all slots.

In @scheme[read-syntax] mode, each recursive read for the vector
elements is also in @scheme[read-syntax] mode, so that the wrapped
vector's elements are also wraped as syntax objects.

@reader-examples[
"#(1 apple 3)"
"#3(\"apple\" \"banana\")"
"#3()"
]

@section[#:tag "mz:parse-hashtable"]{Reading Hash Tables}

A @litchar{#hash} starts an immutable hash-table constant with key
matching based on @scheme[equal?]. The characters after @litchar{hash}
must parse as a list of pairs (see @secref["mz:parse-pair"]) with a
specific use of delimited @litchar{.}: it must appear between the
elements of each pair in the list, and nowhere in the sequence of list
elements. The first element of each pair is used as the key for a
table entry, and the second element of each pair is the associated
value.

A @litchar{#hasheq} starts a hash table like @litchar{#hash}, except
that it constructs a hash table based on @scheme[eq?] instead of
@scheme[equal?].

In either case, the table is constructed by adding each mapping to the
 hash table from left to right, so later mappings can hide earlier
 mappings if the keys are equivalent.

@reader-examples[
#:example-note @elem{, where @scheme[make-...] stands for @scheme[make-immutable-hash-table]}
"#hash()"
"#hasheq()"
"#hash((\"a\" . 5))"
"#hasheq((a . 5) (b . 7))"
"#hasheq((a . 5) (a . 7))"
]

@section[#:tag "mz:parse-box"]{Reading Boxes}

When the reader encounters a @litchar{#&}, it starts parsing a box;
see @secref["boxes"] for information on boxes. The content of the box
is determined by recursively reading the next datum.

In @scheme[read-syntax] mode, the recursive read for the box content
is also in @scheme[read-syntax] mode, so that the wrapped box's
content is also wraped as a syntax object.

@reader-examples[
"#&17"
]

@section[#:tag "mz:parse-character"]{Reading Characters}

@guideintro["guide:characters"]{the syntax of characters}

A @litchar["#\\"] starts a character constant, which has one of the
following forms:

@itemize{

 @item{ @litchar["#\\nul"] or @litchar["#\\null"]: NUL (ASCII 0)@nonalpha[]}
 @item{ @litchar["#\\backspace"]: backspace  (ASCII 8)@nonalpha[]}
 @item{ @litchar["#\\tab"]: tab (ASCII 9)@nonalpha[]}
 @item{ @litchar["#\\newline"] or @litchar["#\\linefeed"]: linefeed (ASCII 10)@nonalpha[]}
 @item{ @litchar["#\\vtab"]: vertical tab (ASCII 11)@nonalpha[]}
 @item{ @litchar["#\\page"]: page break (ASCII 12)@nonalpha[]}
 @item{ @litchar["#\\return"]: carriage return (ASCII 13)@nonalpha[]}
 @item{ @litchar["#\\space"]: space (ASCII 32)@nonalpha[]}
 @item{ @litchar["#\\rubout"]: delete (ASCII 127)@nonalpha[]}

 @item{@litchar["#\\"]@kleenerange[1 3]{@nonterm{digit@sub{8}}}:
       Unicode for the octal number specified by @kleenerange[1
       3]{@nonterm{digit@sub{8}}}, as in string escapes (see
       @secref["mz:parse-string"]).}

 @item{@litchar["#\\x"]@kleenerange[1 2]{@nonterm{digit@sub{16}}}:
       Unicode for the hexadecimal number specified by @kleenerange[1
       2]{@nonterm{digit@sub{16}}}, as in string escapes (see
       @secref["mz:parse-string"]).}

 @item{@litchar["#\\u"]@kleenerange[1 4]{@nonterm{digit@sub{16}}}:
       like @litchar["#\\x"], but with up to four hexadecimal digits.}

 @item{@litchar["#\\U"]@kleenerange[1 6]{@nonterm{digit@sub{16}}}:
       like @litchar["#\\x"], but with up to six hexadecimal digits.}

 @item{@litchar["#\\"]@nonterm{c}: the character @nonterm{c}, as long
       as @litchar["#\\"]@nonterm{c} and the characters following it
       do not match any of the previous cases, and as long as the
       character after @nonterm{c} is not
       @schemelink[char-alphabetic?]{alphabetic}.}

}

@reader-examples[
"#\\newline"
"#\\n"
"#\\u3BB"
"#\\\u3BB"
]

@section[#:tag "mz:parse-keyword"]{Reading Keywords}

A @litchar{#:} starts a keyword. The parsing of a keyword after the
@litchar{#:} is the same as for a symbol, including case-folding in
case-insensitive mode, except that the part after @litchar{#:} is
never parsed as a number.

@reader-examples[
"#:Apple"
"#:1"
]

@section[#:tag "mz:parse-regexp"]{Reading Regular Expressions}

A @litchar{#rx} or @litchar{#px} starts a regular expression. The
characters immediately after @litchar{#rx} or @litchar{#px} must parse
as a string or byte string (see @secref["mz:parse-string"]). A
@litchar{#rx} prefix starts a regular expression as would be
constructed by @scheme[regexp], @litchar{#px} as
constructed by @scheme[pregexp], @litchar{#rx#} as
constructed by @scheme[byte-regexp], and @litchar{#px#} as
constructed by @scheme[byte-pregexp].

@reader-examples[
"#rx\".*\""
"#px\"[\\\\s]*\""
"#rx#\".*\""
"#px#\"[\\\\s]*\""
]

@section[#:tag "mz:parse-graph"]{Reading Graph Structure}

A @graph-defn[] tags the following datum for reference via
@graph-ref[], which allows the reader to produce a datum that
have graph structure.

For a specific @graph-tag[] in a single read result, each @graph-ref[]
reference is replaced by the datum read for the corresponding
@graph-defn[]; the definition @graph-defn[] also produces just the
datum after it. A @graph-defn[] definition can appear at most once,
and a @graph-defn[] definition must appear before a @graph-ref[]
reference appears, otherwise the @exnraise[exn:fail:read]. If the
@scheme[read-accept-graph] parameter is set to @scheme[#f], then
@graph-defn[] or @graph-ref[] triggers a @scheme[exn:fail:read]
exception.

Although a comment parsed via @litchar{#;} discards the datum
afterward, @graph-defn[] definitions in the discarded datum
still can be referenced by other parts of the reader input, as long as
both the comment and the reference are grouped together by some other
form (i.e., some recursive read); a top-level @litchar{#;} comment
neither defines nor uses graph tags for other top-level forms.

@reader-examples[
"(#1=100 #1# #1#)"
"#0=(1 . #0#)"
]

@local-table-of-contents[]

@section[#:tag "mz:parse-reader"]{Reading via an External Reader}

When the reader encounters @litchar{#reader}, then it loads an
external reader procedure and applies it to the current input stream.

The reader recursively reads the next datum after @litchar{#reader},
and passes it to the procedure that is the value of the
@scheme[current-reader-guard] @tech{parameter}; the result is used as a
module path. The module path is passed to @scheme[dynamic-require]
with either @scheme['read] or @scheme['read-syntax] (depending on
whether the reader is in @scheme[read] or @scheme[read-syntax]
mode).

The resulting procedure should accept the same arguments as
@scheme[read] or @scheme[read-syntax] in the case that all optional
arguments are provided. The procedure is given the port whose stream
contained @litchar{#reader}, and it should produce a datum result. If
the result is a syntax object in @scheme[read] mode, then it is
converted to a datum using @scheme[syntax-object->datum]; if the
result is not a syntax object in @scheme[read-syntax] mode, then it is
converted to one using @scheme[datum->syntax-object]. See also
@secref["mz:reader-procs"] for information on the procedure's results.

If the @scheme[read-accept-reader] @tech{parameter} is set to
@scheme[#f], then if the reader encounters @litchar{#reader}, the
@exnraise[exn:fail:read].

@section[#:tag "mz:parse-honu"]{Honu Parsing}