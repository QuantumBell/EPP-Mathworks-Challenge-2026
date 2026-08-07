% Script that is used to evaluate a set of models for image inspection
% This script is to be used on the latest modified dataset version. It will
% allocate data for training, validation, and testing. A function that
% trains all networks will run and return a structure that contains of 
% all the key info it holds. Evaluation will be performed through testing
% the networks on set of images through the master function "inspectPart,"
% which loops through all images in the test set, returning their label and
% confidence score. A confusion matrix for all tested images for ALL
% NETWORKS will be displayed, along with metrics of network accuracy,
% recall, and precision. Separate plots and tables containing yield and
% defect counts will also be outputted. Finally, a montage of images that
% are deemed as common failures will also be outputted.

%Testing script

%DIFFERENT from Task 3: The splitting methodology is different here since
% cvpartition does not account for there being a defect type for the
% validation set during the initial split (before being sent into
% classifyTestSuite). This causes the training and validation labels to
% never line up and halts training. The code below will account for there
% being at least 4 validation images for every defect type, along with 3
% images for every defect type for testing to ensure a proper distribution.
% This is due to the small dataset our team were ultimately forced to use
% because of difficulty masking evidence for certain defect types and
% objects

%NOTE: THIS SCRIPT CANNOT RUN UNLESS TASK 1 FROM THE LIVE SCRIPT HAS BEEN
% RAN

clc;

%To correctly partition data, create separate tables for training,
% validation, and testing (avoids any missteps during random distribution of
% data, such as every set contains each and every defect type)
trainSet = dataSetTable([],:);
valSet = dataSetTable([],:);
testSet = dataSetTable([],:);
 
%Assign categorical variable for part labels
partsLabels = categories(dataSetTable.Part);

%Establish loop for storing all the different sets of data for part,
% condition (pass/fail) and defect type (ensuring there is an image from
% each subfolder). The loop cycles through each part type and stores data
% according to its pass/fail and defect type labels
for p = 1:numel(partsLabels)
    
    %Cycle through each part (one by one)
    currentPart = partsLabels{p};

    %Obtain the pass images for current part and store them in a table
    passRows = dataSetTable.Part==currentPart & ...
        dataSetTable.("Part Condition")=="PASS";
    passTable = dataSetTable(passRows,:);
    idx = randperm(height(passTable));

    passTable = passTable(idx,:);

    %Calculates the split for PASS for each set and assigns them to 
    % corresponding table
    N = height(passTable);
    nVal = round(0.15*N);
    nTest = round(0.15*N);

    valSet = [valSet;
        passTable(1:nVal,:)];
    testSet = [testSet;
        passTable(nVal+1:nVal+nTest,:)];
    trainSet = [trainSet;
        passTable(nVal+nTest+1:end,:)];

    %Obtain the fail images for current part and store them in a table
    failRows = dataSetTable.Part==currentPart & ...
        dataSetTable.("Part Condition")=="FAIL";
    failTable = dataSetTable(failRows,:);

    %Obtain defect labels for corresponding part
    defects = categories(removecats(failTable.("Defect Type")));

    %Loop for getting a number of defect types to be in each set
    for d = 1:numel(defects)

        %Defines current defect type images to obtain based on part type
        % and extracts images
        currentDefect = defects{d};

        rows = failTable.("Defect Type")==currentDefect;
        defectTable = failTable(rows,:);
        idx = randperm(height(defectTable));
        defectTable = defectTable(idx,:);

        %Assign minimum number of images needed per defect type within
        % validation and testing (ensures networks can be trained and
        % validated properly
        minimumVal = 4;
        minimumTest = 3;

        %Display a message indicating if a defect table has too few
        % according to the minimum number of images needed
        if height(defectTable) < minimumVal + minimumTest + 1

            warning("%s - %s has too few images.",...
                currentPart,currentDefect);
            continue

        end

        %Assign defect types for object type to the 3 different sets
        valSet = [valSet;
            defectTable(1:2,:)];
        testSet = [testSet;
            defectTable(3:4,:)];
        trainSet = [trainSet;
            defectTable(5:end,:)];
    end

end

%Take the table sets and shuffle them
trainSet = trainSet(randperm(height(trainSet)),:);
valSet = valSet(randperm(height(valSet)),:);
testSet = testSet(randperm(height(testSet)),:);


%Ensure that no duplicate images were split from one dataset to another
% (display message if they were)
allSplitFiles = [trainSet.Filename;
    valSet.Filename;
    testSet.Filename];

%Throw an error if there is
assert(numel(unique(allSplitFiles)) == height(dataSetTable), ...
    "Duplicate images were assigned to multiple splits. Try running the script again");
assert(numel(allSplitFiles) == height(dataSetTable), ...
    "One or more images are missing from the dataset splits. Try running the script again");

%Use the following for debugging if there is an error
%{
%Display contents of each set for verification of correctly allocated
% splits
disp("Training Set")
groupsummary(trainSet,...
    ["Part","Part Condition","Defect Type"])

disp("Validation Set")
groupsummary(valSet,...
    ["Part","Part Condition","Defect Type"])

disp("Testing Set")
groupsummary(testSet,...
    ["Part","Part Condition","Defect Type"])

%}

%Run function that will train the networks and store key info based on the 
% split dataset
InspectionSystem = classifyTestSuite(trainSet, valSet, dataSetTable);
%}

