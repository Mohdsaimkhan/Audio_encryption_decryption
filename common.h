#pragma once

#define DTYPE float
#define FULL_MASK 0xffffffff

extern "C"
double computeGold(const unsigned int nsteps);

extern "C"
unsigned int nextPow2(unsigned int n);
