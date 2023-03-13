open Graphlib.Std
open Ppx_hash_lib.Std.Hash.Builtin
open Ppx_compare_lib.Builtin
open Ppx_sexp_conv_lib.Conv

module VMap = Map.Make (String)

module Node: sig
  type t = { name: string }
  [@@deriving compare, hash, sexp]

  include Core.Comparable.S with type t := t
  include Core.Hashable.S with type t := t
end = struct
  module T = struct
    type t = { name: string }
    [@@deriving compare, hash, sexp]
  end

  include T
  include Core.Comparable.Make (T)
  include Core.Hashable.Make (T)
end

(*= Init Graph =*)
module G = Graphlib.Labeled (Node) (Bool) (Unit)

type dfs_state = { in_tree : bool; marked_nodes: G.Node.Set.t }

(* Fill Graph *)
let create_vertex map target = 
  match VMap.find_opt target map with
  | None -> 
    let vertex = G.Node.create { node={name=target}; node_label=false } in
    let map = VMap.add target vertex map in
    vertex, map
  | Some vertex -> vertex, map

let create_graph target_list prereqs_map =
  let map = VMap.empty in
  let graph = G.empty in
  let insert_vertex (map, graph) target = 
    let parent, map = create_vertex map target in
    let graph = G.Node.insert parent graph in
    let prereqs = VMap.find target prereqs_map in
    let insert_edge (map, graph) target = 
      let child, map = create_vertex map target in
      let graph = G.Edge.insert (G.Edge.create parent child ()) graph in
      (map, graph)
    in
    let map, graph = List.fold_left insert_edge (map, graph) prereqs in
    map, graph
  in
  List.fold_left insert_vertex (map, graph) target_list
;;

(* Traverse Graph(dfs) *)
let dfs node graph enter_node leave_node = 
  let reachable = 
    Graphlib.fold_reachable (module G) ~init:G.Node.Set.empty ~f:G.Node.Set.add graph node
  in
  Graphlib.depth_first_search
    (module G)
    graph
    ~start:node
    ~start_tree:(fun node state ->
      if G.Node.Set.mem reachable node
      then state
      else { state with in_tree = true })
    ~init:{ in_tree = false; marked_nodes = G.Node.Set.empty }
    ~leave_edge:(fun kind edge state ->
      match kind with
      | `Back ->
        Printf.printf
          "make: Circular %s <- %s dependency dropped.\n"
          (G.Edge.src edge).node.name
          (G.Edge.dst edge).node.name;
        state
      | _ -> state)
    ~enter_node:enter_node
    ~leave_node:leave_node
;;

let compare_time_stats_of_childs graph (node : G.Node.t) = 
  let target = node.node.name in
  let compare_time_stats target child = 
    (not (Sys.file_exists child)) || ((Unix.stat child).st_mtime > (Unix.stat target).st_mtime)
  in
  Base.Sequence.exists (G.Node.succs node graph) ~f:(fun child -> compare_time_stats target child.node.name)
;;
