// CORDIC implementation inspired by: https://github.com/nkkav/kvcordic/blob/master/sw/cordic.c
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

#define ROTATION   0
#define VECTORING  1
#define CIRCULAR   0
#define LINEAR     1
#define HYPERBOLIC 2

typedef enum {
    SIN = 0,
    COS = 1,
    ATAN = 2,
    SQRT = 3,
    RECIPROCAL = 4,
    INVERSE_SQRT = 5
} operation_t;

typedef short int integer; // work with 16-bit numbers

//Cordic in 16 bit signed fixed point math
//Function is valid for arguments in range -pi/2 -- pi/2
//for values pi/2--pi: value = half_pi-(theta-half_pi) and similarly for values -pi---pi/2
//
// 1.0 = 16384
// 1/k = 0.6072529350088812561694
// pi = 3.1415926536897932384626
//Constants
#define MY_PI 3.1415926536897932384626
// Q2.14S
#define CORDIC_1K 9949
#define CORDIC_1KP 19783
#define HALF_PI 25735
// #define MUL 16384.000000
#define MUL 16384
#define CORDIC_NTAB 14

integer cordic_tab[3*CORDIC_NTAB] = {
  65535 /* NOT USED */, 8999, 4184, 2058, 1025, 512, 256, 128, 64, 32, 16, 8, 4, 2, /* HYPERBOLIC */
  16384, 8192, 4096, 2048, 1024, 512, 256, 128, 64, 32, 16, 8, 4, 2,                /* LINEAR */
  12867, 7596, 4013, 2037, 1022, 511, 255, 127, 63, 31, 15, 7, 3, 1                 /* CIRCULAR */
};
// for convergence in hyperbolic mode, steps 4 and 13 must be repeated
integer cordic_hyp_steps[] = {
//	1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28
	1, 2, 3, 4, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 13
};
integer gdirection; // {0: ROTATION, 1: VECTORING}
integer gmode; // {0: CIRCULAR, 1: LINEAR, 2: HYPERBOLIC}


// source array of values in Q2.14 format to be computed
integer source_array[62] = {4000, 4400, 4800, 5200, 5600, 6000, 6400, 6800, 7200, 7600, 8000, 8400, 8800, 9200, 9600, 10000, 10400, 10800, 11200, 11600, 12000, 12400, 12800, 13200, 13600, 14000, 14400, 14800, 15200, 15600, 16000, 16400, 16800, 17200, 17600, 18000, 18400, 18800, 19200, 19600, 20000, 20400, 20800, 21200, 21600, 22000, 22400, 22800, 23200, 23600, 24000, 24400, 24800, 25200, 25600, 26000, 26400, 26800, 27200, 27600, 28000, 28400};

// destination array of values in Q2.14 format
integer destination_array_SW[62];
integer destination_array_HW[62];


void cordic(integer direction, integer mode, integer xin, integer yin, integer zin, integer *xout, integer *yout, integer *zout)
{
  integer k, kk, d, x1, x2, y1, y2, z1, z2;
  integer x, y, z;
  integer kstart, kfinal, xbyk, ybyk, tabval;
  integer offset;

  x = xin;
  y = yin;
  z = zin;
  offset = ((mode == HYPERBOLIC) ? 0 : ((mode == LINEAR) ? 14 : 28));
  kfinal = ((mode != HYPERBOLIC) ? CORDIC_NTAB : CORDIC_NTAB+1);
  for (k = 0; k < kfinal; k++)
  {
    d = ((direction == ROTATION) ? ((z>=0) ? 0 : 1) : ((y<0) ? 0 : 1));
    kk = ((mode != HYPERBOLIC) ? k : cordic_hyp_steps[k]);
    xbyk = (x>>kk);
    ybyk = ((mode == HYPERBOLIC) ? -(y>>kk) : ((mode == LINEAR) ? 0 : (y>>kk)));
    tabval = cordic_tab[kk+offset];
    x1 = x - ybyk;
    x2 = x + ybyk;
    y1 = y + xbyk;
    y2 = y - xbyk;
    z1 = z - tabval;
    z2 = z + tabval;
    x = ((d == 0) ? x1 : x2);
    y = ((d == 0) ? y1 : y2);
    z = ((d == 0) ? z1 : z2);
  }  
  *xout = x;
  *yout = y;
  *zout = z;
}

