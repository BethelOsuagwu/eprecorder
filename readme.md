# Evoked response recorder
This package comprises different components which together allow to record,  programmatically and visually analyse evoked responses using MATLAB and Simulink.

![Evoked response recorder]( ./art/screenshot.png)

# Table of contents
* [Evoked response recorder](#evoked-response-recorder)
* [Table of contents](#table-of-contents)
* [Getting Started](#getting-started)
* [Installation](#installation)
  * [Prerequisites](#prerequisites)
  * [Installation](#installation-1)
* [Usage](#usage)
    * [Recording](#recording)
    * [Analysis](#analysis)
* [License](#license)

# Getting Started
The package is designed to be used with MATLAB and Simulink. The package has been tested with MATLAB R2022a. The package has been tested on Windows 10. The package has not been tested on other operating systems.

# Features
- Visualise evoked responses as they are recorded
- Add notes to evoked responses as they are recorded
- Reject trials during data recording
- Programatically analyse evoked responses
- Visualise analyse evoked responses
- Plot response averages
- Plot recruitment curves
- Estimate Transcutaneous Electrical spinal cord stimulation (TESCS) threshold parameters
- Automatically process evoked responses
- Merge separate recordings
- Import MATLAB matrices.



# Installation
## Prerequisites
The following software is required to run the package:
* MATLAB (tested with R2022a)
* Simulink (tested with R2022a)
* Signal Processing Toolbox (tested with R2022a)
* Statistics and Machine Learning Toolbox (tested with R2022a)

## Installation
The package can be installed by copying or cloning the repository. The repository can be cloned using the following command:
```bash
git clone https://github.com/BethelOsuagwu/eprecorder.git
```

# Usage
## Recording
Data reording typically done using a Simulink model. The recording parameters, including the name of the model to be used, are set in the file *initEPR.m* found in the root project directly.  Running the *initEPR.m* opens a GUI which can be used to acquire data. When a recording is started, a window appears to allow online visualisation of evoked potentials. When recording ends the data is saved in the *data* directory. The data is saved in a file with a unique name derived from recording settings. The data is saved in a *.mat* file which contains the following variables: EPR.

## Analysis
The recorded data can be proccessed visually. To do this, open the data using  *eprecorder_continuous_lab*.

Alternatively, the analysis can be done using various scripts available in the *src* directory. The scripts are typically run from the MATLAB command line. The scripts are documented in the code. 

# License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

