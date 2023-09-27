#!/usr/bin/env python3

import sys, os
from pathlib import Path
sys.path.insert(
    0, 
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
tb = lib.test_bench("tb_axis_width_conv_generic")
for N, M, LCM in [(8,1,16),(8,2,16),(8,3,24),(8,5,40),(8,6,24),(8,7,56),
                  (1,8,16),(2,8,16),(3,8,24),(5,8,40),(6,8,24),(7,8,56)]:
    tb.add_config(
        name = f"N{N}:M{M}:LCM{LCM}",
        parameters = dict(N = N, M = M, LCM = LCM, NREQUESTS = 1024))

tb = lib.test_bench("tb_axis_width_conv_wide_narrow")
for N, M in [(8,1),(8,2),(8,4)]:
    tb.add_config(
        name = f"N{N}:M{M}",
        parameters = dict(N = N, M = M, NREQUESTS = 1024))

tb = lib.test_bench("tb_axis_width_conv_narrow_wide")
for N, M in [(1,8),(2,8),(4,8)]:
    tb.add_config(
        name = f"N{N}:M{M}",
        parameters = dict(N = N, M = M, NREQUESTS = 1024))
    
tb = lib.test_bench("tb_axis_width_conv")
for N, M, LCM in [(8,1,8),(8,2,8),(8,3,24),(8,4,8),(8,5,40),(8,6,24),(8,7,56),
                  (1,8,8),(2,8,8),(3,8,24),(4,8,8),(5,8,40),(6,8,24),(7,8,56)]:
    tb.add_config(
        name = f"N{N}:M{M}:LCM{LCM}",
        parameters = dict(N = N, M = M, LCM = LCM, NREQUESTS = 1024))
vu.main()
