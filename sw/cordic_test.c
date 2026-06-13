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

#define MUL 16384

typedef enum {
    SIN = 0,
    COS = 1,
    ATAN = 2,
    SQRT = 3,
    RECIPROCAL = 4,
    INVERSE_SQRT = 5
} operation_t;

typedef short int integer;  // work with 16-bit numbers

float angle_array[8] = {0, 0, 0, 1.16937, 0.34, 1.46, 0.82};
integer source_array[8];


integer destination_array[8] = {9, 9, 9, 9, 9, 9, 9, 9};


int main() {
    uart_init();

    int length = sizeof(source_array) / sizeof(source_array[0]);

    for (int i = 0; i < length; i++) source_array[i] = angle_array[i] * MUL; //convert angles into Q2.14 format

    // write operation type, source array address, number of elements and destination array address into crocdic_top register file
    *(volatile uint32_t *)CROCDIC_OPERATION = SIN;
    *(volatile uint32_t *)CROCDIC_SOURCE_ARRAY_ADDRESS = (uint32_t)source_array;
    *(volatile uint32_t *)CROCDIC_NR_OF_ELEMENTS = 6;
    *(volatile uint32_t *)CROCDIC_DESTINATION_ARRAY_ADDRESS = (uint32_t)destination_array;

    // start crocdic_top by writing something to the start_address
    *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

    // wait until crocdic_top sets the done signal
    while (*(volatile uint32_t *)CROCDIC_DONE == 0) 
    {
        printf("STILL WAITING FOR CROCDIC_TOP TO COMPLETE\n"); // print statement should be removed in final performance test, as it adds a big delay
    }

    printf("!!CROCDIC_TOP HAS COMPLETED!!\n");

    // CHECK: check elements in destination array (ONLY THE first 6 values should match the value in source array without modifications)
    for (int i = 0; i < 8; i++)
    {
        printf("Destination Array Element %x: %x\n", i, destination_array[i]);
    }


    uart_write_flush();
    return 0;
}
