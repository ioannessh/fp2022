open Make_lib

let () =
  Stdlib.Sys.chdir "demo_project";
  let input = Core.In_channel.read_all "./Makefile" in
  Pretty_print.pretty_print input
;;