%========================================

%The following code creates a table that will store all of the info needed
% from the test set based on ground truths, predictions and confidence 
% scores returned from a looping of the inspectPart across all test images

%Allocate storage based on the amount of test images there are
numTestImages = height(testSet);

%Obtain Ground truth labels from test set for all images and store in
% vector
truePart = testSet.Part;
trueCondition = testSet.("Part Condition");
trueDefect = testSet.("Defect Type");


%Created a predicted labels vector for each classifier that will store the
% predicted label for each classifier for all test images
predictedPart = categorical(strings(numTestImages,1));
predictedCondition = categorical(strings(numTestImages,1));
predictedDefect = categorical(strings(numTestImages,1));

%Create confidence vector from test set for all images and store in vector
% that will store the confidence score for each tested image
partConfidence = zeros(numTestImages,1);
conditionConfidence = zeros(numTestImages,1);
defectConfidence = NaN(numTestImages,1);

%Create a vector that can store all the evidence info from the image
% processing section
numComponents = zeros(numTestImages,1);
largestArea = zeros(numTestImages,1);
areaRatio = zeros(numTestImages,1);

%Code for later use in the montage of failures

%Allocate storage to store the images classified as failure cases (this
% helps to place all images into unified place during testing so testing
% does not need to occur twice
evidenceOverlay = cell(numTestImages,1);

%Loop through all test images using inspectPart (this can be slow, so be
% patient)
for k = 1:numTestImages

    I = imread(testSet.Filename(k));

    [conditionLabel, conditionScore, partLabel, partScore, typeLabel,...
        typeScore, overlay, metrics] = inspectPart(I, InspectionSystem);

    %Store the info outputted after the function runs
    predictedPart(k) = partLabel;
    predictedCondition(k) = conditionLabel;
    predictedDefect(k) = typeLabel;

    partConfidence(k) = partScore;
    conditionConfidence(k) = conditionScore;
    defectConfidence(k) = typeScore;

    %Will go into the cell for image storage, away from final table to 
    % avoid slower program run times
    evidenceOverlay{k} = overlay;

    numComponents(k) = metrics.numComponents;
    largestArea(k) = metrics.maxArea;
    areaRatio(k) = metrics.areaRatio;

end

%Build the results table. This holds all the provided info needed for
% displaying evaluation metrics for each model after testing.
resultsTable = table(testSet.Filename, truePart, predictedPart,...
    partConfidence, trueCondition, predictedCondition,...
    conditionConfidence, trueDefect, predictedDefect, defectConfidence,...
    numComponents, largestArea, areaRatio, 'VariableNames', {'Filename',...
    'TruePart', 'PredictedPart', 'PartConfidence', 'TrueCondition',...
    'PredictedCondition', 'ConditionConfidence', 'TrueDefect',...
    'PredictedDefect', 'DefectConfidence', 'NumComponents',...
    'LargestArea', 'AreaRatio'});

%Print that the code has run successfully along with the images evaluated
% (should match the amount in testSet)
fprintf("Testing Complete\n");

fprintf("Images Evaluated : %d\n", numTestImages);

%}


%==============================================

%Begin converting predictions into confusion matrices for establishing
% metrics later

%Create structure that can be used to store the matrices for all 
% predictions based on each classifier
confusionResults = struct;

%Part Classifier: partCM tallies the part labels with truth and predication
% partOrder establishes the order the labels should be in
[partCM, partOrder] = confusionmat(resultsTable.TruePart,...
    resultsTable.PredictedPart);
