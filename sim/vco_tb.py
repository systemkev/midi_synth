import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb_tools.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")


async def reset_dut(dut):
    dut.rst.value = 1
    dut.sample_tick.value = 0
    dut.freq_inc.value = 0
    dut.pw.value = 0

    await ClockCycles(dut.clk, 3)
    
    await FallingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_vco_waveforms(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.pw.value = 0x8000
    dut.freq_inc.value = 0x01000000
    dut.sample_tick.value = 1

    valid_cycles = 0
    max_wait = 20
    
    for _ in range(max_wait):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if dut.osc_vld.value == 1:
            break
            
    assert dut.osc_vld.value == 1

    dut._log.info("Cycle |    Saw    |    Tri    |    Sin    |   Pulse   | Sync")
    dut._log.info("-" * 65)
    
    initial_saw = int(dut.osc_saw.value)
    
    for i in range(10):
        await RisingEdge(dut.clk)
        await ReadOnly()
        
        saw = dut.osc_saw.value.signed_integer
        tri = dut.osc_tri.value.signed_integer
        sin = dut.osc_sin.value.signed_integer
        pulse = dut.osc_pulse.value.signed_integer
        sync = int(dut.sync.value)
        
        dut._log.info(f"{i:5} | {saw:9} | {tri:9} | {sin:9} | {pulse:9} | {sync:4}")

    await ClockCycles(dut.clk, 1000)
    await ReadOnly()
    
    assert int(dut.osc_saw.value) != initial_saw


def my_module_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "rtl" / "vco.sv", 
    ]

    build_test_args = ["-Wall"]
    lut_path = proj_path / "mem" / "sine4096_24bit.mem"

    assert lut_path.is_file(), f"Missing sine LUT: {lut_path}"

    parameters = {
        "FILE_NAME": f'"{lut_path.as_posix()}"',
        "LUT_DEPTH": 12,
        "SIN_WIDTH": 24,
        "SND_WIDTH": 24,
        "ACC_WIDTH": 32,
        "PUL_WIDTH": 16,
    }

    runner = get_runner(sim)
    
    runner.build(
        sources=sources,
        hdl_toplevel="vco",  
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )

    runner.test(
        hdl_toplevel="vco",  
        test_module=test_file,
        waves=True,
    )

if __name__ == "__main__":
    my_module_runner()