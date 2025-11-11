vlib work 
vlog -sv -cover bcst ./apb_slave.sv ./tb.sv 
vsim -coverage TB -do "log -r /*; run -all; coverage save cov.ucdb; coverage report -details -output coverage_full.txt; coverage report -details -du=apb_slave -output coverage_apb_slave.txt; coverage report -details -du=TB -output coverage_tb.txt;"
