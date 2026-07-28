clear;
clc;
close all;

%dataSet = fullfile("mvtec_anomaly_detection_USED/toothbrush/train/")

%dataSet = "C:\Users\alexisarroyo\Documents\MATLAB\mvtec_anomaly_detection_USED\toothbrush\train";

dataSet = uigetdir;


imds = imageDatastore(dataSet,"IncludeSubfolders",true,LabelSource="foldernames")

numImages = numel(imds.Labels);
idx = randperm(numImages,16);
I = imtile(imds,Frames=idx);
figure
imshow(I)

classNames = categories(imds.Labels)
numClasses = numel(classNames)

[imdsTrain,imdsValidation,imdsTest] = splitEachLabel(imds,0.7,0.15,0.15,"randomized");

inputSize = [224 224]

fprintf("Training images: %d\n", numel(imdsTrain.Files));
fprintf("Validation images: %d\n", numel(imdsValidation.Files));
fprintf("Testing images: %d\n", numel(imdsTest.Files));

augmenter = imageDataAugmenter( ...
    "RandRotation", [-10 10], ...
    "RandXReflection", true, ...
    "RandXTranslation", [-5 5], ...
    "RandYTranslation", [-5 5]);

% Training images: resize, augment, and convert grayscale to RGB
augimdsTrain = augmentedImageDatastore( ...
    inputSize, ...
    imdsTrain, ...
    "DataAugmentation", augmenter, ...
    "ColorPreprocessing", "gray2rgb");

% Validation images: resize and convert grayscale to RGB
augimdsValidation = augmentedImageDatastore( ...
    inputSize, ...
    imdsValidation, ...
    "ColorPreprocessing", "gray2rgb");

% Test images: resize and convert grayscale to RGB
augimdsTest = augmentedImageDatastore( ...
    inputSize, ...
    imdsTest, ...
    "ColorPreprocessing", "gray2rgb");


net = imagePretrainedNetwork( ...
    "resnet18", ...
    NumClasses=numClasses);

options = trainingOptions("adam", ...
    "InitialLearnRate", 1e-4, ...
    "MaxEpochs", 10, ...
    "MiniBatchSize", 8, ...
    "Shuffle", "every-epoch", ...
    "ValidationData", augimdsValidation, ...
    "ValidationFrequency", 5, ...
    "ValidationPatience", 5, ...
    "Metrics", "accuracy", ...
    "ObjectiveMetricName", "loss", ...
    "OutputNetwork", "best-validation", ...
    "Plots", "training-progress", ...
    "Verbose", true);

trainedNet = trainnet(augimdsTrain,net,"crossentropy",options)


%uncomment to save the trained net 
%save("trainedNetwork.mat", ..."trainedNet", ..."classNames", ..."inputSize", ..."imdsTest")

scores = minibatchpredict(trainedNet, augimdsTest);

% Convert scores to predicted labels
predictedLabels = scores2label(scores, classNames);

% Actual labels
actualLabels = imdsTest.Labels;

% Calculate accuracy
accuracy = mean(predictedLabels == actualLabels);


fprintf("Test Accuracy: %.2f%%\n", accuracy*100);

% Display confusion matrix
figure
confusionchart(actualLabels, predictedLabels);
title("Confusion Matrix");















%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"onright","rightPanelPercent":46.6}
%---
