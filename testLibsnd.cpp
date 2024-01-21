#include <stdio.h>
#include <iostream>
#include <filesystem>
#include <vector>


#include <sndfile.hh>


int main(){
    std::cout << "STARTING MAIN\n" << std::endl;

    SF_INFO info;
    info.format = 0;

    // Open the wave file for reading
    SNDFILE *sndfile = sf_open("absolute path to .wav", SFM_READ, &info);

    if (!sndfile) {
        std::cerr << "Error: could not open file" << std::endl;
        return 1;
    }

    // Print some information about the file
    std::cout << "Sample rate: " << info.samplerate << std::endl;
    std::cout << "Channels: " << info.channels << std::endl;
    std::cout << "Samples: " << info.frames << std::endl;

    // Allocate memory for the samples
    // old: double samples[info.frames * info.channels];
    std::vector<double> samples(info.frames * info.channels);

    // Read the samples into the array
    // old: sf_readf_double(sndfile, samples, info.frames);
    sf_readf_double(sndfile, &samples[0], info.frames);

    // Close the file
    sf_close(sndfile);

    // print the size of the samples and print the first element
    // old: std::cout << "\nElements in samples: " << sizeof(samples)/sizeof(samples[0]) << std::endl;
    std::cout << "\nElements in samples: " << samples.size() << std::endl;

    // Loop through the array until the first position where the value is not 0. Print this value and postion
    for (int i = 0; i < info.frames * info.channels; i++){
        if (samples[i] != 0){
            std::cout << "Samples(" << i << "): " << samples[i] << std::endl;
            break;
        }
    }


    std::cout << "FINISHED MAIN\n" << std::endl;

    return 0;
}
