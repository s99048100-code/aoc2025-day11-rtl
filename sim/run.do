transcript on
if {![file exists work]} { vlib work }
vmap work work
vlog src/day11_top.v tb/tb_day11.v
vsim tb_day11
run -all
