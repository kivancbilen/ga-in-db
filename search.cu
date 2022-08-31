#include "cuda_runtime.h"
#include <cuda_runtime_api.h>
#include "device_launch_parameters.h"
#include <device_functions.h>


__device__ int dev_result1[10000];
__device__ int dev_count[1] = { 0 };

__global__ void searchNumber(const float* a, int* result)
{
    int thread = blockIdx.x * blockDim.x + threadIdx.x;

    int i = thread;

    int shift = 0;
    while (shift < 2) {
        int j = i + shift * 32768;
        if (a[j] == 65500) {
            result[0] = j;
        }
        shift++;
    }
}

__global__ void charcheck(char* a)
{
    int thread = blockIdx.x * blockDim.x + threadIdx.x;

    int i = thread;

    a[i] = 'a';
}

__global__ void resetVars()
{
    memset(dev_result1, 0, 10000 * sizeof(*dev_result1));
    memset(dev_count, 0, 1 * sizeof(*dev_count));

}

__global__ void searchField(char* a, int fieldfieldsize, char* value,  int rowsize, int fieldsize, int totalrow,char* result)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    //char val[9]= { ' ',' ','k', 'i', 'v', 'a', 'n', 'c','\0'};
    if (i < totalrow) {
        bool check = true;
        int start = i * 24 + 8;

        for (int j = 0; j < 8; j++) {
            if (value[j] != a[start]) {
                check = false;
                goto Exit;
            }
            start++;
        }

        if (check) {
            result[i] = 1;
        }
        Exit:

    }
}

class CudaTable {
public:             // Access specifier
    char* dev_rows;
    cudaStream_t stream;
    char* dev_chararray;
    char* dev_resultarray;
    char resultarray[1048576] = { ' ' };

