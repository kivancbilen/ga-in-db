
#include "cuda_runtime.h"
#include <cuda_runtime_api.h>
#include "device_launch_parameters.h"
#include <device_functions.h>
#include "vector"
#include <stdio.h>
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <algorithm>
#include "table.cpp"
#include "add.cu"

using namespace std;



int getSPcores(cudaDeviceProp devProp);
#define SIZE 1024 // FOR PARALEL GPU  SIZE HAS TO BE 2^n 1024
#define THREADS 4 // FOR PARALEL GPU  THREADS = SIZE / (BLOCKS * 2) 
#define BLOCKS 128//FOR PARALEL GPU  BLOCKS = SIZE / (THREADS * 2) 
string type = "DEVICE";  // USE "HOST" FOR CPU BUBBLE SORT, USE "DEVICE" FOR GPU BUBBLE SORT
int flag = 0;

__device__ long d_answer = 0;




__global__ void sortArray(int* a, int* size)
{
    int thread = blockIdx.x * blockDim.x + threadIdx.x;

    int i = thread;
    
    if (size[0] % 2 == 0) {
        if (i < size[0] - 1) {
            if (i % 2 == 0) {
                if (a[i] < a[i + 1]) {
                    int temp = a[i];
                    a[i] = a[i + 1];
                    a[i + 1] = temp;
                }
            }
        }
    }


    if (size[0] % 2 == 0) {
        if (i % 2 != 0) {
            if (a[i] < a[i + 1]) {
                int temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
            }
        }
    }
    else {
        if (i < size[0] - 1 && i % 2 != 0) {
            if (a[i] < a[i + 1]) {
                int temp = a[i];
                a[i] = a[i + 1];
                a[i + 1] = temp;
            }
        }

    }
}


int main() {
    cout << "Hello World!\n";
    string command;
    vector<table*> tables;
    bool run = true;
    while (run) {
        cout << "Enter command: ";
        cin >> command;
        if (command == "create") {
            vector<string> fields(3);
            fields[0] = "id";
            fields[1] = "name";
            fields[2] = "surname";
            table* asd = new table("table1", fields);
            tables.push_back(asd);
        }

        if (command == "insert")
        {
            string flds;
            string vals;
            cout << "Enter fields comma seperated:";
            cin >> flds;
            cout << "Enter values comma seperated:";
            cin >> vals;
            tables[0]->insert(flds, vals);
        }

        if (command == "insert2")
        {

            tables[0]->insert50000();
        }

        if (command == "select") {
            vector<char> res = tables[0]->read();
            int size = res.size();
            for (size_t i = 0; i < size; i++)
            {
                cout << res[i];
            }
        }

        if (command == "search") {
            tables[0]->search("", "");
        }

        if (command == "sort") {
            tables[0]->sort();
        }

        if (command == "exit") {
            run = false;
        }

        if (command == "update")
        {
            string value;
            cout << "enter value:";
            cin >> value;
            tables[0]->update(value);
        }

    }
}

int main0()
{
    const int arraySize = 5;
    const int a[arraySize] = { 1, 2, 3, 4, 5 };
    const int b[arraySize] = { 10, 20, 30, 40, 50 };
    int c[arraySize] = { 0 };
    int result[1] = { -1 };

    // Add vectors in parallel.
    cudaError_t cudaStatus = addWithCuda(c, a, b, arraySize, result);
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "addWithCuda failed!");
        return 1;
    }

    printf("{1,2,3,4,5} + {10,20,30,40,50} = {%d,%d,%d,%d,%d}\n",
        c[0], c[1], c[2], c[3], c[4]);

    printf("{%d}\n",
        result[0]);
    // cudaDeviceReset must be called before exiting in order for profiling and
    // tracing tools such as Nsight and Visual Profiler to show complete traces.
    cudaStatus = cudaDeviceReset();
    if (cudaStatus != cudaSuccess) {
        fprintf(stderr, "cudaDeviceReset failed!");
        return 1;
    }

    return 0;
}







int getSPcores(cudaDeviceProp devProp)
{
    int cores = 0;
    int mp = devProp.multiProcessorCount;
    switch (devProp.major) {
    case 2: // Fermi
        if (devProp.minor == 1) cores = mp * 48;
        else cores = mp * 32;
        break;
    case 3: // Kepler
        cores = mp * 192;
        break;
    case 5: // Maxwell
        cores = mp * 128;
        break;
    case 6: // Pascal
        if ((devProp.minor == 1) || (devProp.minor == 2)) cores = mp * 128;
        else if (devProp.minor == 0) cores = mp * 64;
        else printf("Unknown device type\n");
        break;
    case 7: // Volta and Turing
        if ((devProp.minor == 0) || (devProp.minor == 5)) cores = mp * 64;
        else printf("Unknown device type\n");
        break;
    case 8: // Ampere
        if (devProp.minor == 0) cores = mp * 64;
        else if (devProp.minor == 6) cores = mp * 128;
        else printf("Unknown device type\n");
        break;
    default:
        printf("Unknown device type\n");
        break;
    }
    return cores;
}