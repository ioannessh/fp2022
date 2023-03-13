open Parser
open Ast
open Graph

exception NoRule of string
exception NoRuleNeed of string * string
exception IsUpToDate of string
exception RuleError of string * int
exception NothingToBeDone of string
exception AllDone


(* Substitute variable values in string *)
let insert_vars_values vars_map (targets_as_string: substring list) = 
  let var_value name = 
    match VMap.find_opt name vars_map with
    | None -> ""
    | Some s -> s
  in
  let get_str substr = 
    match substr with
    | STR s -> s
    | VAR v -> var_value v
  in
  List.fold_left (fun init x -> init^(get_str x)) "" targets_as_string

let insert_vars vars_map targets = 
  let targets_as_words = Parser.substrings_parser (targets^" ") in
  insert_vars_values vars_map targets_as_words
;;

(*== Fill maps ==*)
(*= Fill vars map =*)
let fill_var_map vars_map exprs = 
  let set_var name value map = 
    if VMap.mem name map
    then
      VMap.update name (fun _ -> Some value) map
    else
      VMap.add name value map
  in
  let choise_decl map expr = 
    match expr with
    | RULE _ -> map
    | VAR_DEC (name, value) -> set_var name value map
  in
  List.fold_left choise_decl vars_map exprs

(*= Fill rules and prerequisites map =*)
let set_rules targets rules map = 
  let set_rule map target = 
    if VMap.mem target map
    then
      (Printf.eprintf 
      "Makefile: warning: overriding recipe for target '%s'\n\
      Makefile: warning: ignoring old recipe for target '%s'\n" target target;
      VMap.update target (fun _ -> Some rules) map)
    else
      VMap.add target rules map
  in
  List.fold_left set_rule map targets

let set_prereqs targets prereqs map = 
  let set_prereq map target = 
    if VMap.mem target map
    then
      VMap.update target (fun l -> Some (List.concat [prereqs; (Option.get l)])) map
    else
      VMap.add target prereqs map
  in
  List.fold_left set_prereq map targets

let fill_maps vars_map exprs = 
  let targets rule = words_parser (insert_vars vars_map rule.targets) in
  let prerequisites rule = words_parser (insert_vars vars_map rule.prerequisites) in
  let choise_decl (rules_map, prereqs_map) expr = 
    match expr with
    | RULE rule -> (set_rules (targets rule) rule.commands rules_map), (set_prereqs (targets rule) (prerequisites rule) prereqs_map)
    | VAR_DEC _ -> rules_map, prereqs_map
  in
  List.fold_left choise_decl (VMap.empty, VMap.empty) exprs
;;

(* Run rules *)
let exec_rule rule vars_map target = 
  let echo command = Sys.command (String.concat " " ["echo"; command]) in
  let choise_decl str = 
    let command = insert_vars_values vars_map str in
    let retcode = 
      if String.starts_with ~prefix:"@" command then
        let command = (String.mapi (fun i c1 -> if 0 = i then ' ' else c1) command) in
        (Sys.command command)
      else let _ = (echo command) in (Sys.command command) in
    if retcode <> 0 
    then raise (RuleError (target, retcode)) 
    else ()
  in
  List.iter choise_decl rule

let try_exec rules_map vars_map prereqs_map graph (node : G.Node.t) marked_nodes goal = 
  let target = node.node.name in
  let vars_map = VMap.update "@" (fun _ -> Some target) vars_map in
  let self_prerequisites = 
    match VMap.find_opt target prereqs_map with
    | None -> ""
    | Some s -> (String.concat " " s)
  in
  let vars_map = VMap.update "^" (fun _ -> Some self_prerequisites) vars_map in
  if Base.Sequence.exists (G.Node.succs node graph) ~f:(fun child -> G.Node.Set.mem marked_nodes child)
  then (
    exec_rule (VMap.find target rules_map) vars_map target;
    (G.Node.Set.add marked_nodes node))
  else if Sys.file_exists target
    then (
      if target = goal
      then raise (IsUpToDate target)
      else if compare_time_stats_of_childs graph node
      then (G.Node.Set.add marked_nodes node)
      else marked_nodes
    )
  else
  match VMap.find_opt target rules_map with
  | None -> raise (NoRuleNeed (target, goal))
  | Some [] -> raise (NothingToBeDone target)
  | Some rule -> exec_rule rule vars_map target; (G.Node.Set.add marked_nodes node)
;;

(* Run DFS on graph *)
let run_dfs rules_map vars_map prereqs_map graph vertex_map target = 
  if not (VMap.mem target vertex_map) || not (VMap.mem target rules_map)
  then raise (NoRule target)
  else
  let start_node = VMap.find target vertex_map in
  let enter_n = (fun _ (_: G.Node.t) stat -> stat)
  in
  let leave_n = (fun _ (node: G.Node.t) stat ->
    if stat.in_tree
    then stat
    else { stat with marked_nodes = 
          (try_exec rules_map vars_map prereqs_map graph node stat.marked_nodes target) })
  in
  dfs start_node graph enter_n leave_n |> (fun _ -> ())
;;

(*===== INTERPRETER =====*)
let exec_exprs exprs main_targets = 
  let vars_map = fill_var_map VMap.empty exprs in
  let vars_map = VMap.add "@" "@" vars_map in
  let vars_map = VMap.add "^" "^" vars_map in
  let vars_map = VMap.add "$" "$" vars_map in
  let rules_map, prereqs_map = fill_maps vars_map exprs in
  let targets = VMap.fold (fun target _ targets -> (List.append [target] targets)) rules_map [] in
  let vartex_map, graph = create_graph targets prereqs_map in
  try 
    List.iter (run_dfs rules_map vars_map prereqs_map graph vartex_map) main_targets;
    raise AllDone
  with
  | NoRule target -> Printf.eprintf "make: *** No rule to make target `%s`. Stop.\n" target
  | IsUpToDate target -> Printf.eprintf "make: `%s` is up to date.\n" target
  | RuleError (err, retcode) -> Printf.eprintf "make: *** [Makefile: %s] Error %d\n" err retcode
  | NothingToBeDone target -> Printf.eprintf "make: Nothing to be done for `%s`.\n" target
  | NoRuleNeed (prereq, goal) -> Printf.eprintf "No rule to make target `%s`, needed by `%s`.\n" prereq goal
  | AllDone -> ()
  | InvalidVarName s -> Printf.eprintf "Char '%s' cannot be used in variable name. \n" s
  | InvalidString (input, _) -> Printf.eprintf "String \"%s\" cannot be parsed\n" input
;;

let interpret input targets = 
  let targets = if 0 = List.length targets then ["all"] else targets in
  match parser input with
  | Result.Ok res -> exec_exprs res targets
  | Error e -> print_string e
;;
let array_to_list xs =
  Array.fold_right List.cons xs []
;;

(*=============================*)
(*============TESTS============*)
(*=============================*)
let test_vars = VMap.add "t1" "some" VMap.empty;;
