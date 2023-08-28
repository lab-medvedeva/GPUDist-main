#include <time.h>
#include <iostream>
#include <fstream>
#include <R.h>

#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPUassert: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}

__global__ void Rkendall_gpu_atomic(const double* col1, const double* col2, const int n, const int m, unsigned long long* R){
  int row1 = blockIdx.y * blockDim.y + threadIdx.y;
  int row2 = blockIdx.x * blockDim.x + threadIdx.x;
  if (row1 < row2 && row2 < n){
    if ((col1[row1] - col1[row2]) * (col2[row1] - col2[row2]) < 0){
      atomicAdd(R, 1);
    }
  }
}

__global__ void Rkendall_gpu_atomic_float(float* array, const int n, const int m, unsigned int* result) {
  
  int row1 = blockIdx.y * blockDim.y + threadIdx.y;
  int row2 = blockIdx.x * blockDim.x + threadIdx.x;


  for (int col1_num = 0; col1_num < m; ++col1_num) {
      for (int col2_num = col1_num + 1; col2_num < m; ++col2_num) {
          float* col1 = array + n * col1_num;
          float* col2 = array + n * col2_num;

          if (row1 < row2 && row2 < n){
            if ((col1[row1] - col1[row2]) * (col2[row1] - col2[row2]) < 0){
              atomicAdd(result + col1_num * m + col2_num, 1);
              atomicAdd(result + col2_num * m + col1_num, 1);
            }
          }
      }
  }
}


__global__ void Reuclidean_gpu_atomic_float(float* array, const int n, const int m, unsigned int* result) {
  
  int row = blockIdx.x * blockDim.x + threadIdx.x;

  for (int col1_num = 0; col1_num < m; ++col1_num) {
      for (int col2_num = col1_num + 1; col2_num < m; ++col2_num) {
          float* col1 = array + n * col1_num;
          float* col2 = array + n * col2_num;

          if (row < n) {
            float diff = col1[row] - col2[row];
            diff = diff * diff;
            atomicAdd(result + col1_num * m + col2_num, diff);
            atomicAdd(result + col2_num * m + col1_num, diff);

          }
      }
  }
}

__global__ void Rkendall_gpu_atomic_float_different_blocks(float* array, float* array2, const int n, const int m, const int m_b, unsigned int* result) {
  
  int row1 = blockIdx.y * blockDim.y + threadIdx.y;
  int row2 = blockIdx.x * blockDim.x + threadIdx.x;


  for (int col1_num = 0; col1_num < m; ++col1_num) {
      for (int col2_num = 0; col2_num < m_b; ++col2_num) {
          float* col1 = array + n * col1_num;
          float* col2 = array2 + n * col2_num;

          if (row1 < row2 && row2 < n){
            if ((col1[row1] - col1[row2]) * (col2[row1] - col2[row2]) < 0){
              atomicAdd(result + col2_num * m + col1_num, 1);
            }
          }
      }
  }
}

__global__ void Reuclidean_gpu_atomic_float_different_blocks(float* array, float* array2, const int n, const int m, const int m_b, unsigned int* result) {
  
  int row = blockIdx.x * blockDim.x + threadIdx.x;


  for (int col1_num = 0; col1_num < m; ++col1_num) {
      for (int col2_num = 0; col2_num < m_b; ++col2_num) {
          float* col1 = array + n * col1_num;
          float* col2 = array2 + n * col2_num;

          if (row < n) {
            float diff = col1[row] - col2[row];
            diff = diff * diff;
            //atomicAdd(result + col1_num * m + col2_num, diff);
            atomicAdd(result + col2_num * m + col1_num, diff);

          }
      }
  }
}

