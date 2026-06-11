#include <math.h>

#include "uart.h"
#include "print.h"
#include "config.h"
#include "gpio.h"
#include "util.h"

typedef short int integer; // work with 16-bit numbers

integer source_array[1] = {23};
// integer destination_array[3] = {0};


int main(int argc, char **argv)
{
    uart_init();

    // Timestamps
    uint32_t t0, t1;
    // Results
    integer result_sw_cos[1] = {0};
    integer result_sw_sin[1] = {0};
    // int length = sizeof(source_array) / sizeof(source_array[0]);

    t0 = get_mcycle();

    // result_sw_sin[1] = sin(source_array[1]);
    result_sw_cos[1] = cos(source_array[1]);

    // result_sw_sin[1] = source_array[1] + source_array[1];
    // result_sw_cos[1] = source_array[1] + source_array[1];

    t1 = get_mcycle();


    // printf("Software result:\n cos: %x\n sin: %x\n (0x%x cycles)\n", result_sw_cos, result_sw_sin, t1-t0);
    printf("Software result:\n cos: %x\n (0x%x cycles)\n", result_sw_cos, t1-t0);

    uart_write_flush();

    return 0;

}