#include <stdint.h>

#define REG(address) (*(volatile uint32_t *)(address))
#define REQUIRE(condition,code) do { if (!(condition)) return code; } while (0)
static volatile uint32_t traps,cause,tval,expected;
extern void _exit(int) __attribute__((noreturn));

static void __attribute__((interrupt("machine"),aligned(4))) handler(void) {
    uint32_t epc;
    __asm__ volatile("csrr %0,mcause":"=r"(cause));
    __asm__ volatile("csrr %0,mtval":"=r"(tval));
    if (cause!=expected) _exit(100+(cause&31));
    if (cause==0x8000000b) REG(0x10000010)=0;
    else if (cause==0x80000003) REG(0x02000000)=0;
    else if (cause==0x80000007) {
        REG(0x02004004)=0xffffffff;
        REG(0x02004000)=0xffffffff;
    } else {
        __asm__ volatile("csrr %0,mepc":"=r"(epc));
        epc+=(*(volatile uint16_t *)epc&3)==3 ? 4 : 2;
        __asm__ volatile("csrw mepc,%0"::"r"(epc));
    }
    traps++;
}

__asm__(".pushsection .text.patch,\"ax\"\n.balign 4\n.option push\n.option norvc\n"
        ".global patch_function\npatch_function:\naddi a0,zero,1\nret\n.option pop\n.popsection");
extern int patch_function(void);

int main(void) {
    __asm__ volatile("csrw mtvec,%0"::"r"(handler));
    expected=2;
    __asm__ volatile(".word 0xffffffff" ::: "memory");
    REQUIRE(traps==1 && cause==2 && tval==0xffffffff,1);
    expected=11;
    __asm__ volatile("ecall" ::: "memory");
    REQUIRE(traps==2 && cause==11 && tval==0,2);

    uint32_t base,ignored;
    __asm__ volatile("mv %0,sp":"=r"(base));
    expected=4;
    __asm__ volatile("lw %0,1(%1)":"=r"(ignored):"r"(base):"memory");
    REQUIRE(traps==3 && cause==4 && tval==base+1,3);
    expected=6;
    __asm__ volatile("sw zero,1(%0)"::"r"(base):"memory");
    REQUIRE(traps==4 && cause==6 && tval==base+1,4);

    REG(0x10000100)=0x12345678;
    REQUIRE(REG(0x10000100)==0x12345678,5);
    *(volatile uint8_t *)0x10000101=0x3a;
    __asm__ volatile("fence iorw,iorw" ::: "memory");
    REQUIRE(REG(0x10000100)==0x12343a78,6);

    volatile uint32_t word=7;
    uint32_t old,success;
    __asm__ volatile("amoadd.w %0,%2,(%1)":"=r"(old):"r"(&word),"r"(5):"memory");
    REQUIRE(old==7 && word==12,7);
    __asm__ volatile("lr.w %0,(%2)\nsc.w %1,%3,(%2)":"=&r"(old),"=&r"(success):"r"(&word),"r"(19):"memory");
    REQUIRE(old==12 && success==0 && word==19,8);

    REQUIRE(patch_function()==1,9);
    *(volatile uint32_t *)(uintptr_t)patch_function=0x00200513;
    __asm__ volatile("fence.i" ::: "memory");
    REQUIRE(patch_function()==2,10);

    expected=0x8000000b;
    __asm__ volatile("csrw mie,%0\ncsrsi mstatus,8"::"r"(0x800):"memory");
    REG(0x10000014)=4096;
    __asm__ volatile("wfi" ::: "memory");
    REQUIRE(traps==5 && cause==0x8000000b,11);

    expected=0x80000003;
    __asm__ volatile("csrw mie,%0"::"r"(8):"memory");
    REG(0x02000000)=1;
    for (unsigned i=0;i<10000 && traps<6;i++) __asm__ volatile("nop");
    REQUIRE(traps==6 && cause==0x80000003,12);

    expected=0x80000007;
    __asm__ volatile("csrw mie,%0"::"r"(128):"memory");
    REG(0x02004004)=0xffffffff;
    REG(0x02004000)=REG(0x0200bff8)+4096;
    REG(0x02004004)=REG(0x0200bffc);
    for (unsigned i=0;i<10000 && traps<7;i++) __asm__ volatile("nop");
    REQUIRE(traps==7 && cause==0x80000007,13);
    __asm__ volatile("csrci mstatus,8" ::: "memory");
    #define ILLEGAL(encoding,code) do { \
        uint32_t before=traps; expected=2; \
        __asm__ volatile(".word " #encoding ::: "memory"); \
        REQUIRE(traps==before+1 && tval==encoding,code); \
    } while (0)
    ILLEGAL(0x00003203,14); ILLEGAL(0x00006203,15); ILLEGAL(0x00007203,16);
    ILLEGAL(0x00003023,17); ILLEGAL(0x00002063,18); ILLEGAL(0x00001067,19);
    ILLEGAL(0x02001013,20); ILLEGAL(0x02005013,21); ILLEGAL(0x04000033,22);
    ILLEGAL(0x30004073,23); ILLEGAL(0x302000f3,24); ILLEGAL(0x101020af,25);
    ILLEGAL(0x280020af,26); ILLEGAL(0x000030af,27);
    return 0;
}
