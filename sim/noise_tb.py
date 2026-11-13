
import os
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge
from cocotb_tools.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")


@cocotb.test()
async def test_xorshift_noise(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rst.value = 1

    await ClockCycles(dut.clk, 5)
    await FallingEdge(dut.clk)

    dut.rst.value = 0

    await ClockCycles(dut.clk, 1000)


def my_module_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "hdl" / "noise.sv",
    ]

    runner = get_runner(sim)

    runner.build(
        sources=sources,
        hdl_toplevel="noise",
        always=True,
        build_args=["-Wall"],
        timescale=("1ns", "1ps"),
        waves=True,
    )

    runner.test(
        hdl_toplevel="noise",
        test_module=test_file,
        waves=True,
    )


if __name__ == "__main__":
    my_module_runner()
