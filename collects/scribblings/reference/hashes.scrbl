#lang scribble/doc
@(require "mz.ss")

@title[#:tag "hashtables"]{Hash Tables}

A @deftech{hash table} (or simply @deftech{hash}) maps each of its
keys to a single value. For a given hash table, keys are equivalent
via @scheme[equal?] or @scheme[eq?], and keys are retained either
strongly or weakly (see @secref["weakbox"]). A hash table is also
either mutable or immutable; immutable tables support constant-time
functional update.

A hash table can be used as a two-valued @tech{sequence} (see
@secref["sequences"]). The keys and values of the hash table serve as
elements of the sequence (i.e., each element is a key and its
associated value). If a mapping is added to or removed from the hash
table during iteration, then an iteration step may fail with
@scheme[exn:fail:contract], or the iteration may skip or duplicate
keys and values.  See also @scheme[in-hash], @scheme[in-hash-keys],
@scheme[in-hash-values], and @scheme[in-hash-pairs].

Two hash tables are @scheme[equal?] if they use the same
key-comparison procedure (@scheme[equal?] or @scheme[eq?]), if they
both hold keys strongly or weakly, and if they have the same
mutability.

@bold{Caveats concerning concurrent modification:} A mutable hash
table can be manipulated with @scheme[hash-ref], @scheme[hash-set!],
and @scheme[hash-remove!] concurrently by multiple threads, and the
operations are protected by a table-specific semaphore as needed. Two
caveats apply, however:

 @itemize{

  @item{If a thread is terminated while applying @scheme[hash-ref],
  @scheme[hash-set!], or @scheme[hash-remove!] to a hash table that
  uses @scheme[equal?] key comparisons, all current and future
  operations on the hash table block indefinitely.}

  @item{The @scheme[hash-map] and @scheme[hash-for-each] procedures do
  not use the table's semaphore. Consequently, if a hash table is
  extended with new keys by another thread while a map or for-each
  traversal is in process, arbitrary key--value pairs can be dropped
  or duplicated in the traversal. Similarly, if a map or for-each
  procedure itself extends the table, arbitrary key--value pairs can
  be dropped or duplicated. However, key mappings can be deleted or
  remapped by any thread with no adverse affects (i.e., the change
  does not affect a traversal if the key has been seen already,
  otherwise the traversal skips a deleted key or uses the remapped
  key's new value).}

 }

@bold{Caveat concerning mutable keys:} If a key into an
@scheme[equal?]-based hash table is mutated (e.g., a key string is
modified with @scheme[string-set!]), then the hash table's behavior
for insertion and lookup operations becomes unpredictable.


@defproc[(hash? [v any/c]) boolean?]{

Returns @scheme[#t] if @scheme[v] is a @tech{hash table}, @scheme[#f]
otherwise.}

@defproc[(hash-eq? [hash hash?]) boolean?]{

Returns @scheme[#t] if @scheme[hash] compares keys with @scheme[eq?],
@scheme[#f] if it compares with @scheme[equal?].}


@defproc[(hash-weak? [hash hash?]) boolean?]{

Returns @scheme[#t] if @scheme[hash] retains its keys weakly,
@scheme[#f] if it retains keys strongly.}


@defproc[(make-hash) hash?]{

Creates an empty mutable hash table that holds keys strongly and that
uses @scheme[equal?] to compare keys. See also
@scheme[make-custom-hash].}


@defproc[(make-hasheq) (and/c hash? hash-eq?)]{

Creates an empty mutable hash table that holds keys strongly and that
uses @scheme[eq?] to compare keys.}


@defproc[(make-weak-hash) (and/c hash? hash-weak?)]{

Creates an empty mutable hash table that holds keys weakly and that
uses @scheme[equal?] to compare keys.  See also
@scheme[make-weak-custom-hash].}


@defproc[(make-weak-hasheq) (and/c hash? hash-eq? hash-weak?)]{

Creates an empty mutable hash table that holds keys weakly and that
uses @scheme[eq?] to compare keys.}


@defproc[(make-immutable-hash [assocs (listof pair?)])
         (and/c hash? immutable?)]{

Creates an immutable hash table that compares keys with
@scheme[equal?]. In each element of @scheme[assocs], the @scheme[car]
of each pair is a key, and the @scheme[cdr] is the corresponding
value. The mappings are added to the table in the order that they
appear in @scheme[assocs], so later mappings can hide earlier
mappings.}

@defproc[(make-immutable-hasheq [assocs (listof pair?)])
         (and/c hash? hash-eq? immutable?)]{

Like @scheme[make-immutable-hash], but the resulting hash table
compares keys with @scheme[eq?].}


@defproc[(hash-set! [hash (and/c hash? (not/c immutable?))]
                    [key any/c]
                    [v any/c]) void?]{

Maps @scheme[key] to @scheme[v] in @scheme[hash], overwriting
any existing mapping for @scheme[key].}


@defproc[(hash-set [hash (and/c hash? immutable?)]
                   [key any/c]
                   [v any/c])
          (and/c hash? immutable?)]{

Functionally extends @scheme[hash] by mapping @scheme[key] to
@scheme[v], overwriting any existing mapping for @scheme[key], and
returning an extended hash table.}


@defproc[(hash-ref [hash hash?]
                   [key any/c]
                   [failure-result any/c (lambda () (raise (make-exn:fail ....)))])
         any]{

Returns the value for @scheme[key] in @scheme[hash]. If no value
is found for @scheme[key], then @scheme[failure-result] determines the
result: 

@itemize{

 @item{If @scheme[failure-result] is a procedure, it is called
       (through a tail call) with no arguments to produce the result.}

 @item{Otherwise, @scheme[failure-result] is returned as the result.}

}}


@defproc[(hash-remove! [hash (and/c hash? (not/c immutable?))]
                       [key any/c])
         void?]{

Removes any existing mapping for @scheme[key] in @scheme[hash].}


@defproc[(hash-remove [hash (and/c hash? immutable?)]
                      [key any/c])
         (and/c hash? immutable?)]{

Functionally removes any existing mapping for @scheme[key] in
@scheme[hash], returning the updated hash table.}


@defproc[(hash-map [hash hash?]
                   [proc (any/c any/c . -> . any/c)])
         (listof any/c)]{

Applies the procedure @scheme[proc] to each element in
@scheme[hash] in an unspecified order, accumulating the results
into a list. The procedure @scheme[proc] is called each time with a
key and its value. See the caveat above about concurrent
modification.}


@defproc[(hash-for-each [hash hash?]
                        [proc (any/c any/c . -> . any)])
         void?]{

Applies @scheme[proc] to each element in @scheme[hash] (for the
side-effects of @scheme[proc]) in an unspecified order. The procedure
@scheme[proc] is called each time with a key and its value. See the
caveat above about concurrent modification.}


@defproc[(hash-count [hash hash?])
         nonnegative-exact-integer?]{

Returns the number of keys mapped by @scheme[hash]. If
@scheme[hash] is not created with @scheme['weak], then the
result is computed in constant time and atomically. If
@scheme[hash] is created with @scheme['weak], see the caveat
above about concurrent modification.}


@defproc[(hash-iterate-first [hash hash?])
         (or/c false/c nonnegative-exact-integer?)]{

Returns @scheme[#f] if @scheme[hash] contains no elements, otherwise
it returns an integer that is a index to the first element in the hash
table; ``first'' refers to an unspecified ordering of the table
elements, and the index values are not necessarily consecutive
integers. For a mutable @scheme[hash], this index is guaranteed to
refer to the first item only as long as no items are added to or
removed from @scheme[hash].}

@defproc[(hash-iterate-next [hash hash?]
                            [pos nonnegative-exact-integer?])
         (or/c false/c nonnegative-exact-integer?)]{

Returns either an integer that is an index to the element in
@scheme[hash] after the element indexed by @scheme[pos] (which is not
necessarily one more than @scheme[pos]) or @scheme[#f] if @scheme[pos]
refers to the last element in @scheme[hash]. If @scheme[pos] is not a
valid index, then the @exnraise[exn:fail:contract]. For a mutable
@scheme[hash], the result index is guaranteed to refer to its item
only as long as no items are added to or removed from @scheme[hash].}


@defproc[(hash-iterate-key [hash hash?]
                           [pos nonnegative-exact-integer?])
         any]{

Returns the key for the element in @scheme[hash] at index
@scheme[pos]. If @scheme[pos] is not a valid index for
@scheme[hash], the @exnraise[exn:fail:contract].}


@defproc[(hash-iterate-value [hash hash?]
                             [pos nonnegative-exact-integer?])
         any]{

Returns the value for the element in @scheme[hash] at index
@scheme[pos]. If @scheme[pos] is not a valid index for
@scheme[hash], the @exnraise[exn:fail:contract].}


@defproc[(hash-copy [hash hash?]) 
         (and/c hash? (not/c immutable?))]{

Returns a mutable hash table with the same mappings, same
key-comparison mode, and same key-holding strength as @scheme[hash].}


@defproc[(eq-hash-code [v any/c]) exact-integer?]{

Returns an exact integer; for any two @scheme[eq?] values, the
returned integer is the same. Furthermore, for the result integer
@scheme[k] and any other exact integer @scheme[j], @scheme[(= k j)]
implies @scheme[(eq? k j)].}


@defproc[(equal-hash-code [v any/c]) exact-integer?]{

Returns an exact integer; for any two @scheme[equal?] values, the
returned integer is the same.  Furthermore, for the result integer
@scheme[k] and any other exact integer @scheme[j], @scheme[(= k j)]
implies @scheme[(eq? k j)]. A has code is computed even when
@scheme[v] contains a cycle through pairs, vectors, boxes, and/or
inspectable structure fields. See also @scheme[prop:equal+hash].}

@defproc[(equal-secondary-hash-code [v any/c]) exact-integer?]{

Like @scheme[equal-hash-code], but computes a secondary value suitable
for use in double hashing.}