confusionResults.Part.Matrix = partCM;
confusionResults.Part.ClassOrder = partOrder;

%Condition Classifier

%Obtain parts label for ground truths for per part type confusion matrices
parts = categories(resultsTable.TruePart);
confusionResults.Condition = struct;

%Obtain an Overall confusion matrix for the condition classifier
[conditionCM, conditionOrder] = confusionmat(resultsTable.TrueCondition,...
    resultsTable.PredictedCondition);


confusionResults.Condition.Overall.Matrix = conditionCM;
confusionResults.Condition.Overall.ClassOrder = conditionOrder;

%Obtain per part type confusion matrices for the condition classifier
%Loop to store a matrix for each part type based on condition
% classification
for k = 1:numel(parts)

    currentPart = parts{k};

    %Find only images belonging to passed part
    partRows = resultsTable.TruePart == currentPart;

    %Generate confusion matrix for currentParts condition network
    [conditionCM, conditionOrder] = confusionmat(...
        resultsTable.TrueCondition(partRows),...
        resultsTable.PredictedCondition(partRows));

    %Store results
    %Converts labels to usable strings for structure access
    partName = matlab.lang.makeValidName(currentPart);
    confusionResults.Condition.(partName).Matrix = conditionCM;
    confusionResults.Condition.(partName).ClassOrder = conditionOrder;

end

%Establish a matrix that has a summary for all pass/fail metrics across all
% objects
[conditionCM, conditionOrder] = confusionmat(resultsTable.TrueCondition,...
    resultsTable.PredictedCondition);


%Defect Classifier: this one never classifies pass images

confusionResults.DefectType = struct;

%Obtain an Overall confusion matrix for the defect type classifier
%Only evaluate failed images. Never output any prediction labels for a pass
% image (eliminates the label NONE)
failRows = resultsTable.TrueCondition == "FAIL" & ...
    resultsTable.PredictedCondition == "FAIL" & ...
    resultsTable.PredictedDefect ~= "NONE";

%Remove labels that contain NONE
trueLabels = removecats(resultsTable.TrueDefect(failRows));
predictedLabels = removecats(resultsTable.PredictedDefect(failRows));

[overallCM, overallOrder] = confusionmat(trueLabels, predictedLabels);

confusionResults.DefectType.Overall.Matrix = overallCM;
confusionResults.DefectType.Overall.ClassOrder = overallOrder;

%Obtain per part type confusion matrices for the defect type classifier
for k = 1:numel(parts)

    currentPart = parts{k};

    %Select only current part
    partRows = resultsTable.TruePart == currentPart;

    %Select only FAIL images for both true conditions, and predicted
    % conditions (this is because the labels assigned in the test for pass
    % images must have a label associated with it, but that label is
    % irrelevant to the defect matrices if it passes (because the defect
    % classifier never runs in inspectPart)
    failRows = partRows & resultsTable.TrueCondition == "FAIL" & ...
        resultsTable.PredictedCondition == "FAIL";

    % Remove unused categories so only the current parts defect labels 
    % remain
    trueLabels = removecats(resultsTable.TrueDefect(failRows));
    predictedLabels = removecats(resultsTable.PredictedDefect(failRows));

    %Check to see if any of the defects were classified correctly for their
    % part. If not, account for 

    %Generate confusion matrix
    [defectCM, defectOrder] = confusionmat(trueLabels, predictedLabels);

    %Store results
    %Convert to usable string (for obtaining class labels from networks)
    partName = matlab.lang.makeValidName(currentPart);
    confusionResults.DefectType.(partName).Matrix = defectCM;
    confusionResults.DefectType.(partName).ClassOrder = defectOrder;

end

%}

%=========================================


