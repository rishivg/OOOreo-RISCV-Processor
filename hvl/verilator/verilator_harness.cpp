#include <algorithm>
#include <iostream>
#include <sstream>
#include <stdint.h>
#include <stdlib.h>
#include <stdexcept>

#include "Vtop_tb.h"
#include <verilated.h>
#if VM_TRACE
#include <verilated_vcd_c.h>
#endif

typedef Vtop_tb dut_t;

VerilatedContext* contextp;
dut_t* dut;
uint64_t clk_half_period = 0;
uint64_t cycle = 0;

#if VM_TRACE
// Trace only the requested cycle window; normal builds omit this code.
VerilatedVcdC* tfp = nullptr;
uint64_t dump_start = 0, dump_end = 0;
#endif

void tick(dut_t* dut) {
    contextp->timeInc(clk_half_period);
    dut->clk ^= 1;
    dut->eval();
    if (dut->clk == 1) cycle++;            // count rising edges
#if VM_TRACE
    if (tfp && cycle >= dump_start && cycle < dump_end) {
        tfp->dump((uint64_t)contextp->time());
    }
#endif
}

void tickn(dut_t* dut, int cycles) {
    for (int i = 0; i < cycles * 2; i++) {
        tick(dut);
    }
}

uint64_t get_int_plusarg(std::string arg) {
    std::string s(contextp->commandArgsPlusMatch(arg.c_str()));
    std::replace(s.begin(), s.end(), '=', ' ');
    std::stringstream ss(s);
    std::string p;
    uint64_t retval = 0;
    if (!(ss >> p >> retval)) throw std::invalid_argument(arg);
    return retval;
}

int main(int argc, char** argv) {
    contextp = new VerilatedContext;

    contextp->traceEverOn(true);
    contextp->commandArgs(argc, argv);
    contextp->fatalOnError(false);

    try {
        clk_half_period = get_int_plusarg("OOOREO_CLOCK_PERIOD_PS") / 2;
        if (!clk_half_period) throw std::invalid_argument("zero clock period");
    } catch (const std::exception& e) {
        std::cerr << "TB Error: Invalid command line arg" << std::endl;
        return 1;
    }

    dut = new dut_t;

#if VM_TRACE
    if (!std::string(contextp->commandArgsPlusMatch("DUMP_VCD")).empty()) {
        std::string ss(contextp->commandArgsPlusMatch("DUMP_START_CYC"));
        std::string sl(contextp->commandArgsPlusMatch("DUMP_LEN_CYC"));
        dump_start = ss.empty() ? 50000 : get_int_plusarg("DUMP_START_CYC");
        uint64_t len = sl.empty() ? 10000 : get_int_plusarg("DUMP_LEN_CYC");
        dump_end = dump_start + len;
        tfp = new VerilatedVcdC;
        dut->trace(tfp, 99);
        tfp->open("sim_power.vcd");
        std::cerr << "VCD: dumping cycles [" << dump_start << ", " << dump_end << ")\n";
    }
#endif

    dut->clk = 1;
    dut->rst = 1;

    tickn(dut, 2);

    dut->rst = 0;

    while (!contextp->gotFinish()) {
        tickn(dut, 1);
    }

#if VM_TRACE
    if (tfp) { tfp->close(); tfp = nullptr; }
#endif
    dut->final();
    return contextp->gotError() ? EXIT_FAILURE : 0;
}
