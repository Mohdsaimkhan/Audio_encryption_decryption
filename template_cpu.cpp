#include <stdio.h>
/*
 * Copyright 1993-2015 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

////////////////////////////////////////////////////////////////////////////////
#include "common.h"

////////////////////////////////////////////////////////////////////////////////
//! Compute reference data set
//! Each element is multiplied with the number of threads / array length
//! @param nsteps     nombre de pas de calcul
//! @param outpi      output of the computed value
////////////////////////////////////////////////////////////////////////////////
double computeGold(const unsigned int nsteps)
{
    long i;
    double step, sum_ref = 0.0;
    step = (1.0)/((double)nsteps);

    for (i = 0; i < nsteps; ++i) {
      double x = ((double)i+0.5)*step;
      sum_ref += 1.0 / (1.0 + x * x);
    }

    return (4.0 * step * sum_ref) ;

}

unsigned int nextPow2(unsigned int n) 
{ 
    unsigned int p = 1; 
    if (n && !(n & (n - 1))) 
        return n; 
  
    while (p < n)  
        p <<= 1; 
      
    return p; 
} 
