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
#define cordic_1K 9949
#define cordic_1Kp 19783
#define half_pi 25735
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
// For ATAN, alternate 2 x-values, 2 corresponding y-values
integer source_array[18] =  {0, 0, 0, 500, 3500, 5500, 3500, 6000, 6500, 3500, 7000, 6000, 7000, 6500, 7000, 7000, 2500, 5000};
//integer source_array[450] = {0, 0, 0, 500, 0, 1000, 0, 1500, 0, 2000, 0, 2500, 0, 3000, 0, 3500, 0, 4000, 0, 4500, 0, 5000, 0, 5500, 0, 6000, 0, 6500, 0, 7000, 500, 0, 500, 500, 500, 1000, 500, 1500, 500, 2000, 500, 2500, 500, 3000, 500, 3500, 500, 4000, 500, 4500, 500, 5000, 500, 5500, 500, 6000, 500, 6500, 500, 7000, 1000, 0, 1000, 500, 1000, 1000, 1000, 1500, 1000, 2000, 1000, 2500, 1000, 3000, 1000, 3500, 1000, 4000, 1000, 4500, 1000, 5000, 1000, 5500, 1000, 6000, 1000, 6500, 1000, 7000, 1500, 0, 1500, 500, 1500, 1000, 1500, 1500, 1500, 2000, 1500, 2500, 1500, 3000, 1500, 3500, 1500, 4000, 1500, 4500, 1500, 5000, 1500, 5500, 1500, 6000, 1500, 6500, 1500, 7000, 2000, 0, 2000, 500, 2000, 1000, 2000, 1500, 2000, 2000, 2000, 2500, 2000, 3000, 2000, 3500, 2000, 4000, 2000, 4500, 2000, 5000, 2000, 5500, 2000, 6000, 2000, 6500, 2000, 7000, 2500, 0, 2500, 500, 2500, 1000, 2500, 1500, 2500, 2000, 2500, 2500, 2500, 3000, 2500, 3500, 2500, 4000, 2500, 4500, 2500, 5000, 2500, 5500, 2500, 6000, 2500, 6500, 2500, 7000, 3000, 0, 3000, 500, 3000, 1000, 3000, 1500, 3000, 2000, 3000, 2500, 3000, 3000, 3000, 3500, 3000, 4000, 3000, 4500, 3000, 5000, 3000, 5500, 3000, 6000, 3000, 6500, 3000, 7000, 3500, 0, 3500, 500, 3500, 1000, 3500, 1500, 3500, 2000, 3500, 2500, 3500, 3000, 3500, 3500, 3500, 4000, 3500, 4500, 3500, 5000, 3500, 5500, 3500, 6000, 3500, 6500, 3500, 7000, 4000, 0, 4000, 500, 4000, 1000, 4000, 1500, 4000, 2000, 4000, 2500, 4000, 3000, 4000, 3500, 4000, 4000, 4000, 4500, 4000, 5000, 4000, 5500, 4000, 6000, 4000, 6500, 4000, 7000, 4500, 0, 4500, 500, 4500, 1000, 4500, 1500, 4500, 2000, 4500, 2500, 4500, 3000, 4500, 3500, 4500, 4000, 4500, 4500, 4500, 5000, 4500, 5500, 4500, 6000, 4500, 6500, 4500, 7000, 5000, 0, 5000, 500, 5000, 1000, 5000, 1500, 5000, 2000, 5000, 2500, 5000, 3000, 5000, 3500, 5000, 4000, 5000, 4500, 5000, 5000, 5000, 5500, 5000, 6000, 5000, 6500, 5000, 7000, 5500, 0, 5500, 500, 5500, 1000, 5500, 1500, 5500, 2000, 5500, 2500, 5500, 3000, 5500, 3500, 5500, 4000, 5500, 4500, 5500, 5000, 5500, 5500, 5500, 6000, 5500, 6500, 5500, 7000, 6000, 0, 6000, 500, 6000, 1000, 6000, 1500, 6000, 2000, 6000, 2500, 6000, 3000, 6000, 3500, 6000, 4000, 6000, 4500, 6000, 5000, 6000, 5500, 6000, 6000, 6000, 6500, 6000, 7000, 6500, 0, 6500, 500, 6500, 1000, 6500, 1500, 6500, 2000, 6500, 2500, 6500, 3000, 6500, 3500, 6500, 4000, 6500, 4500, 6500, 5000, 6500, 5500, 6500, 6000, 6500, 6500, 6500, 7000, 7000, 0, 7000, 500, 7000, 1000, 7000, 1500, 7000, 2000, 7000, 2500, 7000, 3000, 7000, 3500, 7000, 4000, 7000, 4500, 7000, 5000, 7000, 5500, 7000, 6000, 7000, 6500, 7000, 7000};

integer destination_array_SW[9];
integer destination_array_HW[9];


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
  integer w1;

  // ROTATION, SIN
  printf("ATAN\n");

  // RUN & BENCHMARK SOFTWARE IMPLEMENTATION
  t0 = get_mcycle();

  gdirection = VECTORING; gmode = CIRCULAR;
  z1 = 0;

  for (int i = 0; i < length; i+=2) {
    x1 = source_array[i];
    y1 = source_array[i+1];
    cordic(gdirection, gmode, x1, y1, z1, &x2, &y2, &z2);
    destination_array_SW[i/2] = z2;
  }

  // RUN & BENCHMARK HARDWARE IMPLEMENTATION
  t1 = get_mcycle();

  *(volatile uint32_t *)CROCDIC_OPERATION = ATAN;
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

  t2 = get_mcycle();

  // Verify that software result is equal to hardware result and print error message otherwise
  for (int i = 0; i < length/2; i++) {
    printf("INDEX: [%x] of RESULT LENGTH [%x]\n", i, length/2);
    if (destination_array_SW[i] != destination_array_HW[i]) {
      printf("!!MISMATCH BETWEEN SW AND HW RESULT at index position 0x%x!!\n", i);

      // while(1);  // optional: use this so you definitely notice that something is wrong (halt CPU)
    }
  }

  // printf("SOFTWARE RESULTS\n");
  // for (int i = 0; i < length; i+=2) {
  //   printf("SW:: Inputs: 0x%x, 0x%x, Output: 0x%x\n", source_array[i], source_array[i+1], destination_array_SW[i/2]);
  // }

  // printf("HARDWARE RESULTS\n");
  // for (int i = 0; i < length; i+=2) {
  //   printf("HW:: Inputs: 0x%x, 0x%x, Output: 0x%x\n", source_array[i], source_array[i+1], destination_array_HW[i/2]);
  // }

  printf("SOFTWARE AND HARDWARE RESULTS\n");
  for (int i = 0; i < length/2; i++) {
    printf("SW:: Index: [0x%x], Inputs: 0x%x, 0x%x, Output: 0x%x\n", i, source_array[2*i], source_array[2*i+1], destination_array_SW[i]);
    printf("HW:: Index: [0x%x], Inputs: 0x%x, 0x%x, Output: 0x%x\n", i, source_array[2*i], source_array[2*i+1], destination_array_HW[i]);
  }

  printf("Software implementation took 0x%x cycles\n", t1-t0);
  printf("Hardware implementation took 0x%x cycles\n", t2-t1);
  
  uart_write_flush();

  return 0;

}