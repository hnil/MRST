//
// include necessary system headers
//
#include <cmath>
// #include <mex.h>
#include <array>
#ifdef _OPENMP
    #include <omp.h>
#endif
#include <iostream>
//#ifdef OCTAVE_VERSION
    #include <octave/oct.h>
    #include <octave/dMatrix.h>
//#endif
void faceAverage(const int nf, const int nc, const int dim, const double* value, const double* N, double* result) {
    #pragma omp parallel for schedule(static)
    for(int i=0;i<nf;i++){
        int left = N[i] - 1;
        int right = N[i + nf] - 1;
        for(int j =0; j<dim; j++){
            result[i+nf*j] = 0.5*(value[left + nc*j] + value[right + nc * j]);
        }
    }
}

/* OCT gateway */
// #ifdef OCTAVE_VERSION
    DEFUN_DLD (mexFaceAverageVal, args, nargout,
               "Face average operator for MRST - value only.")
    {
        const int nrhs = args.length();
        const int nlhs = nargout;
        if (nrhs == 0) {
            if (nlhs > 0) {
                error("Cannot give outputs with no inputs.");
            }
            // We are being called through compilation testing. Just do nothing.
            // If the binary was actually called, we are good to go.
            return octave_value_list();
        } else if (nrhs != 2) {
            error("2 input arguments required.");
        } else if (nlhs > 1) {
            error("Wrong number of output arguments.");
        }
        
        const NDArray value_nd = args(0).array_value();
        const NDArray N_nd = args(1).array_value();
        
        const double * value = value_nd.data();
        const double * N = N_nd.data();
        // double * value = mxGetPr(prhs[0]);
        // double * N = mxGetPr(prhs[1]);
        const dim_vector sz = value_nd.dims();
        const dim_vector nsz = N_nd.dims();
        
        int dim = sz(1);
        int nc = sz(0);
        
        int nf = nsz(0);
        /*
        int dim = mxGetN(prhs[0]);
        int nc = mxGetM(prhs[0]);
        int nf = mxGetM(prhs[1]);
        */
        NDArray output({nf, dim}, 0);
        double * result = output.fortran_vec();
        // plhs[0] = mxCreateDoubleMatrix(nf, dim, mxREAL);
        // double * result = mxGetPr(plhs[0]);

       faceAverage(nf, nc, dim, value, N, result);
       return octave_value (output);
    }
// #endif



// /* MEX gateway */
// void mexFunction( int nlhs, mxArray *plhs[], 
// 		  int nrhs, const mxArray *prhs[] )
//      
// { 
//     // In: Cell value (nc x d), N (nf x 2)
//     // Out: Face value of (nf x d)
//     if (nrhs == 0) {
//         if (nlhs > 0) {
//             mexErrMsgTxt("Cannot give outputs with no inputs.");
//         }
//         // We are being called through compilation testing. Just do nothing. 
//         // If the binary was actually called, we are good to go.
//         return;
//     } else if (nrhs != 2) {
// 	    mexErrMsgTxt("2 input arguments required."); 
//     } else if (nlhs > 1) {
// 	    mexErrMsgTxt("Wrong number of output arguments."); 
//     } 
//     double * value = mxGetPr(prhs[0]);
//     double * N = mxGetPr(prhs[1]);
// 
//     int dim = mxGetN(prhs[0]);
//     int nc = mxGetM(prhs[0]);
//     int nf = mxGetM(prhs[1]);
//     plhs[0] = mxCreateDoubleMatrix(nf, dim, mxREAL);
//     double * result = mxGetPr(plhs[0]);
//     faceAverage(nf, nc, dim, value, N, result);
// 
//     return;
// }