__global__ void RpearsonCorr_gpu_atomic_float_same_block(
  float* array,
  const int n, const int m,
  float* scalar_product,
  float* x_norm,
  float* y_norm
) {
  int row = blockIdx.x * blockDim.x + threadIdx.x;
  
  for (int col1_num = 0; col1_num < m; ++col1_num) {
      for (int col2_num = col1_num+1; col2_num < m; ++col2_num) {
          float* col1 = array + n * col1_num;
          float* col2 = array + n * col2_num;

          if (row < n) {
            float diff = col1[row] * col2[row];
            atomicAdd(scalar_product + col1_num * m + col2_num, diff);
            atomicAdd(scalar_product + col2_num * m + col1_num, diff);

            float x_element_norm = col1[row] * col1[row];
            float y_element_norm = col2[row] * col2[row];

            atomicAdd(x_norm + col1_num * m + col2_num, x_element_norm);
            atomicAdd(x_norm + col2_num * m + col1_num, x_element_norm);
            atomicAdd(y_norm + col1_num * m + col2_num, y_element_norm);
            atomicAdd(y_norm + col2_num * m + col1_num, y_element_norm);
	
          }
      }
  }
}

__global__ void RpearsonCorr_gpu_atomic_float_different_blocks(float* array, float* array2, const int n, const int m, const int m_b, float* scalar_prod,float *x_norm, float* y_norm ){
    int row = blockIdx.x*blockDim.x +threadIdx.x;
    for (int col1_num=0;col1_num<m;++col1_num){
	for(int col2_num=0;col2_num<m_b;++col2_num){
		float* col1 = array + n * col1_num;
		float* col2 = array2 + n * col2_num;
		if(row<n) {
				float num = (col1[row] * col2[row]);
				float sum1 = (col1[row] * col1[row]);
				float sum2 = (col2[row] * col2[row]);
				//if(dist==1){}
				atomicAdd(scalar_prod+col1_num*m_b+col2_num,num);
				atomicAdd(x_norm+col1_num*m_b+col2_num,sum1);
				atomicAdd(y_norm+col1_num*m_b+col2_num,sum2);
				//atomicAdd(scalar_prod+col2_num*m+col1_num,num);
				//atomicAdd(x_norm+col2_num*m+col1_num,sum1);
				//atomicAdd(y_norm+col2_num*m+col1_num,sum2);
				//!debug if(threadIdx.x==0){printf("val1=%4.2f, val2=%4.2f, num=%4.2f, sum1=%4.2f, sum2=%4.2f, \n", col1[row],col2[row],num,sum1,sum2);}
			}
		}
	}
}

__global__ void RpearsonChi_gpu_atomic_float_different_blocks(float* array, float* array2, const int n, const int m, const int m_b, unsigned int* result){
  //int i,j,k;
  //int row1 = blockIdx.y * blockDim.y + threadIdx.y;
	//int row2 = blockIdx.x* blockDim.x + threadIdx.x;
  float epsilon = 0.01;
  int row = blockIdx.x * blockDim.x + threadIdx.x;


  for (int col1_num = 0; col1_num < m; ++col1_num) {
    for (int col2_num = 0; col2_num < m_b; ++col2_num) {
      float* col1 = array + n * col1_num;
      float* col2 = array2 + n * col2_num;
      if (row < m) {
        if(col2[row]==0.0){
          
          float diff = col1[row] - col2[row];
          diff = diff * diff;
          diff = diff/epsilon;
          //atomicAdd(result + col1_num * m + col2_num, diff);
          atomicAdd(result + col2_num * m + col1_num, diff);
        } else {
          float diff = col1[row] - col2[row];
          diff = diff * diff;
          diff = diff/col2[row];
          //atomicAdd(result + col1_num * m + col2_num, diff);
          atomicAdd(result + col2_num * m + col1_num, diff);
        }
      }
    }
  }
}

extern "C" bool check_gpu() {
    cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, 0);
    cudaEvent_t start;
    cudaEventCreate(&start);
    cudaEventRecord(start);
    cudaEventSynchronize(start);
    return true;
}

