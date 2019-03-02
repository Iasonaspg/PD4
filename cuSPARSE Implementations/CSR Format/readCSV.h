/**********************************************************************
 *
 * readCSV.c -- readCSV function for reading the input from
 *              a .csv file
 *
 * Michail Iason Pavlidis <michailpg@ece.auth.gr>
 * John Flionis <iflionis@auth.gr>
 *
 **********************************************************************/

#ifndef READ_CSV_H
#define READ_CSV_H

/* Struct for Sparse Matrix type in the Coordinate Format (CSR) */
typedef struct Sparse_Matrix_in_CSR_format {
   int   nnz;
   float* csrVal;
   int* csrRowPtr;
   int* csrColInd;
}csrFormat;

int readCSV(char* fName, csrFormat *A, int* N, int* M, int* nT_Mat, double* matlab_time);
int split_line_int(char* str, char* delim, int* args);
char *trim_space(char *in);
int findLines(char* fName);
void mulSparse(csrFormat* A, csrFormat* C, int N);
int findTrianglesCPU(csrFormat* A, csrFormat* C, int N);
double cpuSecond();
__global__ void filter(csrFormat A, csrFormat C, int* counter1, int* counter2);
__global__ void findTriangles(csrFormat A, csrFormat C, int* sum, int N);
__global__ void findTrianglesSum(csrFormat A, csrFormat C, int* totalSum, int* counter);


#define CHECK(call) \
{                    \
    const cudaError_t error = call; \
    if (error != cudaSuccess){       \
        printf("Error: %s:%d, ", __FILE__, __LINE__);  \
        printf("code:%d, reason: %s\n", error, cudaGetErrorString(error)); \
        exit(1); \
    } \
} \

#endif /* READ_CSV_H */