%{
%Used for debugging: displays all the class orders and confusion matrices
% to see what they contain
%Verification Display: display the confusion matrices to ensure they are
% correctly labeled

fprintf("\n---------------------------------------\n");
fprintf("CONFUSION MATRIX VERIFICATION\n");
fprintf("-----------------------------------------\n");

%Part classifier
disp(" ");
disp("----------- PART CLASSIFIER -----------")

disp("Class Order:")
disp(confusionResults.Part.ClassOrder)
disp("Confusion Matrix:")
disp(confusionResults.Part.Matrix)

%Overall Condition Classifier
disp(" ");
disp("----------- OVERALL CONDITION CLASSIFIER -----------")

disp("Class Order:")
disp(confusionResults.Condition.Overall.ClassOrder)
disp("Confusion Matrix:")
disp(confusionResults.Condition.Overall.Matrix)

%Individual Condition Classifiers
disp(" ");
disp("----------- INDIVIDUAL CONDITION CLASSIFIERS -----------")

%Store all the part types from the structure of the confusion matrices
conditionParts = fieldnames(confusionResults.Condition);

%Loop to display all confusion matrices for the condition classifier for
% each object/part type
for k = 1:numel(conditionParts)

    %Obtain current part
    currentPart = conditionParts{k};

    %Skip overall matrix
    if strcmp(currentPart,"Overall")
        continue
    end

    fprintf("\n%s Condition Classifier\n", currentPart)

    disp("Class Order:")
    disp(confusionResults.Condition.(currentPart).ClassOrder)
    disp("Confusion Matrix:")
    disp(confusionResults.Condition.(currentPart).Matrix)

end

%Overall Defect type classifier
disp(" ");
disp("----------- OVERALL DEFECT CLASSIFIER -----------")

disp("Class Order:")
disp(confusionResults.DefectType.Overall.ClassOrder)
disp("Confusion Matrix:")
disp(confusionResults.DefectType.Overall.Matrix)

%Individual defect type classifiers
disp(" ");
disp("----------- INDIVIDUAL DEFECT CLASSIFIERS -----------")

%Store all the part types from the structure of the confusion matrices
defectParts = fieldnames(confusionResults.DefectType);

for k = 1:numel(defectParts)

    currentPart = defectParts{k};

    %Skip overall matrix
    if strcmp(currentPart,"Overall")
        continue
    end


    fprintf("\n%s Defect Classifier\n", currentPart)

    disp("Class Order:")
    disp(confusionResults.DefectType.(currentPart).ClassOrder)
    disp("Confusion Matrix:")
    disp(confusionResults.DefectType.(currentPart).Matrix)

end

fprintf("\n%s\n", currentPart);

disp("True labels present:")
disp(categories(removecats(trueLabels)))

disp("Predicted labels present:")
disp(categories(removecats(predictedLabels)))

partName = matlab.lang.makeValidName(currentPart);

disp("Network classes:")
disp(InspectionSystem.DefectTypeClassifiers.(partName).Classes)


%Throw an error if NONE is found in any of the class orders
assert(all(resultsTable.TrueCondition ~= "NONE"),...
    "Unexpected NONE condition label found.");

assert(all(~ismember(confusionResults.DefectType.Overall.ClassOrder,...
    "NONE")),...
    "NONE defect class incorrectly included in defect confusion matrix.");

%}

%=====================================


%Display the confusion charts to visualize evaluation

%Display a message to separate sections
disp("=========Displaying Confusion Charts...===========")
disp(" ")

%Part Classifier

%Open figure window and display titling
figure("Name","Part Classifier Confusion Matrix");

confusionchart(confusionResults.Part.Matrix,...
    confusionResults.Part.ClassOrder, RowSummary="row-normalized",...
    ColumnSummary="column-normalized", Title="Part Classifier");

%Overall Condition Classifier (displays info for pass and fail for all
% objects)

figure("Name","Overall Condition Classifier");

confusionchart(confusionResults.Condition.Overall.Matrix,...
    confusionResults.Condition.Overall.ClassOrder, ...
    RowSummary="row-normalized", ColumnSummary="column-normalized",...
    Title="Overall Condition Classifier");

%Individual Condition Classifiers (displays info for every object types
% pass/fail labels

%Assign part names into array for displaying each individual confusion 
% matrix
conditionParts = fieldnames(confusionResults.Condition);

%Loop through all part types
for k = 1:numel(conditionParts)

    %Determine if the current matrix access is the overall matrix. Exit
    % loop if it is
    if strcmp(conditionParts{k},"Overall")
        continue
    end

    %Grab current confusion structure based on part type
    currentResult = confusionResults.Condition.(conditionParts{k});
    
    figure("Name",sprintf("%s Condition Classifier",conditionParts{k}));

    confusionchart(currentResult.Matrix, currentResult.ClassOrder,...
        RowSummary="row-normalized", ColumnSummary="column-normalized",...
        Title=sprintf("%s Condition Classifier", conditionParts{k}));

end
%}



%Overall Defect Classifier (display info for all defect types for all
% failed images)

figure("Name","Overall Defect Type Classifier");