//' Driver Function for calculation of Kendall matrix for same block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Kendall_distance_same_block(double* a, double * b /* not used */, double* c, int* n, int* m, int* m_b){

  clock_t start_1, end;
  cudaEvent_t start, stop1, stop2, stop3;
  double cpu_time_used;
  start_1 = clock();

  float milliseconds = 0.0f;
  int array_size = *n * *m;

  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }
  end = clock();
  cpu_time_used = ((double) (end - start_1)) / CLOCKS_PER_SEC * 1000.0;
  Rprintf("%lf create array time \n", cpu_time_used);

  //cudaEventCreate(&start);
  //cudaEventCreate(&stop1);
  //cudaEventCreate(&stop2);
  //cudaEventCreate(&stop3);
  //cudaEventRecord(start);
  
  
  float* d_array;

  cudaMalloc(&d_array, array_size * sizeof(float));
  end = clock();

  cpu_time_used = ((double) (end - start_1)) / CLOCKS_PER_SEC * 1000.0;
  Rprintf("%lf create event and record \n", cpu_time_used);

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);
  //cudaEventRecord(stop1);
  //cudaEventSynchronize(stop1);
  end = clock();
  cpu_time_used = ((double) (end - start_1)) / CLOCKS_PER_SEC * 1000;
  Rprintf("%lf stop1 time \n", cpu_time_used);
  //cudaEventElapsedTime(&milliseconds, start, stop1);

  //Rprintf("%f memcpy\n", milliseconds);
  int threads = 16;
  int blocks_in_row = (*n + threads - 1) / threads;
  int blocks_in_col = (*n + threads - 1) / threads;

  dim3 THREADS(threads, threads);
  dim3 BLOCKS(blocks_in_row, blocks_in_col);

  unsigned int* d_result;
  unsigned int* h_result = new unsigned int[(*m) * (*m)];
  cudaMalloc(&d_result, (*m) * (*m) * sizeof(unsigned int));
  cudaMemset(d_result, 0, (*m) * (*m) * sizeof(unsigned int));

  //cudaEventRecord(stop2);
  //cudaEventSynchronize(stop2);

  //cudaEventElapsedTime(&milliseconds, start, stop2);

  // Rprintf("%f memset\n", milliseconds);

  Rkendall_gpu_atomic_float<<<BLOCKS, THREADS>>>(d_array, *n, *m, d_result);

  cudaMemcpy(h_result, d_result, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);

  
  for (int i = 0; i < (*m) * (*m); ++i) {
    c[i] = h_result[i] * 2.0f / (*n) / (*n - 1);
  }

  free(h_result);
  cudaFree(d_result);
  cudaFree(d_array);

  //cudaEventRecord(stop3);
  //cudaEventSynchronize(stop3);

  //cudaEventElapsedTime(&milliseconds, start, stop3);
  //Rprintf("%f kernel call\n", milliseconds);
  
  end = clock();
  cpu_time_used = ((double) (end - start_1)) / CLOCKS_PER_SEC;
  Rprintf("%lf all time \n", cpu_time_used);
}


//' Driver Function for calculation of Euclidean matrix for same block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Euclidean_distance_same_block(double* a, double * b /* not used */, double* c, int* n, int* m, int* m_b){


  int array_size = *n * *m;

  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }

  float* d_array;

  cudaMalloc(&d_array, array_size * sizeof(float));

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);

  int threads = 256;
  int blocks_in_row = (*n + threads - 1) / threads;
  //int blocks_in_col = *n;


  unsigned int* d_result;
  unsigned int* h_result = new unsigned int[(*m) * (*m)];
  cudaMalloc(&d_result, (*m) * (*m) * sizeof(unsigned int));
  cudaMemset(d_result, 0, (*m) * (*m) * sizeof(unsigned int));

  Reuclidean_gpu_atomic_float<<<blocks_in_row, threads>>>(d_array, *n, *m, d_result);

  cudaMemcpy(h_result, d_result, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);


  for (int i = 0; i < (*m) * (*m); ++i) {
    c[i] = sqrtf(h_result[i]);
  }

  free(h_result);
  cudaFree(d_result);
  cudaFree(d_array);
}