    CudaTable() {
        cudaError_t cudaStatus;
        cudaStatus = cudaSetDevice(0);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
        }
        dev_rows = 0;
        cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking);
        
        
        cudaMalloc((void**)&dev_chararray, 8 * sizeof(char));
        cudaMallocHost((void**)&resultarray, 1048576 * sizeof(char));
        cudaMalloc((void**)&dev_resultarray, 1048576 * sizeof(char));
    }
    // Helper function for using CUDA to add vectors in parallel.
    int* searchWithCuda(const float* a, int* result, unsigned int size)
    {
        float* dev_a = 0;
        int* dev_result = 0;
        cudaError_t cudaStatus;

        // Choose which GPU to run on, change this on a multi-GPU system.
        cudaStatus = cudaSetDevice(0);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
            goto Error;
        }


        cudaStatus = cudaMalloc((void**)&dev_a, size * sizeof(int));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMalloc failed!");
            goto Error;
        }



        cudaStatus = cudaMalloc((void**)&dev_result, 1 * sizeof(int));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMalloc failed!");
            goto Error;
        }

        // Copy input vectors from host memory to GPU buffers.
        cudaStatus = cudaMemcpy(dev_a, a, size * sizeof(float), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }

        cudaStatus = cudaMemcpy(dev_result, result, 1 * sizeof(int), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }

        // Launch a kernel on the GPU with one thread for each element.
        searchNumber << <size / 256, 128 >> > (dev_a, dev_result);

        // Check for any errors launching the kernel
        cudaStatus = cudaGetLastError();
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
            goto Error;
        }

        // cudaDeviceSynchronize waits for the kernel to finish, and returns
        // any errors encountered during the launch.
        cudaStatus = cudaDeviceSynchronize();
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
            goto Error;
        }

        // Copy output vector from GPU buffer to host memory.
        cudaStatus = cudaMemcpy(result, dev_result, 1 * sizeof(int), cudaMemcpyDeviceToHost);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }

    Error:
        cudaFree(dev_a);
        cudaFree(dev_result);

        return result;
    }

    void updateGPU(char* a, unsigned int size,int start) {
        cudaError_t cudaStatus;
        cudaStatus = cudaMemcpy(dev_rows+start, a, size * sizeof(char), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }
    Error:
        fprintf(stderr, "%s", cudaStatus);
    }
    void insertToGPU(char* a, unsigned int size) {

        cudaError_t cudaStatus;

        // Choose which GPU to run on, change this on a multi-GPU system.
        cudaStatus = cudaSetDevice(0);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
            goto Error;
        }

        cudaStatus = cudaMalloc((void**)&dev_rows, size * sizeof(char));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMalloc failed!");
            goto Error;
        }

        cudaStatus = cudaMemcpy(dev_rows, a, size * sizeof(char), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }

        cudaStatus = cudaDeviceSynchronize();
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
            goto Error;
        }


    Error:
        fprintf(stderr, "cudaMemcpy failed!");

    }
    

    // Helper function for using CUDA to add vectors in parallel.
    char* searchStringWithCudaGPU(unsigned int size, unsigned int totalsize, int field, char* value, int rowsize, int fieldsize)
    {
        
        std::vector<int> count(1);
        
        cudaError_t cudaStatus;
        

        std::chrono::steady_clock::time_point begin_1 = std::chrono::steady_clock::now();

       /* cudaStatus = cudaMalloc((void**)&dev_chararray, 8 * sizeof(char));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMalloc failed!");
            goto Error;
        }*/

        
        std::chrono::steady_clock::time_point end_1 = std::chrono::steady_clock::now();
        std::cout << "Time difference malloc= " << std::chrono::duration_cast<std::chrono::microseconds>(end_1 - begin_1).count() << "[microseconds]" << std::endl;


       /* cudaStatus = cudaMalloc((void**)&dev_result, 1 * sizeof(int));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMalloc failed!");
            goto Error;
        }*/
        std::chrono::steady_clock::time_point begin = std::chrono::steady_clock::now();
        //memcpy(dev_chararray, value, 8 * sizeof(char));

        cudaStatus = cudaMemcpy(dev_chararray, value, 8 * sizeof(char), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }
        
        cudaStatus = cudaMemcpy(dev_resultarray, resultarray, 8 * sizeof(char), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }

        std::chrono::steady_clock::time_point end = std::chrono::steady_clock::now();
        std::cout << "Time difference = " << std::chrono::duration_cast<std::chrono::microseconds>(end - begin).count() << "[microseconds]" << std::endl;




        /*cudaStatus = cudaMemcpy(dev_result, result, 1 * sizeof(int), cudaMemcpyHostToDevice);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }*/
        std::chrono::steady_clock::time_point begin0 = std::chrono::steady_clock::now();
        searchField << <1024, 1024 >> > (dev_rows, field*fieldsize, dev_chararray, rowsize, fieldsize, totalsize/rowsize,dev_resultarray);
        std::chrono::steady_clock::time_point end0 = std::chrono::steady_clock::now();
        std::cout << "Time difference0 = " << std::chrono::duration_cast<std::chrono::microseconds>(end0 - begin0).count() << "[microseconds]" << std::endl;

        // Launch a kernel on the GPU with one thread for each element.

        // Check for any errors launching the kernel
        cudaStatus = cudaGetLastError();
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "addKernel launch failed: %s\n", cudaGetErrorString(cudaStatus));
            goto Error;
        }

        // cudaDeviceSynchronize waits for the kernel to finish, and returns
        // any errors encountered during the launch.
        std::chrono::steady_clock::time_point begin4 = std::chrono::steady_clock::now();
        
        cudaStatus = cudaDeviceSynchronize();
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaDeviceSynchronize returned error code %d after launching addKernel!\n", cudaStatus);
            goto Error;
        }
        std::chrono::steady_clock::time_point end4 = std::chrono::steady_clock::now();
        std::cout << "Time difference4 = " << std::chrono::duration_cast<std::chrono::microseconds>(end4 - begin4).count() << "[microseconds]" << std::endl;

        cudaStatus = cudaMemcpy(resultarray, dev_resultarray, 1024*1024 * sizeof(char), cudaMemcpyDeviceToHost);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }
        /*cudaStatus = cudaMemcpyFromSymbol(&(count[0]), dev_count, 1 * sizeof(int));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!\n", cudaStatus);
            goto Error;
        }


        cudaStatus = cudaMemcpyFromSymbol(&(result[0]), dev_result1, count[0] * sizeof(int));
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!\n", cudaStatus);
            goto Error;
        }*/
        

        //resetVars << <1,1 >> > ();
        
        

        // Copy output vector from GPU buffer to host memory.
        /*cudaStatus = cudaMemcpy(result, dev_result, 1 * sizeof(int), cudaMemcpyDeviceToHost);
        if (cudaStatus != cudaSuccess) {
            fprintf(stderr, "cudaMemcpy failed!");
            goto Error;
        }*/

    Error:
        
        return resultarray;
    }
};