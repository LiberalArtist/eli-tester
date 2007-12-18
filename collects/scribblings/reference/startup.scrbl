#lang scribble/doc
@(require "mz.ss"
          scribble/bnf
          (for-label scheme/pretty
                     scheme/gui/base))

@(define (FlagFirst n) (as-index (Flag n)))
@(define (DFlagFirst n) (as-index (DFlag n)))
@(define (PFlagFirst n) (as-index (PFlag n)))

@(define eventspace
   @tech[#:doc '(lib "scribblings/gui/gui.scrbl")]{eventspace})

@title[#:tag "running-sa"]{Starting MzScheme or MrEd}

The core PLT Scheme run-time system is available in two main variants:

@itemize{

 @item{MzScheme, which provides the primitives libraries on which
       @schememodname[scheme/base] is implemented. Under Unix and Mac
       OS X, the executable is called
       @as-index{@exec{mzscheme}}. Under Windows, the executable is
       called @as-index{@exec{MzScheme.exe}}.}

 @item{MrEd, which extends @exec{mzscheme} with GUI primitives on
       which @schememodname[scheme/gui/base] is implemented. Under
       Unix, the executable is called @as-index{@exec{mred}}. Under
       Windows, the executable is called
       @as-index{@exec{MrEd.exe}}. Under Mac OS X, the @exec{mred}
       script launches @as-index{@exec{MrEd.app}}.}

}

@; ----------------------------------------------------------------------

@section[#:tag "init-actions"]{Initialization}

On startup, the top-level environment contains no bindings---not even
for function application.

The first action of MzScheme or MrEd is to initialize
@scheme[current-library-collection-paths] to the result of
@scheme[(find-library-collection-paths _extras)], where
@scheme[_extras] are extra directory paths provided in order in the
command line with @Flag{S}/@DFlag{search}. An executable created from
the MzScheme or MrEd executable can embed additional paths that are
appended to @scheme[_extras].

MzScheme and MrEd next @scheme[require] @schememodname[scheme/init]
and @schememodname[scheme/gui/init], respectively, but only if the
command line does not specify a @scheme[require] flag
(@Flag{t}/@DFlag{require}, @Flag{l}/@DFlag{lib}, or
@Flag{u}/@DFlag{require-script}) before any @scheme[eval],
@scheme[load], or read-eval-print-loop flag (@Flag{e}/@DFlag{eval},
@Flag{f}/@DFlag{load}, @Flag{r}/@DFlag{script}, @Flag{m}/@DFlag{main},
@Flag{i}/@DFlag{repl}, or @Flag{z}/@DFlag{text-repl}).

After potentially loading the initialization module, expression
@scheme[eval]s, files @scheme[load]s, and module @scheme[require]s are
executed in the order that they are provided on the command line. If
any raises an uncaught exception, then the remaining @scheme[eval]s,
@scheme[load]s, and @scheme[require]s are skipped.

After running all command-line expressions, files, and modules,
MzScheme or MrEd then starts a read-eval-print loop for interactive
evaluation if no command line flags are provided.  If any command-line
argument is provided, then the read-eval-print-loop is not started,
unless the @Flag{i}/@DFlag{repl} or @Flag{z}/@DFlag{text-repl} flag is
provided on the command line to specifically re-enable it. In
addition, just before the command line is started, MzScheme loads the
file @scheme[(find-system-path 'init-file)] and MrEd loads the file
@scheme[(find-graphical-system-path 'init-file)] is loaded, unless the
@Flag{q}/@DFlag{no-init-file} flag is specified on the command line.

Finally, before MrEd exists, it waits for all frames to class, all
timers to stop, @|etc| in the main @|eventspace| by evaluating
@scheme[(scheme 'yield)]. This waiting step can be suppressed with the
@Flag{V}/@DFlag{no-yield} command-line flag.

The exit status for the MzScheme or MrEd process indicates an error if
an error occurs during a command-line @scheme[eval], @scheme[load], or
@scheme[require] when no read-eval-print loop is started. Otherwise,
the exit status is @scheme[0] or determined by a call to
@scheme[exit].

@; ----------------------------------------------------------------------

@section{Command Line}

The MzScheme and MrEd executables recognize the following command-line
flags:

@itemize{

 @item{File and expression options:

 @itemize{

  @item{@FlagFirst{e} @nonterm{expr} or @DFlagFirst{eval}
        @nonterm{expr} : @scheme[eval]s @nonterm{expr}.}

  @item{@FlagFirst{f} @nonterm{file} or @DFlagFirst{load}
        @nonterm{file} : @scheme[load]s @nonterm{file}.}

  @item{@FlagFirst{t} @nonterm{file} or @DFlagFirst{require}
        @nonterm{file} : @scheme[require]s @nonterm{file}.}

  @item{@FlagFirst{l} @nonterm{path} or @DFlagFirst{lib}
       @nonterm{path} : @scheme[require]s @scheme[(lib
       @nonterm{path})].}

  @item{@FlagFirst{p} @nonterm{file} @nonterm{u} @nonterm{path} :
       @scheme[require]s @scheme[(planet @nonterm{file}
       @nonterm{user} @nonterm{pkg})].}

  @item{@FlagFirst{r} @nonterm{file} or @DFlagFirst{script}
        @nonterm{file} : @scheme[load]s @nonterm{file} as a
        script. This flag is like @Flag{t} @nonterm{file} plus
        @Flag{N} @nonterm{file} to set the program name and @Flag{-}
        to cause all further command-line elements to be treated as
        non-flag arguments.}

  @item{@FlagFirst{u} @nonterm{file} or @DFlagFirst{require-script}
       @nonterm{file} : @scheme[require]s @nonterm{file} as a script;
       This flag is like @Flag{t} @nonterm{file} plus @Flag{N}
       @nonterm{file} to set the program name and @Flag{-} to cause
       all further command-line elements to be treated as non-flag
       arguments.}

  @item{@FlagFirst{k} @nonterm{n} @nonterm{m} : Loads code embedded in
        the executable from file position @nonterm{n} to
        @nonterm{m}. This option normally embedded in a stand-alone
        binary that embeds Scheme code.}

  @item{@FlagFirst{m} or @DFlagFirst{main} : Evaluates a call to
        @scheme[main] in the top-level environment. All of the
        command-line arguments that are not processed as options
        (i.e., the arguments put into
        @scheme[current-command-line-args]) are passed as arguments to
        @scheme[main].}

 }}

 @item{Interaction options:

 @itemize{

  @item{@FlagFirst{i} or @DFlagFirst{repl} : Runs interactive read-eval-print
        loop, using either @scheme[read-eval-print-loop] (MzScheme) or
        @scheme[graphical-read-eval-print-loop] (MrEd) after showing
        @scheme[(banner)] and loading @scheme[(find-system-path
        'init-file)].}

  @item{@FlagFirst{z} or @DFlagFirst{text-repl} : MrEd only; like
        @Flag{i}/@DFlag{repl}, but uses @scheme[read-eval-print-loop]
        instead of @scheme[graphical-read-eval-print-loop].}

  @item{@FlagFirst{q} or @DFlagFirst{no-init-file} : Skips loading
        @scheme[(find-system-path 'init-file)] for
        @Flag{i}/@DFlag{repl} or @Flag{z}/@DFlag{text-repl}.}

  @item{@FlagFirst{n} or @DFlagFirst{no-lib} : Skips requiring
        @schememodname[scheme/init] or @schememodname[scheme/gui/init]
        when not otherwise disabled.}

  @item{@FlagFirst{v} or @DFlagFirst{version} : Shows
        @scheme[(banner)].}

  @item{@FlagFirst{K} or @DFlagFirst{back} : MrEd, Mac OS X only;
        leave application in the background.}

  @item{@FlagFirst{V} @DFlagFirst{no-yield} : Skips final
        @scheme[(yield 'wait)] action, which normally waits until all
        frames are closed, @|etc| in the main @|eventspace| before
        exiting.}

 }}

 @item{Configuration options:

 @itemize{

  @item{@FlagFirst{c} or @DFlagFirst{no-compiled} : Disables loading
        of compiled byte-code @filepath{.zo} files, by initializing
        @scheme[current-compiled-file-paths] to @scheme[null].}

  @item{@FlagFirst{X} @nonterm{dir} or @DFlagFirst{collects}
        @nonterm{dir} : Sets @nonterm{dir} as the path to the main
        collection of libraries by making @scheme[(find-system-path
        'collects-dir)] produce @nonterm{dir}.}

  @item{@FlagFirst{S} @nonterm{dir} or @DFlagFirst{search}
        @nonterm{dir} : Adds @nonterm{dir} to the library collection
        search path. The @scheme{dir} is added after a user-specific
        directory, if any, and before the main collection directory.}

  @item{@FlagFirst{U} or @DFlagFirst{no-user-path} : Omits
        user-psecific paths in the search for collections, C
        libraries, etc. by initializing the
        @scheme[use-user-specific-search-paths] parameter to
        @scheme[#f].}

  @item{@FlagFirst{N} @nonterm{file} or @DFlagFirst{name}
        @nonterm{file} : sets the name of the executable as reported
        by @scheme[(find-system-path 'run-file)] to
        @nonterm{file}.}

  @item{@FlagFirst{j} or @DFlagFirst{no-jit} : Disables the
        native-code just-in-time compiler by setting the
        @scheme[eval-jit-enabled] parameter to @scheme[#f].}

  @item{@FlagFirst{d} or @DFlagFirst{no-delay} : Disables on-demand
        parsing of compiled code and syntax objects by setting the
        @scheme[read-on-demand-source] parameter to @scheme[#f].}

  @item{@FlagFirst{b} or @DFlagFirst{binary} : Requests binary mode,
        instead of text mode, for the process's input, out, and error
        ports. This flag currently has no effect, because binary mode
        is always used.}

 }}

 @item{Meta options:

 @itemize{

  @item{@FlagFirst{-} : No argument following this flag is itself used
        as a flag.}
 
  @item{@FlagFirst{h} or @DFlagFirst{help} : Shows information about
        the command-line flags and start-up process and exits,
        ignoring all other flags.}
 
 }}

}

If at least one command-line argument is provided, and if the first
one is not a flag, then a @Flag{u}/@DFlag{--require-script} flag is
implicitly added before the first argument.

For MrEd under X11, the follow flags are recognized when they appear
at the beginning of the command line, and they do not otherwise count
as command-line flags (i.e., they do not disable the read-eval-print
loop or prevent the insertion of @Flag{u}/@DFlag{require-script}):

@itemize{

  @item{@FlagFirst{display} @nonterm{display} : Sets the X11 display
        to use.}

  @item{@FlagFirst{geometry} @nonterm{arg}, @FlagFirst{bg}
        @nonterm{arg}, @FlagFirst{background} @nonterm{arg},
        @FlagFirst{fg} @nonterm{arg}, @FlagFirst{foreground}
        @nonterm{arg}, @FlagFirst{fn} @nonterm{arg}, @FlagFirst{font}
        @nonterm{arg}, @FlagFirst{iconic}, @FlagFirst{name}
        @nonterm{arg}, @FlagFirst{rv}, @FlagFirst{reverse},
        @PFlagFirst{rv}, @FlagFirst{selectionTimeout} @nonterm{arg},
        @FlagFirst{synchronous}, @FlagFirst{title} @nonterm{arg},
        @FlagFirst{xnllanguage} @nonterm{arg}, or @FlagFirst{xrm}
        @nonterm{arg} : Standard X11 arguments that are mostly ignored
        but accepted for compatibility with other X11 programs. The
        @Flag{synchronous} and @Flag{xrm} flags behave in the usual
        way.}

  @item{@FlagFirst{singleInstance} : If an existing MrEd is already
        running on the same X11 display, if it was started on a
        machine with the same hostname, and if it was started with the
        same name as reported by @scheme[(find-system-path
        'run-file)]---possibly set with the @Flag{N}/@DFlag{name}
        command-line argument---then all non-option command-line
        arguments are treated as filenames and sent to the existing
        MrEd instance via the application file handler (see
        @scheme[application-file-handler]).}

}

Under Mac OS X, a leading switch starting with @FlagFirst{psn_} is
treated specially. It indicates that Finder started the application,
so the current input, output, and error output are redirected to a GUI
window. It does not count as a command-line flag otherwise.

Multiple single-letter switches (the ones preceded by a single @litchar{-}) can
be collapsed into a single switch by concatenating the letters, as long
as the first switch is not @Flag{-}. The arguments for each switch
 are placed after the collapsed switches (in the order of the
 switches). For example,

@commandline{-ifve @nonterm{file} @nonterm{expr}}

and

@commandline{-i -f @nonterm{file} -v -e @nonterm{expr}}

are equivalent. If a collapsed @Flag{-} appears before other collapsed
switches in the same collapsed set, it is implicitly moved to the end
of the collapsed set.

Extra arguments following the last option are available from the
@indexed-scheme[current-command-line-arguments] parameter.