int main(int argc, char **argv)
{
  uart_init();

  int length = sizeof(source_array) / sizeof(source_array[0]);

  // Timestamps
  uint32_t t0, t1, t2;


  integer x1, y1, z1, x2, y2, z2;

  // ROTATION, SIN
  printf("INVERSE SQRT\n");

  // RUN & BENCHMARK SOFTWARE IMPLEMENTATION
  t0 = get_mcycle();

  z1 = 0;
  for (int i = 0; i < length; i++) {
    gdirection = VECTORING; gmode = HYPERBOLIC; //SQRT
    x1 = source_array[i] + (1<<12);
    y1 = source_array[i] - (1<<12);
    cordic(gdirection, gmode, x1, y1, z1, &x2, &y2, &z2);

    gdirection = VECTORING; gmode = LINEAR; //RECIPROCAL
    y1 = (1<<14);
    x1 = (CORDIC_1KP*x2)/MUL;  // multiplication first and division second to preserve precision
    cordic(gdirection, gmode, x1, y1, z1, &x2, &y2, &z2);
    destination_array_SW[i] = z2;
  }

  // RUN & BENCHMARK HARDWARE IMPLEMENTATION
  t1 = get_mcycle();

  *(volatile uint32_t *)CROCDIC_OPERATION = SQRT;
  *(volatile uint32_t *)CROCDIC_SOURCE_ARRAY_ADDRESS = (uint32_t)source_array;
  *(volatile uint32_t *)CROCDIC_NR_OF_ELEMENTS = length;
  *(volatile uint32_t *)CROCDIC_DESTINATION_ARRAY_ADDRESS = (uint32_t)destination_array_HW;
 
  // start crocdic_top by writing something to the start_address
  *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

  // wait until crocdic_top sets the done signal
  while (*(volatile uint32_t *)CROCDIC_DONE == 0) 
  {
    //printf("STILL WAITING FOR CROCDIC_TOP TO COMPLETE\n"); // print statement should be removed in final performance test, as it adds a big delay
  }

  *(volatile uint32_t *)CROCDIC_OPERATION = RECIPROCAL;
  *(volatile uint32_t *)CROCDIC_SOURCE_ARRAY_ADDRESS = (uint32_t)destination_array_HW; //Use previous results as source array and overwrite with new results
  //*(volatile uint32_t *)CROCDIC_NR_OF_ELEMENTS = length;  // not needed as it is already being set before and stays the same
  //*(volatile uint32_t *)CROCDIC_DESTINATION_ARRAY_ADDRESS = (uint32_t)destination_array_HW;  // not needed as it is already being set before and stays the same
 
  // start crocdic_top by writing something to the start_address
  *(volatile uint32_t *)CROCDIC_START = 0xDEADBEEF;

  // wait until crocdic_top sets the done signal
  while (*(volatile uint32_t *)CROCDIC_DONE == 0) 
  {
    //printf("STILL WAITING FOR CROCDIC_TOP TO COMPLETE\n"); // print statement should be removed in final performance test, as it adds a big delay
  }


  t2 = get_mcycle();

  int mismatch_counter = 0;
  // Verify that software result is equal to hardware result and print error message otherwise
  for (int i = 0; i < length; i++) {
    // printf("INDEX: [%x] of RESULT LENGTH [%x]\n", i, length/2);
    if (destination_array_SW[i] != destination_array_HW[i]) {
      mismatch_counter++;
      printf("!!MISMATCH BETWEEN SW AND HW RESULT at index position 0x%x!!\n", i);

      // while(1);  // optional: use this so you definitely notice that something is wrong (halt CPU)
    }
  }
  printf("Total number of mismatches: 0x%x\n", mismatch_counter);

  // (can differ due to printf bug for large arrays)
  printf("SOFTWARE AND HARDWARE RESULTS\n");
  for (int i = 0; i < length; i++) {
    printf("SW:: Index: [0x%x], Input: 0x%x, Output: 0x%x\n", i, source_array[i], destination_array_SW[i]);
    printf("HW:: Index: [0x%x], Input: 0x%x, Output: 0x%x\n", i, source_array[i], destination_array_HW[i]);
  }

  // Report result summary
  printf("Software implementation took 0x%x cycles\n", t1-t0);
  printf("Hardware implementation took 0x%x cycles\n", t2-t1);

  uart_write_flush();

  return 0;

}