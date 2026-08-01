function [hz_maskEvidence, evidence, hz_roi, hz_roiRGB, hz_overlay] = inspectHazelnut(hz_img, defectType)

% NOTE: hz = hazelnut
% This function inspects one hazelnut image at a time.

% Convert AI label to a string for the switch statement.
defectType = lower(string(defectType));

% ---------- STEP 1 - STANDARDIZE THE IMAGE ----------

% Standardize image size so classical masks and metrics are consistent.
classicalSize = [224 224];

hz_standard = imresize(hz_img, classicalSize);

% Convert standardized image to grayscale.
hz_gray = rgb2gray(hz_standard);

% ---------- STEP 2 - PREPROCESS THE IMAGE ----------

% Fairly consistent lighting, so no lighting correction is needed.

% Mild denoising.
hz_denoise = imgaussfilt(hz_gray, 0.5);

% ---------- STEP 3 - DEFINE A REGION OF INTEREST ----------

% Fixed crop used for every hazelnut image.
% Format: [x, y, width, height]
roiPosition = [40, 30, 145, 165];

hz_roi = imcrop(hz_denoise, roiPosition);
hz_roiRGB = imcrop(hz_standard, roiPosition);

% ---------- STEP 4 - SEGMENT THE IMAGE ----------

switch defectType

 case {"crack", "hole"}

    % Designed for dark crack and hole defects.
    T = adaptthresh(hz_roi, 0.40, "ForegroundPolarity", "dark");

    hz_maskEvidence = ~imbinarize(hz_roi, T);

    % Remove the hazelnut outer outline.
    hz_maskEvidence = imclearborder(hz_maskEvidence);

    % Remove small pieces of normal texture.
    hz_maskEvidence = bwareaopen(hz_maskEvidence, 25);

    % Connect small gaps in the defect.
    hz_maskEvidence = imclose(hz_maskEvidence, strel("disk", 2));

  case {"cut", "print"}

    % Designed for bright cut and print defects.
    T = adaptthresh(hz_roi, 0.45, "ForegroundPolarity", "bright");

    hz_maskEvidence = imbinarize(hz_roi, T);

    % Create a rough hazelnut mask.
    hz_partMask = hz_roi > 45;
    hz_partMask = bwareafilt(hz_partMask, 1);
    hz_partMask = imfill(hz_partMask, "holes");

    % Exclude the outer shell boundary.
    hz_innerMask = imerode(hz_partMask, strel("disk", 8));

    hz_maskEvidence = hz_maskEvidence & hz_innerMask;

    % Remove small highlights.
    hz_maskEvidence = bwareaopen(hz_maskEvidence, 15);

    % Connect nearby evidence.
    hz_maskEvidence = imclose(hz_maskEvidence, strel("disk", 2));

  otherwise

    error("Unsupported hazelnut defect type: %s", defectType);

end

% Thicken the detected defect so it becomes a filled white region.
hz_maskEvidence = imdilate(hz_maskEvidence, strel("disk", 1));

% ---------- CREATE RED EVIDENCE OVERLAY ----------

hz_overlay = imoverlay(hz_roiRGB, hz_maskEvidence, "red");

% ---------- STEP 5 - EXTRACT INTERPRETABLE METRICS ----------

% Count the number of separate suspicious regions.
connectedRegions = bwconncomp(hz_maskEvidence);
evidence.numComponents = connectedRegions.NumObjects;

% Find the size of the largest suspicious region.
areaStats = regionprops(hz_maskEvidence, "Area");

if isempty(areaStats)
    evidence.maxArea = 0;
else
    evidence.maxArea = max([areaStats.Area]);
end

% Fraction of the ROI flagged as suspicious.
evidence.areaRatio = nnz(hz_maskEvidence) / numel(hz_maskEvidence);

end
