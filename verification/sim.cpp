#include "Vverification_top.h"
#include <verilated.h>
#include <algorithm>
#include <array>
#include <cstring>
#include <deque>
#include <elf.h>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <stdexcept>
#include <unordered_map>
#include <vector>

// Sparse, zero-initialized RAM; every accepted line read returns four consecutive beats.
class Memory {
    std::unordered_map<uint32_t, std::array<uint8_t, 4096>> pages;
public:
    uint8_t &byte(uint32_t address) { return pages[address >> 12][address & 4095]; }
    uint64_t read(uint32_t address) {
        uint64_t value = 0;
        for (unsigned i = 0; i < 8; ++i) value |= uint64_t(byte(address + i)) << (8*i);
        return value;
    }
    void write(uint32_t address, uint64_t value) {
        for (unsigned i = 0; i < 8; ++i) byte(address + i) = value >> (8*i);
    }
    uint32_t load(const char *path) {
        std::ifstream file(path, std::ios::binary);
        std::vector<char> data((std::istreambuf_iterator<char>(file)), {});
        if (data.size() < sizeof(Elf32_Ehdr)) throw std::runtime_error("missing/truncated ELF");
        const auto &header = *reinterpret_cast<const Elf32_Ehdr *>(data.data());
        if (memcmp(header.e_ident, ELFMAG, SELFMAG) || header.e_ident[EI_CLASS] != ELFCLASS32 ||
            header.e_ident[EI_DATA] != ELFDATA2LSB || header.e_machine != EM_RISCV ||
            header.e_entry != 0xaaaaa000) throw std::runtime_error("expected RV32 little-endian ELF at reset PC");
        auto range = [&](uint64_t offset, uint64_t size) {
            if (offset + size > data.size()) throw std::runtime_error("truncated ELF table");
        };
        range(header.e_phoff, uint64_t(header.e_phnum)*header.e_phentsize);
        for (unsigned i = 0; i < header.e_phnum; ++i) {
            const auto &p = *reinterpret_cast<const Elf32_Phdr *>(data.data()+header.e_phoff+i*header.e_phentsize);
            if (p.p_type != PT_LOAD) continue;
            range(p.p_offset, p.p_filesz);
            if (p.p_filesz > p.p_memsz || p.p_paddr < 0xaaaaa000 ||
                uint64_t(p.p_paddr)+p.p_memsz > 0xaeaaa000) throw std::runtime_error("ELF segment outside RAM");
            for (uint32_t j = 0; j < p.p_filesz; ++j) byte(p.p_paddr+j) = data[p.p_offset+j];
        }
        range(header.e_shoff, uint64_t(header.e_shnum)*header.e_shentsize);
        uint32_t tohost = 0;
        for (unsigned i = 0; i < header.e_shnum; ++i) {
            const auto &s = *reinterpret_cast<const Elf32_Shdr *>(data.data()+header.e_shoff+i*header.e_shentsize);
            if (s.sh_type != SHT_SYMTAB || s.sh_link >= header.e_shnum) continue;
            range(s.sh_offset,s.sh_size);
            const auto &strings = *reinterpret_cast<const Elf32_Shdr *>(data.data()+header.e_shoff+s.sh_link*header.e_shentsize);
            range(strings.sh_offset,strings.sh_size);
            for (unsigned j = 0; j < s.sh_size/sizeof(Elf32_Sym); ++j) {
                const auto &symbol = *reinterpret_cast<const Elf32_Sym *>(data.data()+s.sh_offset+j*sizeof(Elf32_Sym));
                if (symbol.st_name < strings.sh_size && !strcmp(data.data()+strings.sh_offset+symbol.st_name,"tohost"))
                    tohost = symbol.st_value;
            }
        }
        if (!tohost) throw std::runtime_error("ELF has no tohost completion symbol");
        return tohost;
    }
};

