import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb_tools.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")


async def reset_dut(dut):
    """Reset the module before starting each test."""
    dut.rst.value = 1

    # default inputs!!

    # wait a few clock cycles
    await ClockCycles(dut.clk, 3)
    
    # deassert reset on the falling edge for clean setup
    await FallingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def basic_test(dut):
    # start a 10ns (100MHz) clock
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    # reset
    await reset_dut(dut)

    @FallingEdge


def my_module_runner():
    """Build and run the tests using cocotb."""
    sim = os.getenv("SIM", "xsim")
    proj_path = Path(__file__).resolve().parent.parent

    # config!!!
    sources = [
        proj_path / "hdl" / "MODULE_NAME.sv",
    ]

    # set compiler arguments and module parameters
    build_test_args = ["-Wall"]
    parameters = {} # e.g. {"WIDTH": 16}

    runner = get_runner(sim)
    
    # compile the design
    runner.build(
        sources=sources,
        hdl_toplevel="MODULE_NAME",  
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )

    runner.test(
        hdl_toplevel="MODULE_NAME",  
        test_module=test_file,
        waves=True,
    )

if __name__ == "__main__":
    my_module_runner()