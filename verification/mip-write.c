#include <stdint.h>
extern void _exit(int) __attribute__((noreturn));
static void __attribute__((interrupt("machine"),aligned(4))) trap(void) {
    uint32_t cause;
    __asm__ volatile("csrr %0,mcause":"=r"(cause));
    _exit(20+(cause&31));
}
int main(void) {
    uint32_t pending;
    __asm__ volatile("csrw mtvec,%0"::"r"(trap));
    *(volatile uint32_t *)0x10000010=1;
    __asm__ volatile("csrw mip,zero\ncsrr %0,mip":"=r"(pending)::"memory");
    return (pending&0x800) ? 0 : 1;
}
