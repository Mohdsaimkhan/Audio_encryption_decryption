#include <iostream>
#include <sndfile.hh>
#include <cmath>
#include <cuda_runtime.h>

// Function to design a digital low-pass filter (Gaussian FIR)
void designLowPassFilter(float* filterCoefficients, int filterLength, float cutoffFrequency) {
    const float sigma = 0.1; 
    const float twoSigmaSquare = 2.0f * sigma * sigma;
    const int midPoint = filterLength / 2;

    for (int i = 0; i < filterLength; ++i) {
        int distance = i - midPoint;
        filterCoefficients[i] = std::exp(-(distance * distance) / twoSigmaSquare);
    }

    // Normalize the filter coefficients
    float sum = 0.0f;
    for (int i = 0; i < filterLength; ++i) {
        sum += filterCoefficients[i];
    }

    for (int i = 0; i < filterLength; ++i) {
        filterCoefficients[i] /= sum;
    }
}

// CUDA kernel for applying the low-pass filter
__global__ void applyLowPassFilter(float* data, int dataSize, const float* filterCoefficients, int filterLength) {
    __shared__ float sharedData[256]; // Shared memory for input data block
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < dataSize) {
        sharedData[threadIdx.x] = data[idx];
        __syncthreads();

        float result = 0.0f;

        for (int i = 0; i < filterLength; ++i) {
            int dataIndex = threadIdx.x - i + filterLength / 2;
            if (dataIndex >= 0 && dataIndex < blockDim.x) {
                result += sharedData[dataIndex] * filterCoefficients[i];
            }
        }

        data[idx] = result;
    }
}

// CUDA kernel for modulation (multiplication with sinusoid)
__global__ void applyModulation(float* data, int dataSize, float modulationFrequency, float sampleRate) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;

    if (idx < dataSize) {
        float angle = 2.0f * M_PI * modulationFrequency * idx / sampleRate;
        data[idx] *= sin(angle);
    }
}

// Function to perform audio encryption on GPU and measure time
float audioEncryptionGPU(float* d_data, int dataSize, float cutoffFrequency, float modulationFrequency, float sampleRate) {
    const int filterLength = 64; 

    // Create CUDA events for timing
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);

    // Host variable for filter coefficients
    float h_filterCoefficients[filterLength];
    
    // Design the low-pass filter on the host
    designLowPassFilter(h_filterCoefficients, filterLength, cutoffFrequency);

    // Allocate GPU memory for filter coefficients
    float* d_filterCoefficients;
    cudaMalloc((void**)&d_filterCoefficients, filterLength * sizeof(float));

    // Copy filter coefficients to GPU
    cudaMemcpy(d_filterCoefficients, h_filterCoefficients, filterLength * sizeof(float), cudaMemcpyHostToDevice);

    // Configure GPU execution parameters
    const int blockSize = 256;
    const int gridSize = (dataSize + blockSize - 1) / blockSize;

    // Record start time
    cudaEventRecord(start);

    // Launch the low-pass filter kernel on GPU
    applyLowPassFilter<<<gridSize, blockSize>>>(d_data, dataSize, d_filterCoefficients, filterLength);
    cudaDeviceSynchronize();

    // Launch the modulation kernel on GPU
    applyModulation<<<gridSize, blockSize>>>(d_data, dataSize, modulationFrequency, sampleRate);
    cudaDeviceSynchronize();

    // Record stop time
    cudaEventRecord(stop);
    cudaEventSynchronize(stop);

    // Calculate and return elapsed time
    float milliseconds = 0.0f;
    cudaEventElapsedTime(&milliseconds, start, stop);

    // Free GPU memory for filter coefficients
    cudaFree(d_filterCoefficients);

    return milliseconds;
}


int main(int argc, char* argv[]) {
    // Parse command-line options to determine encryption or decryption
    bool encryptionMode = true; // Set to true for encryption, false for decryption

    // Check command-line arguments
    if (argc != 5) {
        std::cerr << "Usage: " << argv[0] << " <input_file.wav> <output_file.wav> <cutoff_frequency> <modulation_frequency>" << std::endl;
        return 1;
    }

    // Load the audio file using libsndfile
    SndfileHandle inputFile(argv[1], SFM_READ);
    if (!inputFile) {
        std::cerr << "Error: Failed to open input file." << std::endl;
        return 1;
    }

    // Get audio file parameters
    int dataSize = static_cast<int>(inputFile.frames());
    int sampleRate = inputFile.samplerate();
    int numChannels = inputFile.channels();

    // Allocate host memory for audio data
    float* h_audioData = new float[dataSize];

    // Read audio data from the file
    inputFile.read(h_audioData, dataSize);

    // Allocate device memory for audio data
    float* d_audioData;
    cudaMalloc((void**)&d_audioData, dataSize * sizeof(float));
    cudaMemcpy(d_audioData, h_audioData, dataSize * sizeof(float), cudaMemcpyHostToDevice);

    // Apply audio encryption on GPU and measure time
    float cutoffFrequency = std::stof(argv[3]); // Cutoff frequency from command line
    float modulationFrequency = std::stof(argv[4]); // Modulation frequency from command line
    float processingTime = audioEncryptionGPU(d_audioData, dataSize, cutoffFrequency, modulationFrequency, sampleRate);

    // Print processing time
    std::cout << "GPU Processing Time: " << processingTime << " ms" << std::endl;

    // Copy results from device to host
    cudaMemcpy(h_audioData, d_audioData, dataSize * sizeof(float), cudaMemcpyDeviceToHost);

    // Write the resulting WAV file using libsndfile
    SndfileHandle outputFile(argv[2], SFM_WRITE, SF_FORMAT_WAV | SF_FORMAT_PCM_16, numChannels, sampleRate);
    if (!outputFile) {
        std::cerr << "Error: Failed to open output file." << std::endl;
        return 1;
    }
    outputFile.write(h_audioData, dataSize);

    // Deallocate device memory
    cudaFree(d_audioData);

    // Clean up
    delete[] h_audioData;

    return 0;
}
