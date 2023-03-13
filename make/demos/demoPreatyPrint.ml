open Make_lib

let () =
  Stdlib.Sys.chdir "demo_project";
  let input = Core.In_channel.read_all "./Makefile" in
  Preaty_print.preaty_print input
;;