confusionchart(confusionResults.DefectType.Overall.Matrix,...
    confusionResults.DefectType.Overall.ClassOrder,...
    RowSummary="row-normalized", ColumnSummary="column-normalized",...
    Title="Overall Defect Type Classifier");

%Individual Defect classifier (same thing as Individual Condition
% classifier, just for defect types for the specific part now)

%Assign part names into array for displaying each individual confusion 
% matrix
defectParts = fieldnames(confusionResults.DefectType);


for k = 1:numel(defectParts)

    %Determine if the current matrix access is the overall matrix. Exit
    % loop if it is
    if strcmp(defectParts{k},"Overall")
        continue
    end

    %Grab current confusion structure based on part type
    currentResult = confusionResults.DefectType.(defectParts{k});

    %Determine if the matrix for a part type is empty since it did not
    % ever get to run the defect label predictor within inspectPart (this
    % means the classifier labeled the image as PASS). Breakout of loop for
    % the object if true

    if isempty(currentResult.Matrix)
        continue
    end

    figure("Name",sprintf("%s Defect Type Classifier",defectParts{k}));
    
    confusionchart(currentResult.Matrix,...
        currentResult.ClassOrder, RowSummary="row-normalized",...
        ColumnSummary="column-normalized",...
        Title=sprintf("%s Defect Type Classifier", defectParts{k}));

end
%}


%=====================================

%Create a storage structure for storing the different accuracy, recall,
% precision, and other statistics for each classifier (part, condition,
% defect type)

metrics = struct;

%Helper function use (located at the bottom of script)
%Calculate metrics for Part Classifier Matrix
metrics.Part = calculateMetrics(confusionResults.Part.Matrix,...
    confusionResults.Part.ClassOrder);

%Calculate metrics for Condition Classifier (Overall)
metrics.Condition.Overall = calculateMetrics(...
    confusionResults.Condition.Overall.Matrix,...
    confusionResults.Condition.Overall.ClassOrder);

%Calculate metrics for Condition Classifier (individuals)
conditionParts = fieldnames(confusionResults.Condition);

for k = 1:numel(conditionParts)

    if strcmp(conditionParts{k},"Overall")
        continue
    end


    metrics.Condition.(conditionParts{k}) = calculateMetrics(...
        confusionResults.Condition.(conditionParts{k}).Matrix,...
        confusionResults.Condition.(conditionParts{k}).ClassOrder);

end

%Calculate Defect Type Classifier metrics (Overall)
metrics.DefectType.Overall = calculateMetrics(...
    confusionResults.DefectType.Overall.Matrix,...
    confusionResults.DefectType.Overall.ClassOrder);

%Calculate Defect Type Classifier metrics (Individual)
defectParts = fieldnames(confusionResults.DefectType);

for k = 1:numel(defectParts)

    if strcmp(defectParts{k},"Overall")
        continue
    end


    if isempty(confusionResults.DefectType.(defectParts{k}).Matrix)
        continue
    end

    metrics.DefectType.(defectParts{k}) = calculateMetrics(...
        confusionResults.DefectType.(defectParts{k}).Matrix,...
        confusionResults.DefectType.(defectParts{k}).ClassOrder);

end
%}


%==================================

%Create a structure for inspection metrics (yield and defect rates)
inspectionMetrics = struct;

%Calculate total inspected images for yield and defect rates
totalImages = height(resultsTable);
inspectionMetrics.TotalImages = totalImages;

%Calculate the predicted yield (what the classifier thinks passed for
% images (AKA: predictedLabels))

%Find the number of predicted pass labels and them together
predictedPass = resultsTable.PredictedCondition == "PASS";
numPredictedPass = sum(predictedPass);

%Assign prediction to structure
inspectionMetrics.PredictedPassCount = numPredictedPass;

%Calculate the predicted yield and place in structure
inspectionMetrics.PredictedYield = numPredictedPass / totalImages;

%Calculate the predicted defect rate (images the classifier thinks failed
% (same procedure as predicted yield))
predictedFail = resultsTable.PredictedCondition == "FAIL";
numPredictedFail = sum(predictedFail);
inspectionMetrics.PredictedFailCount = numPredictedFail;
inspectionMetrics.PredictedDefectRate = numPredictedFail / totalImages;

%Find the actual passing yield (based on true labels)

