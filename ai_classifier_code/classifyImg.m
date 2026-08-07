function [aiLabel, aiConfidence] =...
    classifyImg(img, classifierStruct)
%classifyImg Function that takes a structure of networks and classifies an image
%   Will output the label, confidence (max score) with inputs being object
%   for InspectionSystem structure, and the image to be classified
arguments (Input)
    img
    classifierStruct
end

arguments (Output)
    aiLabel
    aiConfidence
end
    
    %Reassign img to I
    I = img;

    %Use code to convert grayscale to RGB if needed
    if size(I,3) == 1
        I = repmat(I,[1 1 3]);
    end

    %Determine input size needed
    neededSize = classifierStruct.Network.Layers(1).InputSize(1:2);

    %Resize Image
    I = imresize(I, neededSize);

    %Convert image to array format for network
    IArray = dlarray(single(I), "SSCB");

    %Obtain scores
    aiScores = minibatchpredict(classifierStruct.Network, IArray);

    %Use if needed to convert to MATLAB array
    %{
    aiScores = extractdata(aiScores);
    %}

    %Find highest score for label output
    [aiConfidence, idx] = max(aiScores);

    %Obtain label
    aiLabel = classifierStruct.Classes(idx); 
end