#lang scribble/doc
@require[scribble/manual]
@require[scribble/eval]
@require["guide-utils.ss"]

@title[#:tag "contracts"]{Contracts}

@local-table-of-contents[]

@;{

Somewhere, discuss eq? and its impact on lists and
procedures. Also, discuss difference between contracts on
mutable datastructures & contracts on immutable ones.

}

@include-section["contracts-intro.scrbl"]
@include-section["contracts-simple-function.scrbl"]
@include-section["contracts-general-function.scrbl"]
@;{
@include-section["contracts-structure.scrbl"]
@include-section["contracts-class.scrbl"]
@include-section["contracts-example.scrbl"]
@include-section["contract-gotchas.scrbl"]
}