//' Driver Function for calculation of Kendall matrix for different block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Kendall_distance_different_blocks(double* a, double* b, double* c, int* n, int* m, int* m_b){

  int array_size = *n * *m;
  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }

  int array2_size = *n * (*m_b);
  float* array2_new = new float[array2_size];

  for (int i = 0; i < array2_size; ++i) {
    array2_new[i] = b[i];
  }

  float* d_array;
  float* d_array2;

  cudaMalloc(&d_array, array_size * sizeof(float));
  cudaMalloc(&d_array2, array_size * sizeof(float));

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(d_array2, array2_new, array2_size * sizeof(float), cudaMemcpyHostToDevice);

  int threads = 16;
  int blocks_in_row = (*n + threads - 1) / threads;
  int blocks_in_col = (*n + threads - 1) / threads;

  dim3 THREADS(threads, threads);
  dim3 BLOCKS(blocks_in_row, blocks_in_col);

  unsigned int* d_result;
  unsigned int* h_result = new unsigned int[(*m) * (*m_b)];
  cudaMalloc(&d_result, (*m) * (*m_b) * sizeof(unsigned int));
  cudaMemset(d_result, 0, (*m) * (*m_b) * sizeof(unsigned int));

  Rkendall_gpu_atomic_float_different_blocks<<<BLOCKS, THREADS>>>(d_array, d_array2, *n, *m, *m_b, d_result);

  cudaMemcpy(h_result, d_result, (*m) * (*m_b) * sizeof(float), cudaMemcpyDeviceToHost);


  for (int i = 0; i < (*m) * (*m_b); ++i) {
    c[i] = h_result[i] * 2.0f / (*n) / (*n - 1);
  }

  free(h_result);
  cudaFree(d_result);
  cudaFree(d_array);
  cudaFree(d_array2);
}


//' Driver Function for calculation of Euclidean matrix for different block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Euclidean_distance_different_blocks(double* a, double* b, double* c, int* n, int* m, int* m_b){

  int array_size = *n * *m;
  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }

  int array2_size = *n * (*m_b);
  float* array2_new = new float[array2_size];

  for (int i = 0; i < array2_size; ++i) {
    array2_new[i] = b[i];
  }

  float* d_array;
  float* d_array2;

  cudaMalloc(&d_array, array_size * sizeof(float));
  cudaMalloc(&d_array2, array_size * sizeof(float));

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(d_array2, array2_new, array2_size * sizeof(float), cudaMemcpyHostToDevice);

  int threads = 256;
  int blocks_in_row = (*n + threads - 1) / threads;
  //int blocks_in_col = *n ;

  unsigned int* d_result;
  unsigned int* h_result = new unsigned int[(*m) * (*m_b)];
  cudaMalloc(&d_result, (*m) * (*m_b) * sizeof(unsigned int));
  cudaMemset(d_result, 0, (*m) * (*m_b) * sizeof(unsigned int));

  Reuclidean_gpu_atomic_float_different_blocks<<<blocks_in_row, threads>>>(d_array, d_array2, *n, *m, *m_b, d_result);

  cudaMemcpy(h_result, d_result, (*m) * (*m_b) * sizeof(float), cudaMemcpyDeviceToHost);


  for (int i = 0; i < (*m) * (*m_b); ++i) {
    c[i] = sqrtf(h_result[i]);
  }

  free(h_result);
  cudaFree(d_result);
  cudaFree(d_array);
  cudaFree(d_array2);
}

