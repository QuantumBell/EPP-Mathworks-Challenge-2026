function [conditionLabel, conditionConfidenceScore,...
    partLabel, partConfidence, typeLabel, typeConfidence, evidenceOverlay,...
    evidenceMetrics] = inspectPart(I, inspectionStruc)
%inspectPart Function that incorporates the entire image inspection system
%   This function takes an image, and structure of classifiers (which comes
%   from the live script or "classifyTestSuite") as input, and outputs a
%   label for each classifier along with a confidence score, and the
%   evidence overlay and metrics to support it if the image inserted is
%   classified as FAIL
arguments (Input)
    I
    inspectionStruc
end

arguments (Output)
    conditionLabel
    conditionConfidenceScore
    partLabel
    partConfidence
    typeLabel
    typeConfidence
    evidenceOverlay
    evidenceMetrics
end
    %Classify part type
    [partLabel, partConfidence] = classifyImg(I,...
        inspectionStruc.PartClassifier);

    %Classify condition (pass/fail)
    [conditionLabel, conditionConfidenceScore] = classifyImg(I,...
        inspectionStruc.ConditionClassifiers.(string(partLabel)));


    %Determine function to run
if lower(string(conditionLabel)) == "fail"

    %Classify defect type
    [typeLabel, typeConfidence] = classifyImg(I,...
        inspectionStruc.DefectTypeClassifiers.(string(partLabel)));

        % Run the matching classical image-processing function.

        switch lower(string(partLabel))

            case "hazelnut"
                [~, evidenceMetrics, ~, ~, evidenceOverlay] = ...
                    inspectHazelnut(I, typeLabel);

            case "wood"
                [~, evidenceMetrics, ~, ~, evidenceOverlay] = ...
                    inspectWood(I, typeLabel);

            case "bottle"
                [~, evidenceMetrics, ~, ~, evidenceOverlay] =...
                    inspectBottle(I);

            case "grid"
                [evidenceMetrics, evidenceOverlay] =...
                    InspectGrid(I, typeLabel);

            otherwise
                error("Unsupported part type: %s", string(partLabel));
        end

else

    % No defect evidence is needed for a passing image.
    typeLabel = categorical("NONE");
    typeConfidence = 1;
    evidenceOverlay = I;

    evidenceMetrics.numComponents = 0;
    evidenceMetrics.maxArea = 0;
    evidenceMetrics.areaRatio = 0;

end
end

