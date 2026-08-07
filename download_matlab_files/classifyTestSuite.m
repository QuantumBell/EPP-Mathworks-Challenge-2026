function InspectionSystem = classifyTestSuite(trainDataSet, valDataSet,...
    fullDataSet)
%classifyTestSuite Function that will create and return classifier data
%   Function will create a structure that contains multiple classifiers
%   based on part type. Structure consists of: classifiers (part,
%   condition, and defect type). The part classifier structure consists of:
%   network and class names, and the name of the classifier (Part Classifier). 
%   Condition classifier consists of object type, which stems into network 
%   classes, and classifier name. The same outline from the condition 
%   classifier applies to defect type classifiers. Used for training and
%   validation of each network for later evaluation performance.
%   Function also displays some sanity checks for proof that each network
%   is being trained and validated on the correct images (DISPLAY INFO 
%   marks these sections).

arguments (Input)
    trainDataSet              %Table consisting of training images
    valDataSet                %Table consisting of validation images
    fullDataSet               %Original data set (used for obtaining
                              % and assigning labels)
end

arguments (Output)
    InspectionSystem       %Structure full of different classifier
                           % information
end

%The following code is the same used in Task 3, but with some adjustments
%for inputting training and validation sets from the runInspectionSuite
%script


%------Network 1: Part Classifier Network (goes before image processing)

%Create structure for classifiers (will store networks and classes labels 
% and the name of each classifier)

InspectionSystem = struct;

%CHANGED FROM TASK 3
%Establish training and validation datastore, along with the labels for
% each (this works for the part classifier since the initial split contains
% everything needed for training immediately)
imdsTrain = imageDatastore(trainDataSet.Filename);
imdsTrain.Labels = trainDataSet.Part;
partLabels = imdsTrain.Labels;
imdsVal = imageDatastore(valDataSet.Filename);
imdsVal.Labels = valDataSet.Part;

%Load pretrained network and create and modify final layer for multiple
% outputs
classes = numel(categories(partLabels));
netPart = imagePretrainedNetwork("resnet18", NumClasses=classes);

%Resize images to match the network and randomly modify images to avoid
%overfitting during learning
inputSize = netPart.Layers(1).InputSize(1:2);

partAugmenter = imageDataAugmenter(RandRotation=[-180 180]);

partAugmentTrain = augmentedImageDatastore(inputSize, imdsTrain,...
    DataAugmentation=partAugmenter, ColorPreprocessing="gray2rgb");
partAugmentVal = augmentedImageDatastore(inputSize, imdsVal,...
    ColorPreprocessing="gray2rgb");

%Modify training options for Part network
partOptions = trainingOptions("adam", InitialLearnRate=3e-4,...
    MaxEpochs=20, MiniBatchSize=16, Shuffle="every-epoch",...
    ValidationData=partAugmentVal, ValidationPatience=8,...
    ValidationFrequency=10, Plots="training-progress",...
    L2Regularization=1e-4, OutputNetwork="best-validation",...
    Metrics="accuracy", Verbose=false);


%-----DISPLAY INFO FOR TRAIN AND VAL-----

%Check labels to be used during training(ensure they match dataset setup)
disp("Training Part Table Contents for Training Part Classifier")
disp(categories(imdsTrain.Labels))
countEachLabel(imdsTrain)

disp("Validation Part Table Contents for Validating Part Classifier")
disp(categories(imdsVal.Labels))
countEachLabel(imdsVal)

%Compare above lines of code display to ensure output matches
disp("Number of files for training and validation set compared against actual dataset files")
numel(imdsTrain.Files)
numel(imdsVal.Files)
height(fullDataSet)

%-----END DISPLAY INFO-----

%Train network
fprintf("Training Parts Classifier...")
trainedPartClassifier = trainnet(partAugmentTrain, netPart,...
    "crossentropy", partOptions);

%Add to structure of networks (InspectionSystem)
InspectionSystem.PartClassifier = struct;
InspectionSystem.PartClassifier.Network = trainedPartClassifier;
InspectionSystem.PartClassifier.Classes = categories(partLabels);
InspectionSystem.PartClassifier.Name = "Part Classifier";

%}


%----Network 2: Condition Classifier



