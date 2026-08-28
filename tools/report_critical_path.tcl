package require ::quartus::project
package require ::quartus::sta

project_open Arcade-MarbleMadness2 -revision Arcade-MarbleMadness2
create_timing_netlist
read_sdc
update_timing_netlist

report_timing -setup -npaths 10 -detail full_path \
	-file output_files/Arcade-MarbleMadness2.critical_paths.txt

delete_timing_netlist
project_close