actualPass = resultsTable.TrueCondition == "PASS";
numActualPass = sum(actualPass);
inspectionMetrics.ActualPassCount = numActualPass;
inspectionMetrics.ActualYield = numActualPass / totalImages;

%Find the actual defect rate
actualFail = resultsTable.TrueCondition == "FAIL";
numActualFail = sum(actualFail);
inspectionMetrics.ActualFailCount = numActualFail;
inspectionMetrics.ActualDefectRate = numActualFail / totalImages;

%USED FOR ROBUSTNESS TEST

%Find the false accept rates for pass/fail
falseAccept = resultsTable.TrueCondition == "FAIL" & ...
    resultsTable.PredictedCondition == "PASS";

inspectionMetrics.FalseAcceptCount = sum(falseAccept);

inspectionMetrics.FalseAcceptRate = sum(falseAccept) / numActualFail;

%Find the false reject rates for pass/fail
falseReject = resultsTable.TrueCondition == "PASS" & ...
    resultsTable.PredictedCondition == "FAIL";

inspectionMetrics.FalseRejectCount = sum(falseReject);

inspectionMetrics.FalseRejectRate = sum(falseReject) / numActualPass;

%Display a table full of the summaries for the yield and defect rates
rateTable = table(...
    ["Actual"; "Predicted"],...
    [
    inspectionMetrics.ActualYield*100;
    inspectionMetrics.PredictedYield*100
    ],...
    [
    inspectionMetrics.ActualDefectRate*100;
    inspectionMetrics.PredictedDefectRate*100
    ], 'VariableNames', {'Inspection Type','Yield Rate (%)',...
    'Defect Rate (%)'});

disp("==========================================")
disp("Yield and Defect Rate Table")
disp("==========================================")

disp(rateTable)
disp(" ")

%Plot the yield and defect rates

%Establish figure for creating plot to display
figure("Name","Inspection Yield and Defect Rate Summary",...
    "Color","black");

%Place the data in an array 
rateData = [
    inspectionMetrics.ActualYield*100,...
    inspectionMetrics.PredictedYield*100;

    inspectionMetrics.ActualDefectRate*100,...
    inspectionMetrics.PredictedDefectRate*100
    ];

%Establish bar graph for the rates
bar(rateData)

%Establish features/labels of the figure for the plot
grid on
ylabel("Percentage (%)")
title("Inspection Yield and Defect Rate Comparison")
xticklabels({"Yield Rate" "Defect Rate"})
legend({"Actual" "Predicted"}, "Location","northoutside",...
    "Orientation","horizontal")
ylim([0 100])