int main(int argc, char **argv) try {
    if (argc < 2) throw std::runtime_error("usage: simulator ELF [cycle-limit] [trace.csv] [memory-latency]");
    VerilatedContext context;
    context.commandArgs(argc,argv);
    Vverification_top dut(&context);
    Memory memory;
    const uint32_t tohost = memory.load(argv[1]);
    const uint64_t limit = argc > 2 ? std::stoull(argv[2]) : 100000000;
    const unsigned latency = argc > 4 ? std::stoul(argv[4]) : 8;
    std::ofstream trace;
    if (argc > 3 && strcmp(argv[3],"-")) trace.open(argv[3]);
    struct Read { uint32_t address; uint64_t ready; unsigned beat; };
    std::deque<Read> reads;
    std::map<uint32_t,uint32_t> device;
    unsigned write_beat = 0;
    uint64_t next_order = 0, sleep_cycles = 0, wake_at = UINT64_MAX;
    uint64_t started = 0, measured_cycles = 0, measured_retired = 0, start_order = 0;
    bool reply = false;
    uint32_t reply_data = 0;
    dut.clk=0; dut.rst=1; dut.irq_ext=0;
    dut.bmem_ready=0; dut.bmem_rvalid=0;
    dut.mmio_req_ready=0; dut.mmio_resp_valid=0; dut.mmio_resp_error=0;
    for (uint64_t cycle = 0; cycle < limit; ++cycle) {
        dut.clk=0;
        dut.rst=cycle < 4;
        dut.irq_ext=(cycle >= wake_at) || (device[0x10000010] & 1);
        dut.bmem_ready=!dut.rst && reads.size()<16;
        dut.bmem_rvalid=!reads.empty() && reads.front().ready<=cycle;
        if (dut.bmem_rvalid) {
            const auto &r=reads.front();
            dut.bmem_raddr=r.address;
            dut.bmem_rdata=memory.read(r.address+8*r.beat);
        }
        dut.mmio_req_ready=!dut.rst && !reply;
        dut.mmio_resp_valid=reply; dut.mmio_resp_rdata=reply_data;
        dut.eval();
        bool mmio=dut.mmio_req_valid && dut.mmio_req_ready;
        uint32_t mmio_address=dut.mmio_addr, mmio_data=dut.mmio_wdata;
        unsigned mmio_mask=dut.mmio_wmask;
        bool read=dut.bmem_read && dut.bmem_ready;
        bool write=dut.bmem_write && dut.bmem_ready;
        uint32_t address=dut.bmem_addr;
        uint64_t data=dut.bmem_wdata;
        int exit_code=-1;
        if (!dut.rst) {
            sleep_cycles+=dut.sleeping;
            std::vector<unsigned> lanes;
            for (unsigned lane=0;lane<2;++lane) if (dut.retired & (1<<lane)) lanes.push_back(lane);
            auto order=[&](unsigned lane) { return uint64_t(dut.orders[2*lane]) | uint64_t(dut.orders[2*lane+1])<<32; };
            std::sort(lanes.begin(),lanes.end(),[&](unsigned a,unsigned b){return order(a)<order(b);});
            for (unsigned lane:lanes) {
                if (order(lane)!=next_order++) throw std::runtime_error("retirement order discontinuity");
                auto word=[](uint64_t value,unsigned lane) { return uint32_t(value>>(32*lane)); };
                unsigned rd=(dut.destinations>>(5*lane))&31;
                unsigned mask=(dut.store_masks>>(4*lane))&15;
                if (word(dut.instructions,lane)==0x00102013) { started=cycle;start_order=order(lane); }
                if (word(dut.instructions,lane)==0x00202013 && started) {
                    measured_cycles=cycle-started;measured_retired=order(lane)-start_order-1;
                }
                if (trace) trace<<std::hex<<word(dut.pcs,lane)<<','<<word(dut.instructions,lane)<<','<<rd<<','
                    <<(rd ? word(dut.results,lane) : 0)<<','<<word(dut.next_pcs,lane)<<','
                    <<word(dut.memory_addresses,lane)<<','<<mask<<','<<word(dut.memory_data,lane)<<'\n';
                if (mask==15 && word(dut.memory_addresses,lane)==tohost && (word(dut.memory_data,lane)&1))
                    exit_code=word(dut.memory_data,lane)>>1;
            }
        }
        dut.clk=1; context.timeInc(1); dut.eval();
        if (dut.bmem_rvalid && ++reads.front().beat==4) reads.pop_front();
        if (read) reads.push_back({address&~31u,cycle+std::max(1u,latency),0});
        if (write) { memory.write((address&~31u)+8*write_beat,data); write_beat=(write_beat+1)%4; }
        reply=false;
        if (mmio) {
            for (unsigned i=0;i<4;++i) if (mmio_mask&(1<<i)) {
                device[mmio_address]=(device[mmio_address]&~(255u<<(8*i))) | (mmio_data&(255u<<(8*i)));
                if (mmio_address==0x10000000 && i==0) std::cout.put(mmio_data&255);
            }
            if (mmio_address==0x10000014 && mmio_mask) wake_at=cycle+mmio_data;
            if (mmio_address==0x10000018 && mmio_mask && (mmio_data&0x800)) {
                device[0x10000010]=mmio_data>>31;
                if (!(mmio_data>>31)) wake_at=UINT64_MAX;
            }
            if (mmio_address==0x10000010 && mmio_mask && !mmio_data) wake_at=UINT64_MAX;
            reply_data=mmio_address==0x10000004 ? 0x6000 : device[mmio_address];
            reply=true;
        }
        if (exit_code>=0) {
            std::cout<<"\nRESULT {\"exit_code\":"<<exit_code<<",\"cycles\":"<<cycle
                <<",\"retired\":"<<next_order<<",\"sleep_cycles\":"<<sleep_cycles
                <<",\"measured_cycles\":"<<measured_cycles<<",\"measured_retired\":"<<measured_retired<<"}\n";
            dut.final();
            return exit_code ? 1 : 0;
        }
        if (context.gotError() || context.gotFinish()) throw std::runtime_error("unexpected simulation termination");
    }
    std::cerr << "STALL pc=" << std::hex << dut.pcs << " inst=" << dut.instructions
              << " frontend=" << dut.debug_front_pc << " state=" << dut.debug_state
              << " rob_ptrs=" << dut.debug_rob_ptrs << " load_block=" << dut.debug_load_block << " retired=" << std::dec << next_order << '\n';
    std::cerr << "LOAD ADDRESSES";
    for (unsigned i=0; i<4; ++i) std::cerr << ' ' << std::hex << dut.debug_load_addresses[i];
    std::cerr << '\n';
    throw std::runtime_error("cycle limit exceeded");
} catch (const std::exception &error) {
    std::cerr<<"SIMULATION FAILED: "<<error.what()<<'\n';
    return 1;
}
