# EPP-Mathworks-Challenge-2026-Team10

## Objective

The objective of this project is to build an image-based manufacturing inspection system in MATLAB that can identify possible defects in a part and classify the part as PASS or FAIL. Classical image-processing methods are used to highlight suspicious regions and measure the detected defects, while a pretrained network is further trained using the defect images to classify each part as PASS or FAIL. The final system combines the AI prediction with a red evidence overlay and simple metrics to show what the program detected and help explain the inspection result.

## How to Run the Code and Models

Download all files in the `download_matlab_files` folder. All files must be in the same MATLAB directory, otherwise the live script cannot function.

Download and extract the `mvtec_anomaly_detection_USED_v5.zip` from the `image_data_set_info` folder. This is the dataset used for the program.

Open the main MATLAB Live Script, `(REPORT) Live Script For ImageBasedDefectSystem [V1].mlx`.

### Task 1: Explore and Organize Image Dataset

Run the **Task 1** section and click on the **Insert data set here** button to select the downloaded dataset on your device. The program will organize and partition the images into the class labels needed to train each classifier.

A table will be displayed showing how the dataset is organized. This can be used to understand how the different part types and defect classes are set up throughout the Live Script.

**NOTE:** Task 1 must be run first because it sets up the dataset and variables needed by the rest of the program.

### Task 2: Build a Single-Image Inspection Function

The **Task 2** section can be used to test the classical image-processing functions for each part.

Each part has its own section, so you can test one part at a time instead of running every part. Using the Import Data Live Tasks, select an image from the corresponding defect category and use the variable names provided in the Live Script. Make sure every Import Data Live Task within the section you are running has an image selected and is assigned the correct variable name listed in the Live Script. If any required image or variable is missing, that section will not run properly.

The inspection functions generate a binary evidence mask and use it to display a red evidence overlay. They also calculate defect metrics such as the number of suspicious regions, size of the largest region, and area ratio.

### Task 3: Train and Integrate the AI Classifiers

The **Task 3** section shows how the AI classifiers are created and trained. Each part has its own classifier, and the trained networks are stored together in one structure.

Training all of the networks can take a long time, especially on slower or older devices. You can run this section to train the classifiers yourself, or simply review the code to understand how the classifiers are set up.

A pretrained network structure is provided in `testingScriptNetworksAndClasses.mat`. This file contains the trained networks for each classifier and allows the rest of the Live Script to run without retraining them. The Live Script automatically loads this file in the sections where it is needed, so it does not need to be loaded manually.

Training results for the provided networks can be found in the `trained_network_statistics` folder within `trained_network_structure`. Each network has an image of its training results.

**Read the comments at the beginning of each Task 3 code section before running it**

### Task 3 Checkpoint: Combine Outputs into a Hybrid Inspection Result

The checkpoint combines the AI classifier with the classical image-processing functions from Task 2.

Run the checkpoint and select one image using the **Image to Inspect** button. The program will determine the part type and PASS/FAIL result using the trained classifiers. If a defect is detected, the corresponding classical inspection function is used to analyze the image and highlight suspicious regions.

The final inspection result displays the AI prediction, confidence score, red evidence overlay, and defect metrics for the selected image.

### Test “classifyImg”

After the trained network structure is available, the **Test “classifyImg”** section can be used to test the AI classification by itself.

Select an image by clicking on the **Click here to insert image** icon. The program will first classify the part type, then classify the image as PASS or FAIL. If the image is classified as FAIL, the program will also predict the defect type.

The section displays the selected image and prints the predicted labels and confidence scores for the part classifier, condition classifier, and defect classifier.

If you did not train the classifiers yourself, the provided trained network structure must be available before running this section.

### Task 4: Evaluate Inspection System Performance

Task 4 includes separate sections depending on whether you want to train your own networks or use the pretrained networks.

Training the networks while also running the testing script can take a long time and may cause slower or older devices to run poorly or even crash. If you do not want to retrain the networks, you can use the provided pretrained option instead.

Be sure to read the comments at the top of each **Task 4** code section before running anything so you know which option you are using.

### Task 5: Test and Evaluate System Robustness

Task 5 is set up similarly to Task 4 and also includes separate sections for either training your own networks or using the pretrained networks.

Training and testing at the same time can take a long time and may be difficult for slower or older devices. If you want to avoid retraining, you can use the provided pretrained option.

Be sure to read the comments at the top of each **Task 5** code section before running anything.

## Required Toolboxes or Dependencies

- Statistics and Machine Learning Toolbox
- Reinforcement Learning Toolbox
- Optimization Toolbox
- Model Predictive Control Toolbox
- MATLAB Coder
- Parallel Computing Toolbox
- MATLAB Compiler
- MATLAB Compiler SDK
- MATLAB Report Generator
- Image Acquisition Toolbox
- Image Processing Toolbox
- Deep Learning Toolbox
- Curve Fitting Toolbox
- Deep Learning HDL Toolbox

## How to Reproduce your Results

The results can be reproduced using either the provided pretrained networks or by training the networks again using the provided dataset and training scripts.

Before reproducing the results, run **Task 1** to load and organize the dataset into the class labels and variables used throughout the Live Script.

For **Task 2**, select images from the different part and defect categories in the `mvtec_anomaly_detection_USED_v5.zip` dataset and run the corresponding classical inspection sections. The program generates a binary evidence mask, then uses that mask to create and display a red evidence overlay along with the defect metrics for each selected image. Results will vary depending on the image selected because defect size, appearance, and location differ throughout the dataset.

For **Task 3**, the pretrained-network option can be used to run the inspection system with the saved classifiers from a previous training run. Alternatively, the networks can be trained again using `runInspectionSuiteTRAIN.m`. After the classifier is ready, run the **“Task 3 Checkpoint: Combine outputs into a hybrid inspection result”** and select an image using the **Image to Inspect** button.

The final system will display the PASS/FAIL prediction, confidence score, red evidence overlay, and defect metrics. AI predictions and confidence scores may vary slightly if the networks are trained again.

For **Task 4**, run either the pretrained or training evaluation section. The program evaluates the inspection system on a batch of test images and produces a confusion matrix, yield and defect summaries, and examples of common failure cases. Using the pretrained option reproduces the results with the saved networks and test set, while the training option retrains the networks before evaluation.

For **Task 5**, run either the pretrained or training robustness section. The program applies simulated image changes such as brightness, blur, or noise and reevaluates the inspection system. The results can then be compared with the original Task 4 results to see how accuracy and false-reject rates change under these variations.
