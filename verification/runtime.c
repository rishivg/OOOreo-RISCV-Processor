#include <stddef.h>
#include <stdint.h>
#include <sys/stat.h>
#include <sys/types.h>

void initialise_board(void) {}
void start_trigger(void) { __asm__ volatile("slti x0,x0,1" ::: "memory"); }
void stop_trigger(void) { __asm__ volatile("slti x0,x0,2" ::: "memory"); }
int uart_send_char(char c) { *(volatile unsigned char *)0x10000000=c; return c; }
int _write(int fd,const void *data,size_t length) {
    (void)fd;
    for (size_t i=0;i<length;++i) uart_send_char(((const char *)data)[i]);
    return length;
}
void *_sbrk(ptrdiff_t increment) {
    extern char __heap_start[],__stack_top[];
    static char *end;
    if (!end) end=__heap_start;
    char *old=end;
    if (increment<0 || end+increment>__stack_top-0x100000) return (void *)-1;
    end+=increment;
    return old;
}
int _close(int fd) { (void)fd; return -1; }
int _fstat(int fd,struct stat *s) { (void)fd; s->st_mode=S_IFCHR; return 0; }
int _isatty(int fd) { (void)fd; return 1; }
int _lseek(int fd,int offset,int whence) { (void)fd; (void)offset; (void)whence; return 0; }
int _read(int fd,void *data,size_t n) { (void)fd; (void)data; (void)n; return 0; }
int _getpid(void) { return 1; }
int _kill(int pid,int signal) { (void)pid; (void)signal; return -1; }
