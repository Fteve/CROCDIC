#include "uart.h"
#include "print.h"
#include "config.h"
#include "gpio.h"
#include "util.h"

#define CROCDIC_START 0x20000004UL
#define CROCDIC_OPERATION 0x20000008UL
#define CROCDIC_SOURCE_ARRAY_ADDRESS 0x2000000CUL
#define CROCDIC_NR_OF_ELEMENTS 0x20000010UL
#define CROCDIC_DESTINATION_ARRAY_ADDRESS 0x20000014UL
#define CROCDIC_DONE 0x20000018UL

typedef enum {
    SIN = 0,
    COS = 1,
    ATAN = 2,
    SQRT = 3,
    RECIPROCAL = 4,
    INVERSE_SQRT = 5
} operation_t;

typedef short int integer;  // work with 16-bit numbers


integer source_array[8] =      {1, 2, 3, 4, 5, 6, 7, 8};
integer destination_array[8] = {9, 9, 9, 9, 9, 9, 9, 9};


int main() {
    uart_init();

    // write operation type, source array address, number of elements and destination array address into crocdic_top register file
    *(volatile uint32_t *)CROCDIC_OPERATION = SQRT;
    *(volatile uint32_t *)CROCDIC_SOURCE_ARRAY_ADDRESS = (uint32_t)source_array;
    *(volatile uint32_t *)CROCDIC_NR_OF_ELEMENTS = 7;
    *(volatile uint32_t *)CROCDIC_DESTINATION_ARRAY_ADDRESS = (uint32_t)destination_array;

    // start crocdic_top by writing something to the start_address
    *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

    // wait until crocdic_top sets the done signal
    while (*(volatile uint32_t *)CROCDIC_DONE == 0) 
    {
        printf("STILL WAITING FOR CROCDIC_TOP TO COMPLETE\n"); // print statement should be removed in final performance test, as it adds a big delay
    }

    printf("!!CROCDIC_TOP HAS COMPLETED!!\n");

    // CHECK: check elements in destination array (ONLY THE first 7 values should match the value in source array without modifications)
    for (int i = 0; i < 8; i++)
    {
        printf("Destination Array Element %x: %x\n", i, destination_array[i]);
    }


    uart_write_flush();
    return 0;
}
