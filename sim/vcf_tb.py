
import os
import math
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

    # default inputs
    dut.audio_in_vld.value = 0
    dut.audio_in.value = 0
    dut.cutoff.value = 0
    dut.resonance.value = 0
    dut.filter_mode.value = 0

    # wait a few clock cycles
    await ClockCycles(dut.clk, 3)

    # deassert reset on the falling edge for clean setup
    await FallingEdge(dut.clk)
    dut.rst.value = 0
    await RisingEdge(dut.clk)

    # allow time for the divider to calculate coefficients
    await ClockCycles(dut.clk, 100)


async def send_sample(dut, sample):
    """Send one audio sample and wait for valid output."""

    await FallingEdge(dut.clk)
    dut.audio_in.value = sample
    dut.audio_in_vld.value = 1

    await FallingEdge(dut.clk)
    dut.audio_in_vld.value = 0

    # wait for output (IDLE -> BP_LP -> HP -> OUT)
    for _ in range(10):
        await RisingEdge(dut.clk)
        await ReadOnly()

        if int(dut.audio_out_vld.value) == 1:
            return dut.audio_out.value.to_signed()

    assert False, "Timed out waiting for audio_out_vld"


@cocotb.test()
async def test_silence(dut):
    """Test 1: Zero input should give zero output."""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.filter_mode.value = 0  # low-pass

    output = await send_sample(dut, 0)

    assert output == 0, f"Expected 0, got {output}"


@cocotb.test()
async def test_highpass(dut):
    """Test 2: Nonzero input should give nonzero high-pass output."""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.filter_mode.value = 1  # high-pass

    output = await send_sample(dut, 100000)

    assert output != 0, "Expected nonzero high-pass output"


@cocotb.test()
async def test_invalid_mode(dut):
    """Test 3: Invalid filter mode should output zero."""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    dut.filter_mode.value = 3  # invalid mode

    output = await send_sample(dut, 100000)

    assert output == 0, f"Expected 0, got {output}"


async def setup_filter(dut, mode):
    """Start clock, reset, and configure filter."""
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await reset_dut(dut)

    await FallingEdge(dut.clk)
    dut.cutoff.value = 0xE000
    dut.resonance.value = 0
    dut.filter_mode.value = mode

    # Wait for coefficients to update
    await ClockCycles(dut.clk, 100)


async def send_mixed_sine(dut):
    """Send a mixture of low and high frequency sine waves."""

    for i in range(256):
        # Low frequency: 64 samples per period
        low = 200000 * math.sin(2 * math.pi * i / 64)

        # High frequency: 8 samples per period
        high = 100000 * math.sin(2 * math.pi * i / 8)

        sample = int(low + high)

        await send_sample(dut, sample)


async def send_step(dut):
    """Send a step waveform."""

    # Start at zero
    for i in range(40):
        await send_sample(dut, 0)

    # Step up
    for i in range(120):
        await send_sample(dut, 200000)

    # Step back down
    for i in range(40):
        await send_sample(dut, 0)


@cocotb.test()
async def test_lowpass_waveform(dut):
    """Test 4: Low-pass filtering of mixed sine waves."""

    await setup_filter(dut, mode=0)
    await send_mixed_sine(dut)


@cocotb.test()
async def test_highpass_waveform(dut):
    """Test 5: High-pass filtering of mixed sine waves."""

    await setup_filter(dut, mode=1)
    await send_mixed_sine(dut)


@cocotb.test()
async def test_bandpass_waveform(dut):
    """Test 6: Band-pass filtering of mixed sine waves."""

    await setup_filter(dut, mode=2)
    await send_mixed_sine(dut)


@cocotb.test()
async def test_lowpass_step(dut):
    """Test 7: Low-pass response to a step input."""

    await setup_filter(dut, mode=0)
    await send_step(dut)


@cocotb.test()
async def test_highpass_step(dut):
    """Test 8: High-pass response to a step input."""

    await setup_filter(dut, mode=1)
    await send_step(dut)


def my_module_runner():
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sources = [
        proj_path / "hdl" / "vcf.sv",
        proj_path / "hdl" / "div_gen_0_1.sv",
    ]

    build_test_args = ["-Wall"]

    # LUT file path
    lut_path = proj_path / "mem" / "g_tan_lut.mem"

    assert lut_path.is_file(), f"Missing tangent LUT: {lut_path}"

    parameters = {
        "FILE_NAME": f'"{lut_path.as_posix()}"',
        "SOUND_WIDTH": 24,
        "CTRL_WIDTH": 16,
        "LUT_DEPTH": 12,
    }

    runner = get_runner(sim)

    runner.build(
        sources=sources,
        hdl_toplevel="vcf",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )

    runner.test(
        hdl_toplevel="vcf",
        test_module=test_file,
        waves=True,
    )


if __name__ == "__main__":
    my_module_runner()
