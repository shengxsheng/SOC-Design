#ifndef __FIR_H__
#define __FIR_H__

#define N 11

int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int inputbuffer[N];
//int inputsignal[N] = {1,2,3,4,5,6,7,8,9,10,11};
int x[64];
int y[64];
int expect[64]={0,-10,-29,-25,35,158,337,539,
732,915,1098,1281,1464,1647,1830,2013,
2196,2379,2562,2745,2928,3111,3294,3477,
3660,3843,4026,4209,4392,4575,4758,4941,
5124,5307,5490,5673,5856,6039,6222,6405,
6588,6771,6954,7137,7320,7503,7686,7869,
8052,8235,8418,8601,8784,8967,9150,9333,
9516,9699,9882,10065,10248,10431,10614,10797};
#endif
