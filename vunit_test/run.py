from vunit import VUnit

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../src/gowin_rpll/gowin_rpll.v", file_type="systemverilog")
lib.add_source_files("../src/psram_controller.v", file_type="systemverilog")
lib.add_source_files("../src/psram_test_top.v", file_type="systemverilog")
lib.add_source_files("../src/uart_tx.v", file_type="systemverilog")
lib.add_source_files("C:/Gowin/Gowin_V1.9.8.09_Education/IDE/simlib/gw1n/prim_sim.v", file_type="systemverilog")
#lib.add_source_files("C:/Gowin/Gowin_V1.9.8.09_Education/IDE/simlib/gw1n/prim_tsim.v", file_type="systemverilog")

# Run vunit function
vu.main()