%Add values above bars (shows percentage for 
textPositions = rateData;

%Loop to establish the position of text on the figure
for row = 1:size(rateData,1)
    for col = 1:size(rateData,2)

        text(row + (col-1)*0.15, rateData(row,col)+2, ...
            sprintf("%.1f%%",rateData(row,col)),...
            "HorizontalAlignment","right","FontSize",10)

    end

end

%Create a table for the false accept and reject rates, along with its
% accuracy (measures performance of the condition classifier

%Obtain overall condition classifier accuracy
conditionAccuracy = ...
    metrics.Condition.Overall.Properties.UserData.Accuracy;

%Create summary table
conditionPerformanceTable = table(["Accuracy";"False Accept Rate";
     "False Reject Rate"], [conditionAccuracy;
     inspectionMetrics.FalseAcceptRate;
     inspectionMetrics.FalseRejectRate] * 100, 'VariableNames',...
    {'Metric','Value (%)'});

disp(" ")
disp("========= Overall Condition Classifier Performance =========")
disp(conditionPerformanceTable)
disp(" ")

%ROBUSTNESS TEST IMPORTANCE
%Plot summary table for false accept and rejects with accuracy

figure("Name","Overall Condition Classifier Performance",...
    "NumberTitle","off");

%Extract values from 'Values'
performanceValues = conditionPerformanceTable.("Value (%)");

%Establish plot
b = bar(performanceValues, "FaceColor",[0.2 0.55 0.85]);

%Edit plot settings
grid on
box on
xticks(1:height(conditionPerformanceTable))
xticklabels(conditionPerformanceTable.Metric)
ylabel("Percentage (%)")
xlabel("Performance Metric")
title("Overall Condition Classifier Robustness Performance")
ylim([0 100])

%Display value above each bar
for k = 1:numel(performanceValues)

    text(k,...
        performanceValues(k)+1, sprintf("%.2f%%", performanceValues(k)),...
        "HorizontalAlignment", "center", "FontWeight", "bold");

end


%==========================

%}

%Begin creating montage output of failures of the inspection system. 
% Failures deemed based on the following:

%Incorrect part label
%Incorrect condition label
%Incorrect defect label (when it is determined to be a successful FAIL)
%Low confidence threshold for each classifier

%Define confidence thresholds based on classifier
partThreshold = 0.95;
conditionThreshold = 0.88;
defectThreshold = 0.80;

%Create a logical vector that will to evaluate predictions that are
% considered failures (sued to access failing images from results table)
partFailure = resultsTable.TruePart ~= resultsTable.PredictedPart;

conditionFailure = resultsTable.TrueCondition ~= ...
    resultsTable.PredictedCondition;

%Determine which type of failures to evaluate for defect type (this is due
% to the defect classifier only running when condition classifier predicts
% FAIL (found in inspectPart)
defectEvaluated = resultsTable.PredictedCondition == "FAIL";
defectFailure = false(height(resultsTable),1);
defectFailure(defectEvaluated) = ...
    resultsTable.TrueDefect(defectEvaluated) ~= ...
    resultsTable.PredictedDefect(defectEvaluated);

%Establish vector that stores logical values based on whether an image has
% that the classifier predicted has a lower confidence value than the
% threshold
lowPartConfidence = resultsTable.PartConfidence < partThreshold;

lowConditionConfidence = resultsTable.ConditionConfidence...
    < conditionThreshold;

%Establish vector that will ignore pass images and store logical values of
% for which images in the test set had low confidence score compared to
% threshold for defect type classifier
lowDefectConfidence = false(height(resultsTable),1);
lowDefectConfidence(defectEvaluated) = ...
    resultsTable.DefectConfidence(defectEvaluated) < defectThreshold;

%Create an array that will store the reasons for why a classification of
% an image is considered a failure
failureReason = strings(height(resultsTable),1);

%Loop to place reasons in array (there can be multiple reasons (such as
% incorrect defect label, along with low defect confidence (both of these 
% are true)) where the reasons will be placed together for later access)
for k = 1:height(resultsTable)

    %Establish string array that will merge with failureReason to store all
    % message types
    reasons = strings(0);

    if partFailure(k)
        reasons(end+1) = "Incorrect Part";
    end

    if conditionFailure(k)
        reasons(end+1) = "Incorrect Condition";
    end

    if defectFailure(k)
        reasons(end+1) = "Incorrect Defect";
    end

    if lowPartConfidence(k)
        reasons(end+1) = "Low Part Confidence";
    end

    if lowConditionConfidence(k)
        reasons(end+1) = "Low Condition Confidence";
    end

    if lowDefectConfidence(k)
        reasons(end+1) = "Low Defect Confidence";
    end

    failureReason(k) = strjoin(reasons,", ");

end

%Determine if an image is a failure
isFailure = partFailure | conditionFailure | defectFailure | ...
    lowPartConfidence | lowConditionConfidence | lowDefectConfidence;

%Assign variables to structure of the evaluation results table
resultsTable.PartFailure = partFailure;
resultsTable.ConditionFailure = conditionFailure;
resultsTable.DefectFailure = defectFailure;

resultsTable.LowPartConfidence = lowPartConfidence;
resultsTable.LowConditionConfidence = lowConditionConfidence;
resultsTable.LowDefectConfidence = lowDefectConfidence;

resultsTable.FailureReason = failureReason;
resultsTable.IsFailure = isFailure;

%Create failure table. This table stores the images that need
% "review" based on a reason (the reasons found in the array above). Place
% the layout in ascending order 

failureTable = resultsTable(resultsTable.IsFailure,:);

%Add review order (used to number the tiles for montage of failure of
% cases)
failureTable.ReviewNumber = (1:height(failureTable)).';

%Sort the table for prioritizing the weakest images based on confidence
% score (eliminates the possibility of many images being deployed in a
% montage if there are a lot of failures below the confidence thresholds)
failureTable.MinimumConfidence = min([failureTable.PartConfidence,...
    failureTable.ConditionConfidence, failureTable.DefectConfidence],[],2);

failureTable = sortrows(failureTable, "MinimumConfidence","ascend");

%Establish a failure montage (without using montage so reasons for why can 
% be listed underneath each set of images (these sets contain the original 
% and overlayed images))

numFailures = height(failureTable);

disp(" ")
disp("==========Generating Failure Montage...========")
disp(" ")

%Loop to display the layout in tiles
for k = 1:numFailures

    %Read original mage
    originalImage = imread(failureTable.Filename(k));

    %Generate overlay
    [~,~,~,~,~,~,overlayImage,~] = ...
        inspectPart(originalImage,InspectionSystem);

    %Determine confidence and label to display (based on reason text). 
    % Initial one is condition confidence/label  if no other 
    % confidence/label is determined to be a fail reason
    labelType = "Condition";
    trueLabelDisplay = string(failureTable.TrueCondition(k));
    predictedLabelDisplay = string(failureTable.PredictedCondition(k));

    confidenceType = "Condition";
    confidenceValue = failureTable.ConditionConfidence(k);

    reasonText = string(failureTable.FailureReason(k));

    %Determine if the reason for failure is related to the label prediction
    if contains(reasonText,"Incorrect Part")

        labelType = "Part";
        trueLabelDisplay = string(failureTable.TruePart(k));
        predictedLabelDisplay = string(failureTable.PredictedPart(k));

    elseif contains(reasonText,"Incorrect Condition")

        labelType = "Condition";
        trueLabelDisplay = string(failureTable.TrueCondition(k));
        predictedLabelDisplay = string(failureTable.PredictedCondition(k));

    elseif contains(reasonText,"Incorrect Defect")

        labelType = "Defect";
        trueLabelDisplay = string(failureTable.TrueDefect(k));
        predictedLabelDisplay = string(failureTable.PredictedDefect(k));

    end

    %Determine if the reason for failure is related to the condition 
    % prediction
    if failureTable.LowPartConfidence(k)

        confidenceType = "Part";
        confidenceValue = failureTable.PartConfidence(k);

    elseif failureTable.LowConditionConfidence(k)

        confidenceType = "Condition";
        confidenceValue = failureTable.ConditionConfidence(k);

    elseif failureTable.LowDefectConfidence(k)

        confidenceType = "Defect";
        confidenceValue = failureTable.DefectConfidence(k);

    end
    
    %Generate figure for each photo comparison of failure cases
    figure("Name",sprintf("Failure Review %d",k), "Color","black");

    tiledlayout(1,2, "TileSpacing","compact", "Padding","compact");

    %Display original image
    nexttile
    imshow(originalImage)
    title("Original Image")

    %Display overlay image
    nexttile
    imshow(overlayImage)
    title("Evidence Overlay")

    %Figure titling (with reasons, labels, and scores)
    titleText = compose("Failure Review %d\n" + "Reason: %s\n" + ...
    "True %s: %s\n" + "Predicted %s: %s\n" + "%s Confidence: %.3f", ...
    failureTable.ReviewNumber(k), reasonText, labelType, ...
    trueLabelDisplay, labelType, predictedLabelDisplay, confidenceType, ...
    confidenceValue);

    sgtitle(titleText, "FontWeight","bold", "FontSize", 8);

end




%=====================================

%Helper functions

%This function calculates precision, recall, and accuracy for each
%different confusion matrix (so for each object type and overall matrices)
function metricTable = calculateMetrics(confusionMatrix, classOrder)

    %Convert matrix to double to be able to obtain numbers for calculations
    CM = double(confusionMatrix);

    %Number of classes/labels for the matrix at hand
    numClasses = size(CM,1);


    %Initialize arrays for each calculation
    precision = zeros(numClasses,1);
    recall = zeros(numClasses,1);

    %Loop across all class types to obtain their confusion matrix stats
    for i = 1:numClasses

        %True positives
        TP = CM(i,i);

        %False positives
        FP = sum(CM(:,i))-TP;

        %False negatives
        FN = sum(CM(i,:))-TP;


        %Precision calculation
        if TP+FP == 0
            precision(i)=0;
        else
            precision(i)=TP/(TP+FP);
        end


        %Recall calculation
        if TP+FN == 0
            recall(i)=0;
        else
            recall(i)=TP/(TP+FN);
        end

    end


    %Overall accuracy for matrix
    accuracy = trace(CM)/sum(CM,"all");


    %Create table for the confusion matrix type
    metricTable = table(classOrder, precision, recall,...
    'VariableNames', ["Class","Precision","Recall"]);

    %Add accuracy as additional property (cant go in table because it
    % doesn't have the same row numbers as the other variables
    metricTable.Properties.UserData.Accuracy = accuracy;

end
%}


%}
