// CORDIC implementation inspired by: https://github.com/nkkav/kvcordic/blob/master/sw/cordic.c
#include "uart.h"
#include "print.h"
#include "config.h"
#include "gpio.h"
#include "util.h"

#define STUDENT_NAMES 0x20000000UL
#define CROCDIC_START 0x20000080UL
#define CROCDIC_OPERATION 0x20000084UL
#define CROCDIC_SOURCE_ARRAY_ADDRESS 0x20000088UL
#define CROCDIC_NR_OF_ELEMENTS 0x2000008CUL
#define CROCDIC_DESTINATION_ARRAY_ADDRESS 0x20000090UL
#define CROCDIC_DONE 0x20000094UL

typedef short int integer; // work with 16-bit numbers

int main(int argc, char **argv)
{
  uart_init();

  printf("%s\n", STUDENT_NAMES);
  
  uart_write_flush();

  return 0;

}