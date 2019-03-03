/******************************************************************************
 *
 * cuFindTriangles.cu -- The kernel that calculates the Number of triangles into
 *                       a graph given the CSR format of its Adjacency Matrix
 *
 * Reference: https://devblogs.nvidia.com/cuda-pro-tip-optimized-filtering-warp-aggregated-atomics/
 * 
 *
 * Michail Iason Pavlidis <michailpg@ece.auth.gr>
 * John Flionis <iflionis@auth.gr>
 *
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <cooperative_groups.h>
#include "readCSV.h"
#include "cuFindTriangles.h"

using namespace cooperative_groups;

#define warpSize 32
#define numberOfWarps 8

__global__
/* Kernel function that zeros the number of triangles variable */
void cuZeroVariable(int* nT) {

  (*nT) = 0;
}


__inline__ __device__
void blockReduceSum(int* temp) {

    auto g = coalesced_threads();
    int lane = g.thread_rank();

    // Each iteration halves the number of active threads
    // Each thread adds its partial sum[i] to sum[lane+i]
    #pragma unroll
    for (int i = g.size() / 2; i > 0; i /= 2)
    {
        if (lane < i) temp[lane] += temp[lane + i];
        g.sync(); // wait for all threads to load
    }
}


__inline__ __device__
void warpReduceSum(int* sum) {

  int lane = threadIdx.x % warpSize;
  int wid = threadIdx.x / warpSize;

  auto g = coalesced_threads();

  int val = g.size(); // warpReduceInc(g);     
  // Each warp performs partial reduction

  if ( g.thread_rank() == 0 )   atomicAdd( &sum[wid], val); 
  // Write reduced value to shared memory

}


__global__
/* Kernel function that finds the number of triangles formed in the graph */
void cuFindTriangles(csrFormat A, int N, int* nT) {

  static __shared__ int sum[numberOfWarps]; // Shared mem for warpSize partial sums

  int lane = threadIdx.x % warpSize;
  int wid = threadIdx.x / warpSize;

  // Each thread processes a different row
  int index = wid + blockIdx.x*numberOfWarps;
  int stride = numberOfWarps * gridDim.x;

  if ( wid==0 ) sum[lane] = 0;

  __syncthreads();

  // Iterate over rows
  for (int row = index; row < N; row += stride) {

      // Iterate over columns
      for (int j = A.csrRowPtr[row] + lane; j < A.csrRowPtr[row+1]; j += warpSize) {

          int col = A.csrColInd[j];
          // [row, col] = position of 1 horizontally

          if ( col>row ) {
          // OPTIMIZATION: Due to symmetry, nT of the upper half array is
          // equal to half the nT, thus additions are cut down to half ! 
            int beginPtr_csr_row = A.csrRowPtr[row];
            int beginPtr_csc_col = A.csrRowPtr[col];

              // Multiplication of A[:,col] * A[row,:]      
              for (int k = beginPtr_csc_col; k < A.csrRowPtr[col+1]; k++) {
                      
                  int csc_row = A.csrColInd[k];
                  // [csr_row, k] = position of 1 vertically

                  for (int l = beginPtr_csr_row; l < A.csrRowPtr[row+1]; l++) {
        
                      int csr_col = A.csrColInd[l];

                      if ( csc_row == csr_col )
                          // Warp reduction into sum[wid] 
                          warpReduceSum( sum );
                      else if ( csr_col > csc_row ) {
                      // OPTIMIZATION: when col>row no need to go further,
                      // continue to the next col, plus for further optimization
                      // keep track of the beginPtr_csr_row where the previous
                      // iteration stopped, so that no time is wasted in rechecking
                          beginPtr_csr_row = l;
                          break;
                      }
                  }
              }
          }
      }
  }

  __syncthreads();
  // Reduction within first warp onto sum,
  // sum[0] will hold the total sum of the block
  if ( wid==0 )   blockReduceSum( sum ); 
  __syncthreads();
  // Adding atomicly only the partial sums to the nT variable
  // Additions to global variable are now as many as the gridDim is 
  // ( aka numberOfBlocks times)
  if ( threadIdx.x == 0 )   atomicAdd( nT, sum[0]);
}

/*********************************************************
  ==============    2D threads & blocks    ===============
  int row_index = blockIdx.x * blockDim.x + threadIdx.x;
  int col_index = blockIdx.y * blockDim.y + threadIdx.y;
  int row_stride = blockDim.x * gridDim.x;
  int col_stride = blockDim.y * gridDim.y;
  for(int row = row_index; row < N; row += row_stride)
  {
    for(int col = col_index; col < N; col += col_stride)
  *********************************************************/