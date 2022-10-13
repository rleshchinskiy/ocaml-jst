(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 2002 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

(** The batch compiler *)

open Misc
open Compile_common

let tool_name = "ocamlopt"

let with_info =
  Compile_common.with_info ~native:true ~tool_name

let interface ~source_file ~output_prefix =
  with_info ~source_file ~output_prefix ~dump_ext:"cmi" @@ fun info ->
  Compile_common.interface
    ~hook_parse_tree:(fun _ -> ())
    ~hook_typed_tree:(fun _ -> ())
    info

let (|>>) (x, y) f = (x, f y)

(** Native compilation backend for .ml files. *)

let flambda i backend typed =
  typed
  |> Profile.(record transl)
      (Translmod.transl_implementation_flambda i.module_name)
  |> Profile.(record generate)
    (fun {Lambda.module_ident; main_module_block_size;
          required_globals; code } ->
    ((module_ident, main_module_block_size), code)
    |>> print_if i.ppf_dump Clflags.dump_rawlambda Printlambda.lambda
    |>> Simplif.simplify_lambda
    |>> print_if i.ppf_dump Clflags.dump_lambda Printlambda.lambda
    |> (fun ((module_ident, main_module_block_size), code) ->
      let program : Lambda.program =
        { Lambda.
          module_ident;
          main_module_block_size;
          required_globals;
          code;
        }
      in
      Asmgen.compile_implementation
        ~backend
        ~filename:i.source_file
        ~prefixname:i.output_prefix
        ~middle_end:Flambda_middle_end.lambda_to_clambda
        ~ppf_dump:i.ppf_dump
        program);
    Compilenv.save_unit_info (cmx i))

let clambda i backend typed =
  Clflags.set_oclassic ();
  typed
  |> Profile.(record transl)
    (Translmod.transl_store_implementation i.module_name)
  |> print_if i.ppf_dump Clflags.dump_rawlambda Printlambda.program
  |> Profile.(record generate)
    (fun program ->
       let code = Simplif.simplify_lambda program.Lambda.code in
       { program with Lambda.code }
       |> print_if i.ppf_dump Clflags.dump_lambda Printlambda.program
       |> Asmgen.compile_implementation
            ~backend
            ~filename:i.source_file
            ~prefixname:i.output_prefix
            ~middle_end:Closure_middle_end.lambda_to_clambda
            ~ppf_dump:i.ppf_dump;
       Compilenv.save_unit_info (cmx i))

let reset_compilenv ~module_name =
  let for_pack_prefix = Compilation_unit.Prefix.from_clflags () in
  let comp_unit =
    Compilation_unit.create for_pack_prefix
      (Compilation_unit.Name.of_string module_name)
  in
  Compilenv.reset comp_unit

(* Emit assembly directly from Linear IR *)
let emit i =
  reset_compilenv ~module_name:i.module_name;
  Asmgen.compile_implementation_linear i.output_prefix ~progname:i.source_file

let implementation ~backend ~start_from ~source_file
    ~output_prefix ~keep_symbol_tables:_ =
  let backend info typed =
    reset_compilenv ~module_name:info.module_name;
    if Config.flambda
    then flambda info backend typed
    else clambda info backend typed
  in
  with_info ~source_file ~output_prefix ~dump_ext:"cmx" @@ fun info ->
  (match (start_from:Clflags.Compiler_pass.t) with
  | Parsing ->
    Compile_common.implementation
      ~hook_parse_tree:(fun _ -> ())
      ~hook_typed_tree:(fun _ -> ())
      info ~backend
  | Emit -> emit info
  | _ -> Misc.fatal_errorf "Cannot start from %s"
           (Clflags.Compiler_pass.to_string start_from));
  let file_prefix = info.output_prefix ^ ".cmx.profile" in
  Compmisc.with_ppf_dump ~file_prefix @@ fun ppf ->
  Profile.print ppf !Clflags.profile_columns ~timings_precision:!Clflags.timings_precision;
  Profile.reset ()
