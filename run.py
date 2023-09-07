#!/usr/bin/env python3

import sys, os
from pathlib import Path
sys.path.insert(0, 
                Path("submodules/vunit").absolute().as_posix())

from vunit import VUnit

VIVADO = Path(os.environ["XILINX_VIVADO"])

vu = VUnit.from_argv()

vu.add_verilog_builtins()
lib = vu.add_library("worklib")
lib.add_source_files(VIVADO / "data/verilog/src/glbl.v")
lib.add_source_files(VIVADO / "data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv")
lib.add_source_files(VIVADO / "data/ip/xpm/xpm_memory/hdl/xpm_memory.sv")
lib.add_source_files(VIVADO / "data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv")
lib.add_source_files("rtl/*.sv")
lib.add_source_files("sim/*.sv")

vu.set_sim_option("modelsim.vsim_flags", ["worklib.glbl", "-voptargs=+acc"])
vu.main()