%Separate part types (used in condition and defect type classifier)
partsType = categories(fullDataSet.Part);

%Create structure for condition classifiers
InspectionSystem.ConditionClassifiers = struct;

%Loop to train each network

for k = 1:numel(partsType)

    %Converts labels to usable strings for classifier
    % structure access

    partName = matlab.lang.makeValidName(partsType{k});

    %Run network training function
    fprintf("Training %s...\n", partsType{k})
    InspectionSystem.ConditionClassifiers.(partName) =...
        trainConditionClassifier(trainDataSet, valDataSet, partsType{k});
end


%Function that will train pass/fail networks for each part in dataset
% (inputs changed from task 3)
function conditionClassifier = trainConditionClassifier(trainDataSet,...
        valDataSet, partName)

%The following will be used to establish the train and validation sets (use
% outside in testing script, but make sure to keep the code for: KEEP)

%CHANGED FROM TASK 3
    %Establish training indices and table for condition classifier (this
    % finds the part name/type that will be used and creates a table for it.
    % It is essentially the same as taking the original dataset and 
    % partitioning it like in Task 3 for pass/fail labels based on defect
    % types, but now the initial split were in tables rather than from a
    % imds, so they must start in tables and then be converted to an imds).
    trainIdx = trainDataSet.Part == partName;
    valIdx = valDataSet.Part == partName;
    trainTablePart = trainDataSet(trainIdx,:);
    valTablePart = valDataSet(valIdx,:);

%-----DISPLAY INFO-----

    %Display total fail and pass images for each part (ensure it matches
    % amount in dataset)
    disp("Training Pass/Fail Table Contents for Training Condition Classifier")
    fprintf("\n%s\n", partName)
    disp(categories(trainTablePart.Part))
    countEachLabel(imageDatastore(trainTablePart.Filename,...
        Labels=trainTablePart.("Part Condition")))

    disp("Validation Pass/Fail Table Contents for Validation Condition Classifier")
    fprintf("\n%s\n", partName)
    disp(categories(valTablePart.Part))
    countEachLabel(imageDatastore(valTablePart.Filename,...
        Labels=valTablePart.("Part Condition")))

%-----END DISPLAY INFO-----

 %CHANGED FROM TASK 3
    %Place tables in a datastore for training purposes and establish
    % labels of pass/fail for each part type
    trainImds = imageDatastore(trainTablePart.Filename);
    trainImds.Labels = trainTablePart.("Part Condition");
    valImds = imageDatastore(valTablePart.Filename);
    valImds.Labels = valTablePart.("Part Condition");

    conditionClasses = 2;

    %Load pretrained network
    netDefect = imagePretrainedNetwork("resnet18", "NumClasses",...
        conditionClasses);

    %Manage input size for network
    conditionSize = netDefect.Layers(1).InputSize(1:2);

    %Resize images and apply random modifications to avoid overfitting
    defectAugmenter = imageDataAugmenter(RandRotation=[-180 180],...
        RandXReflection=true, RandXTranslation=[-8 8],...
        RandYTranslation=[-8 8], RandScale=[0.8 1.2]);

    conditionAugmentTrain = augmentedImageDatastore(conditionSize,...
        trainImds, DataAugmentation=defectAugmenter,...
        ColorPreprocessing="gray2rgb");
    
    conditionAugmentVal = augmentedImageDatastore(conditionSize, valImds,...
        ColorPreprocessing="gray2rgb");
    
    %Define training options
    defectOptions = trainingOptions("adam", InitialLearnRate=1e-4,...
        MaxEpochs=25, MiniBatchSize=8,...
        ValidationData=conditionAugmentVal, Shuffle="every-epoch",...
        ValidationFrequency=5, ValidationPatience=15,...
        Plots="training-progress",L2Regularization=1e-3,...
        OutputNetwork="best-validation", Metrics="accuracy",...
        Verbose=false);
    
    %Train network
    defectNetTrained = trainnet(conditionAugmentTrain, netDefect,...
        "crossentropy", defectOptions);

    %Store relevant pieces into condition classifier
    conditionClassifier.Network = defectNetTrained;
    conditionClassifier.Classes = categories(trainImds.Labels);
    conditionClassifier.Name = string(partName) + " Condition Classifier";

end

%}

