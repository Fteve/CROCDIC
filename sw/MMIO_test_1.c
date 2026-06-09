#include "uart.h"
#include "print.h"
#include "config.h"
#include "gpio.h"
#include "util.h"

#define CROCDIC_START 0x20000004UL
#define CROCDIC_DONE 0x20000008UL

int main() {
    uart_init();

    // write something to start address
    *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

    // read DONE signal
    uint32_t done = *(volatile uint32_t *)CROCDIC_DONE;

    printf("!!Done signal is: %x\n", done);  // should return FFFFFFFF


    // read DONE signal again
    done = *(volatile uint32_t *)CROCDIC_DONE;

    printf("!!Done signal is: %x\n", done);  // should return 0 because start signal wasn't written to first


    // write something to start address
    *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

    // read DONE signal
    done = *(volatile uint32_t *)CROCDIC_DONE;

    printf("!!Done signal is: %x\n", done);  // should return FFFFFFFF



    uart_write_flush();
    return 0;
}
