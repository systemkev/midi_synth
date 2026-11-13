import os
import sys
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, ReadOnly
from cocotb.utils import get_sim_time
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


async def wait_for_valid(dut, max_wait=20):
    """Helper to wait for the oscillator to become valid"""
    for _ in range(max_wait):
        await RisingEdge(dut.clk)
        await ReadOnly()
        if dut.osc_vld.value == 1:
            return
    assert dut.osc_vld.value == 1, "Oscillator valid signal never went high"


@cocotb.test()
async def test_vco_frequency_sweep(dut):
    """Test case 1: Continuously change the frequency over time"""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    # Set initial parameters
    dut.pw.value = 0x8000          # 50% duty cycle
    dut.sample_tick.value = 1
    
    start_freq = 0x00100000
    dut.freq_inc.value = start_freq

    await wait_for_valid(dut)

    dut._log.info("Starting continuous frequency sweep...")
    dut._log.info("Time(ns) | freq_inc")
    dut._log.info("-" * 25)

    # Sweep frequency upwards over time
    # ACC_WIDTH is 32, so we can sweep within that range
    freq_step = 0x00050000
    current_freq = start_freq
    
    for i in range(50):
        # Wait some cycles before changing frequency again
        await ClockCycles(dut.clk, 20) 
        
        current_freq += freq_step
        dut.freq_inc.value = current_freq
        
        if i % 10 == 0:
            time_ns = get_sim_time('ns')
            dut._log.info(f"{time_ns:8.0f} | 0x{current_freq:08X}")

    # Run for a bit at the final frequency
    await ClockCycles(dut.clk, 200)
    dut._log.info("Frequency sweep complete.")


@cocotb.test()
async def test_vco_pw_sweep(dut):
    """Test case 2: Continuously change the pulse width over time"""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    # Set initial parameters
    dut.freq_inc.value = 0x01000000 # Constant frequency
    dut.sample_tick.value = 1
    
    start_pw = 0x0000
    dut.pw.value = start_pw

    await wait_for_valid(dut)

    dut._log.info("Starting continuous pulse width sweep...")
    dut._log.info("Time(ns) | pw")
    dut._log.info("-" * 20)

    # Sweep PW from 0 to near 100% over time
    # PUL_WIDT is 16, so max value is 0xFFFF
    pw_step = 0x0400  
    current_pw = start_pw
    
    for i in range(60):
        await ClockCycles(dut.clk, 20) 
        
        current_pw += pw_step
        if current_pw > 0xFFFF:
            current_pw = 0xFFFF
            
        dut.pw.value = current_pw
        
        if i % 10 == 0:
            time_ns = get_sim_time('ns')
            dut._log.info(f"{time_ns:8.0f} | 0x{current_pw:04X}")

    await ClockCycles(dut.clk, 200)
    dut._log.info("Pulse width sweep complete.")


def my_module_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "hdl" / "vco.sv", 
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