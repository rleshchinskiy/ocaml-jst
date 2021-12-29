(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*                      Pierre Chambart, OCamlPro                         *)
(*                                                                        *)
(*   Copyright 2015 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** Compiler performance recording

  {b Warning:} this module is unstable and part of
  {{!Compiler_libs}compiler-libs}.

*)

type file = string

val reset : unit -> unit
(** erase all recorded profile information *)

val record_call : ?counter:int -> ?accumulate:bool ->
  ?counter_accumulator:(int -> int -> int) ->
  string -> (unit -> 'a) -> 'a
(** [record_call pass f] calls [f] and records its profile information. *)

val record : ?accumulate:bool -> string -> ('a -> 'b) -> 'a -> 'b
(** [record pass f arg] records the profile information of [f arg] *)

val record_counter : ?accumulate:bool ->
  ?counter_accumulator:(int -> int -> int) ->
  string -> int -> unit
(** [record counter v] records the [value] of named [counter] *)

type column = [ `Time | `Alloc | `Top_heap | `Abs_top_heap | `Counter ]

val print : Format.formatter -> column list -> timings_precision:int -> unit
(** Prints the selected recorded profiling information to the formatter. *)

(** Command line flags *)

val options_doc : string
val all_columns : column list

(** A few pass names that are needed in several places, and shared to
    avoid typos. *)

val generate : string
val transl : string
val typing : string
