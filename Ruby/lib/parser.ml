(** Copyright 2021-2022, Kakadu and contributors *)

(** SPDX-License-Identifier: LGPL-3.0-or-later *)

open Angstrom
open Ast

(** Lexer *)
let token_separator = take_while (fun x -> Char.equal x ' ')

let as_token p = token_separator *> p <* token_separator

let expr_separator =
  take_while1 (fun x -> Char.equal x '\n' || Char.equal x ';')
  >>| (fun _ -> ";")
  |> as_token
;;

let new_lines = take_while1 (fun x -> Char.equal x '\n') >>| (fun _ -> "\n") |> as_token

let is_digit = function
  | '0' .. '9' -> true
  | _ -> false
;;

let integer_t = take_while1 is_digit |> as_token
let true_t = string "true" |> as_token
let false_t = string "false" |> as_token
let bool_t = true_t <|> false_t

let ruby_string =
  char '"' *> take_while (fun c -> not (Char.equal c '"')) <* char '"' |> as_token
;;

let asoc0_t = choice [ string "&&"; string "*"; string "/" ] |> as_token
let asoc1_t = choice [ string "||"; string "+"; string "-" ] |> as_token

let asoc2_t =
  choice [ string "=="; string "!="; string ">="; string "<="; string ">"; string "<" ]
  |> as_token
;;

let binops = choice [ asoc0_t; asoc1_t; asoc2_t ]

let is_letter = function
  | 'a' .. 'z' -> true
  | 'A' .. 'Z' -> true
  | _ -> false
;;

let is_letter_or_und c = is_letter c || c = '_'
let keywords = [ "if"; "then"; "else"; "end"; "true"; "false"; "while"; "do"; "def" ]

let identifier_t =
  take_while1 is_letter_or_und
  >>= (fun s1 ->
        take_while (fun c -> is_letter_or_und c || is_digit c) >>| fun s2 -> s1 ^ s2)
  |> as_token
  >>= fun i ->
  match List.find_opt (String.equal i) keywords with
  | Some _ -> fail "Keyword can't be identifier"
  | None -> return i
;;

let token s = as_token (string s)

(** Parser *)

let bool_t = true_t <|> false_t

let literal =
  choice
    [ (integer_t >>| fun s -> IntegerL, s)
    ; (bool_t >>| fun s -> BoolL, s)
    ; (ruby_string >>| fun s -> StringL, s)
    ]
  >>| fun (t, s) -> Literal (t, s)
;;

let wr_binop p = p >>| fun op l r -> Binop (op, l, r)
let binop_v = wr_binop binops
let asoc0 = wr_binop asoc0_t
let asoc1 = wr_binop asoc1_t
let asoc2 = wr_binop asoc2_t
let var_cal = identifier_t >>| fun s -> Var s

let chainl1 e op =
  let rec go acc = lift2 (fun f x -> f acc x) op e >>= go <|> return acc in
  e >>= fun init -> go init
;;

let parens p = token "(" *> p <* token ")"
let maybe p = p <|> return ""

let seq_of_expr =
  fix (fun seq_of_expr ->
    let expr =
      fix (fun expr ->
        (* --- Functions --- *)
        let parameters_decl = token "(" *> sep_by (token ",") identifier_t <* token ")" in
        let function_declaration =
          token "def" *> identifier_t
          >>= fun func_name ->
          option [] parameters_decl
          >>= fun params ->
          maybe new_lines *> seq_of_expr
          <* maybe new_lines
          <* token "end"
          >>| fun f_body -> FuncDeclaration (func_name, params, f_body)
        in
        let invocation =
          choice [ var_cal; parens expr ]
          >>= fun inv_box ->
          token "(" *> sep_by (token ",") expr
          <* token ")"
          >>| fun param_values -> Invocation (inv_box, param_values)
        in
        (* --- Var assn --- *)
        let assn =
          identifier_t
          >>= fun i -> token "=" *> expr >>| fun var_val -> VarAssign (i, var_val)
        in
        (* --- While --- *)
        let while_loop =
          token "while" *> expr
          >>= fun cond ->
          maybe (token "do") *> seq_of_expr
          <* token "end"
          >>= fun body -> return (WhileLoop (cond, body))
        in
        (* --- Conditional ---*)
        let conditional =
          token "if" *> maybe new_lines *> expr
          <* maybe new_lines
          >>= (fun condition ->
                token "then" *> maybe new_lines *> seq_of_expr
                <* maybe new_lines
                >>= fun thenB ->
                option
                  (Conditional (condition, thenB, Literal (NilL, "Nil")))
                  (string "else" *> maybe new_lines *> seq_of_expr
                  <* maybe new_lines
                  >>= fun elseB -> return (Conditional (condition, thenB, elseB))))
          <* token "end"
        in
        (* --- Array declaration --- *)
        let array_t = token "[" *> sep_by (token ",") expr <* token "]" in
        let array_v = array_t >>| fun arr -> ArrayDecl arr in
        (* --- Indexing --- *)
        let index_p =
          choice
            ~failure_msg:"Unrecognized index target"
            [ var_cal
            ; (ruby_string >>| fun s -> Literal (StringL, s))
            ; array_v
            ; parens expr
            ]
          >>= fun box -> token "[" *> expr <* token "]" >>| fun ind -> Indexing (box, ind)
        in
        (* --- Binops ---*)
        let factor =
          choice
            ~failure_msg:"Unrecognized factor"
            [ index_p; invocation; parens expr; literal; var_cal; conditional; array_v ]
        in
        let asoc0_p = chainl1 factor asoc0 in
        let asoc1_p = chainl1 asoc0_p asoc1 in
        let asoc2_p = chainl1 asoc1_p asoc2 in
        (* --- Expr definition --- *)
        choice
          ~failure_msg:"Unrecognized expression"
          [ function_declaration; assn; asoc2_p; parens expr; while_loop; array_v ])
    in
    maybe new_lines *> sep_by expr_separator expr <* maybe new_lines >>| fun s -> Seq s)
;;

let parse (str : string) : ast =
  match parse_string ~consume:All seq_of_expr str with
  | Ok v -> v
  | Error msg -> failwith msg
;;