//' Driver Function for calculation of Pearson matrix for same block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Pearson_distance_same_block(double* a, double * b /* not used */, double* c, int* n, int* m, int* m_b){
  int array_size = *n * *m;
  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }

  // int array2_size = *n * (*m_b);
  // float* array2_new = new float[array2_size];

  // for (int i = 0; i < array2_size; ++i) {
  //   array2_new[i] = b[i];
  // }

  float* d_array;
  // float* d_array2;

  cudaMalloc(&d_array, array_size * sizeof(float));
  // cudaMalloc(&d_array2, array_size * sizeof(float));

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);
  // cudaMemcpy(d_array2, array2_new, array2_size * sizeof(float), cudaMemcpyHostToDevice);

  int threads = 256;
  int blocks = (*n + threads - 1) / threads;
  // int blocks_in_col = (*n + threads - 1) / threads;


  float* d_result;
  float* h_result = new float[(*m) * (*m)];

  cudaMalloc(&d_result, (*m) * (*m) * sizeof(float)); 
  cudaMemset(d_result, 0, (*m) * (*m) * sizeof(float));

  float* d_x_norm_result;
  float* h_x_norm_result = new float[(*m) * (*m)];

  cudaMalloc(&d_x_norm_result, (*m) * (*m) * sizeof(float)); 
  cudaMemset(d_x_norm_result, 0, (*m) * (*m) * sizeof(float));

  float* d_y_norm_result;
  float* h_y_norm_result = new float[(*m) * (*m)];

  cudaMalloc(&d_y_norm_result, (*m) * (*m) * sizeof(float)); 
  cudaMemset(d_y_norm_result, 0, (*m) * (*m) * sizeof(float));

  RpearsonCorr_gpu_atomic_float_same_block<<<blocks, threads>>>(
    d_array,
    *n, *m,
    d_result,
    d_x_norm_result,
    d_y_norm_result
  );
  cudaMemcpy(h_result, d_result, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(h_x_norm_result, d_x_norm_result, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(h_y_norm_result, d_y_norm_result, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  int j=0;
  for (int i = 0; i < (*m) * (*m); ++i) {
    // printf("%4.2f ",h_result[i]);
    
    if(!isnan(h_result[i])){
      //if (i == 1 || i == (*m)) {
      //  printf("%f %f %f\n", h_result[i], h_x_norm_result[i], h_y_norm_result[i]);
      //}
      if (i == j * (*m+1)){
       c[i] = 0.0; //1.0 - h_result[i] / sqrtf(h_x_norm_result[i]) / sqrtf(h_y_norm_result[i]);
       j++;  
      } else {
        c[i] = 1.0 - h_result[i] / sqrtf(h_x_norm_result[i]) / sqrtf(h_y_norm_result[i]);
      }
    }
  }

  free(h_result);
  cudaFree(d_result);
  cudaFree(d_x_norm_result);
  cudaFree(d_y_norm_result);
  cudaFree(d_array);
  // cudaFree(d_array2);
}

//' Driver Function for calculation of Pearson matrix for different block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel, 
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//' 
extern "C" void matrix_Pearson_distance_different_blocks(double* a, double * b /* not used */, double* c, int* n, int* m, int* m_b){
    int array_size = *n * *m;
  float* array_new = new float[*n * *m];

  for (int i = 0; i < array_size; ++i) {
    array_new[i] = a[i];
  }

  int array2_size = *n * (*m_b);
  float* array2_new = new float[array2_size];

  for (int i = 0; i < array2_size; ++i) {
    array2_new[i] = b[i];
  }

  float* d_array;
  float* d_array2;

  cudaMalloc(&d_array, array_size * sizeof(float));
  cudaMalloc(&d_array2, array_size * sizeof(float));

  cudaMemcpy(d_array, array_new, array_size * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(d_array2, array2_new, array2_size * sizeof(float), cudaMemcpyHostToDevice);

  int threads = 16;
  int blocks_in_row = (*n + threads - 1) / threads;
  int blocks_in_col = (*n + threads - 1) / threads;

  dim3 THREADS(threads, threads);
  dim3 BLOCKS(blocks_in_row, blocks_in_col);

//  float* d_result;
//  float* h_result = new float[(*m) * (*m_b)];
  float* scalar;
  float* h_scalar = new float[(*m) * (*m_b)];
 float* prod1;
  float* h_prod1 = new float[(*m) * (*m_b)];
 float* prod2;
  float* h_prod2 = new float[(*m) * (*m_b)];

//  cudaMalloc(&d_result, (*m) * (*m_b) * sizeof(float)); 
//  cudaMemset(d_result, 0, (*m) * (*m_b) * sizeof(float));
  cudaMalloc(&scalar, (*m) * (*m_b) * sizeof(float)); 
  cudaMemset(scalar, 0, (*m) * (*m_b) * sizeof(float));
  cudaMalloc(&prod1, (*m) * (*m_b) * sizeof(float)); 
  cudaMemset(prod1, 0, (*m) * (*m_b) * sizeof(float));
  cudaMalloc(&prod2, (*m) * (*m_b) * sizeof(float)); 
  cudaMemset(prod2, 0, (*m) * (*m_b) * sizeof(float));

  RpearsonCorr_gpu_atomic_float_different_blocks<<<blocks_in_row, threads>>>(d_array,d_array2, *n, *m,*m_b, scalar,prod1,prod2);
  cudaMemcpy(h_scalar, scalar, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(h_prod1, prod1, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(h_prod2, prod2, (*m) * (*m) * sizeof(float), cudaMemcpyDeviceToHost);
  
  int j=0;
  for (int i = 0; i < (*m) * (*m); ++i) {
    // printf("%4.2f ",h_result[i]);
    
    if(!isnan(h_scalar[i])){
      //if (i == 1 || i == (*m)) {
      //  printf("%f %f %f\n", h_result[i], h_x_norm_result[i], h_y_norm_result[i]);
      //}
      if (i == j * (*m+1)){
       c[i] = 0.0; //1.0 - h_result[i] / sqrtf(h_x_norm_result[i]) / sqrtf(h_y_norm_result[i]);
       j++;  
      } else {
        c[i] = 1.0 - h_scalar[i] / sqrtf(h_prod1[i]) / sqrtf(h_prod2[i]);
      }
    }
  }


  free(h_scalar);
  free(h_prod2);
  free(h_prod1);
  
  cudaFree(scalar);
  cudaFree(prod2);
  cudaFree(prod1);
  cudaFree(d_array);
  cudaFree(d_array2);
}

//' Driver Function for calculation of Pearson matrix for different block.
//'
//' Allocates Memory required for the operation. Then,
//' efficiently calculate the distance matrix using the kernel,
//' which is translated to appropriate R tables.
//'
//' @param a,b,c double pointers pointing to memory.
//' @param n,m,m_b Boundary values.
//' @export
//'`
__global__ void matrix_Euclidean_sparse_distance_same_block_gpu(
  int *a_index,
  int *a_positions,
  float *a_values,  // Use float instead of double for GPU calculations
  float *result,
  int num_rows,
  int num_columns
) {
  int row_index = blockIdx.x * blockDim.x + threadIdx.x;

  if (row_index < num_rows) {
    int start_column = a_positions[row_index];
    int end_column = a_positions[row_index + 1];

    for (int col1_index = start_column; col1_index < end_column; ++col1_index) {
      for (int col2_index = col1_index; col2_index < end_column; ++col2_index) {
        int prev_col_index = col1_index - 1;
        int prev_col = (prev_col_index >= start_column) ? a_index[prev_col_index] : -1;

        int next_col_index = col2_index + 1;
        int next_col = (next_col_index < end_column) ? a_index[next_col_index] : num_columns;

        int col1 = a_index[col1_index];
        int col2 = a_index[col2_index];

        float value1 = a_values[col1_index];
        float value2 = a_values[col2_index];

        for (int left = prev_col + 1; left < col1; ++left) {
          atomicAdd(&result[left * num_columns + col2], value2 * value2);
          atomicAdd(&result[col2 * num_columns + left], value2 * value2);
        }

        for (int right = col2 + 1; right < next_col; ++right) {
          atomicAdd(&result[right * num_columns + col1], value1 * value1);
          atomicAdd(&result[col1 * num_columns + right], value1 * value1);
        }

        atomicAdd(&result[col1 * num_columns + col2], (value1 - value2) * (value1 - value2));
        atomicAdd(&result[col2 * num_columns + col1], (value1 - value2) * (value1 - value2));
      }
    }
  }
}

extern "C" void matrix_Euclidean_sparse_distance_same_block_gpu_wrapper(
  int *a_index,
  int *a_positions,
  double *a_double_values,
  double *result,
  int num_rows,
  int num_columns,
  int num_elements_a
) {
  float *a_values = new float[num_elements_a];
  for (int i = 0; i < num_elements_a; ++i) {
    a_values[i] = static_cast<float>(a_double_values[i]);
  }

  float *d_a_values, *d_result;
  int *d_a_index, *d_a_positions;

  cudaMalloc(&d_a_values, num_elements_a * sizeof(float));
  cudaMalloc(&d_result, num_columns * num_columns * sizeof(float));
  cudaMalloc(&d_a_index, num_elements_a * sizeof(int));
  cudaMalloc(&d_a_positions, (num_rows + 1) * sizeof(int));

  cudaMemcpy(d_a_values, a_values, num_elements_a * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(d_a_index, a_index, num_elements_a * sizeof(int), cudaMemcpyHostToDevice);
  cudaMemcpy(d_a_positions, a_positions, (num_rows + 1) * sizeof(int), cudaMemcpyHostToDevice);

  int threadsPerBlock = 256;
  int numBlocks = (num_rows + threadsPerBlock - 1) / threadsPerBlock;

  matrix_Euclidean_sparse_distance_same_block_gpu<<<numBlocks, threadsPerBlock>>>(
    d_a_index, d_a_positions, d_a_values, d_result, num_rows, num_columns
  );

  cudaMemcpy(result, d_result, num_columns * num_columns * sizeof(float), cudaMemcpyDeviceToHost);

  cudaFree(d_a_values);
  cudaFree(d_result);
  cudaFree(d_a_index);
  cudaFree(d_a_positions);

  delete[] a_values;
}


extern "C" void file_Kendall_distance(double* a, int* n, int* m, char** fout){
  std::ofstream RESULTFILE(*fout, std::ios::binary|std::ios::app);
  size_t dataset_column_size = *n * sizeof(double);
  size_t reverse_max_size = sizeof(unsigned long long);
  for (int col1 = 0; col1 < *m; col1++){
    double* first_column_device_ptr;
    cudaMalloc(&first_column_device_ptr, dataset_column_size);
    cudaMemcpy(first_column_device_ptr, a + col1 * *n, dataset_column_size, cudaMemcpyHostToDevice);
    for (int col2 = col1 + 1; col2 < *m; col2 ++){
      double* second_column_device_ptr;
      cudaMalloc(&second_column_device_ptr, dataset_column_size);
      cudaMemcpy(second_column_device_ptr, a + col2 * *n, dataset_column_size, cudaMemcpyHostToDevice);
      unsigned long long host_R = 0;
      unsigned long long* device_R;
      cudaMalloc(&device_R, reverse_max_size);
      cudaMemcpy(device_R, &host_R, reverse_max_size, cudaMemcpyHostToDevice);
      int threads = 16;
      int blocks_in_row = (*n + threads - 1) / threads;
      int blocks_in_col = (*n + threads - 1) / threads;

      dim3 THREADS(threads, threads);
      dim3 BLOCKS(blocks_in_row, blocks_in_col);

      Rkendall_gpu_atomic<<<BLOCKS, THREADS>>>(first_column_device_ptr, second_column_device_ptr, *n, *m, device_R);
      cudaDeviceSynchronize();

      cudaMemcpy(&host_R, device_R, reverse_max_size, cudaMemcpyDeviceToHost);

      double distance = host_R * 2.0 / *n / (*n - 1);
      RESULTFILE.write((char*)&distance, sizeof(distance));

      cudaFree(second_column_device_ptr);
      cudaFree(device_R);
    }
    cudaFree(first_column_device_ptr);
  }
  RESULTFILE.close();
}