%----- Network 3: Defect Classification (used by image processing in case
%       of fail)


% Create a structure for defect type classifiers
InspectionSystem.DefectTypeClassifiers = struct;

% Train every network and store it
for k = 1:numel(partsType)

    %Converts labels to usable strings for classifier
    % structure access

    partName = matlab.lang.makeValidName(partsType{k});

    fprintf("Training %s Defect-Type Network...\n",partsType{k})
    InspectionSystem.DefectTypeClassifiers.(partName) =...
        trainDefectTypeClassifier(trainDataSet, valDataSet, partsType{k});

end

% Function that will train every defect type network (loops from loop above)
    function typeClassifier = trainDefectTypeClassifier(trainDataSet,...
            valDataSet, partName)
    
%CHANGED FROM TASK 3
    %Create table before imds for specified part and condition (FAIL in
    % this case) for each training and validation set
    trainPartIdx = trainDataSet.Part==partName;
    valPartIdx = valDataSet.Part==partName;
    trainPartTable = trainDataSet(trainPartIdx,:);
    valPartTable = valDataSet(valPartIdx,:);
    failIdxTrain = trainPartTable.("Part Condition")=="FAIL";
    failIdxVal = valPartTable.("Part Condition")=="FAIL";
    trainPartFailTable = trainPartTable(failIdxTrain,:);
    valPartFailTable = valPartTable(failIdxVal,:);
    
    %Remove labels that are not found in within an objects fail folder
    trainPartFailTable.("Defect Type") = removecats(trainPartFailTable.(...
        "Defect Type"));
    valPartFailTable.("Defect Type") = removecats(valPartFailTable.(...
        "Defect Type"));

%-----DISPLAY INFO-----

    %Display part that is to be trained along with the amount of images in 
    % each fail subfolder (defect type)

    disp("Training Defect Type Table Contents for Training Defect Type Classifier")
    disp(unique(trainPartFailTable.Part))
    disp(categories(trainPartFailTable.("Defect Type")))
    countEachLabel(imageDatastore(trainPartFailTable.Filename,...
        Labels=trainPartFailTable.("Defect Type")))

    disp("Validation Defect Type Table Contents for Validation Defect Type Classifier")
    disp(unique(valPartFailTable.Part))
    disp(categories(valPartFailTable.("Defect Type")))
    countEachLabel(imageDatastore(valPartFailTable.Filename,...
        Labels=valPartFailTable.("Defect Type")))

%-----END DISPLAY INFO-----

    %Create datastore to establish fail labels to define the fails for the part
    trainImds = imageDatastore(trainPartFailTable.Filename);
    valImds = imageDatastore(valPartFailTable.Filename);
    trainImds.Labels = trainPartFailTable.("Defect Type");
    valImds.Labels = valPartFailTable.("Defect Type");

    %Create classes for defect network (based on number of defect type for
    %an object
    typeClasses = numel(categories(trainImds.Labels));
    typeNetwork = imagePretrainedNetwork("resnet18", "NumClasses",...
        typeClasses);

    %Establish input size for network model
    typeSize = typeNetwork.Layers(1).InputSize(1:2);

    %Augment Data for training and validation and train network

    typeAugmenter = imageDataAugmenter(RandRotation=[-180 180]);
    augmentedTrain = augmentedImageDatastore(typeSize, trainImds,...
        "DataAugmentation", typeAugmenter,...
        "ColorPreprocessing", "gray2rgb");
    typeAugmentVal = augmentedImageDatastore(typeSize, valImds,...
        "ColorPreprocessing", "gray2rgb");
    options = trainingOptions("adam", InitialLearnRate=5e-4,...
        MaxEpochs=120, MiniBatchSize=16, ValidationData=typeAugmentVal,...
        Shuffle="every-epoch", ValidationFrequency=2,...
        Plots="training-progress", L2Regularization=1e-4,...
        OutputNetwork="last-iteration", Metrics="accuracy", Verbose=false);

    defectTypeNet = trainnet(augmentedTrain, typeNetwork,...
        "crossentropy", options);

    % Add parts of network to structure
    typeClassifier.Network = defectTypeNet;
    typeClassifier.Classes = categories(trainImds.Labels);
    typeClassifier.Name = string(partName) + " Defect Type Classifier";

end


end
