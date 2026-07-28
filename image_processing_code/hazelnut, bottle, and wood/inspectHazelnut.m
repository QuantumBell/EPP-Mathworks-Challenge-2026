function [hz_maskEvidence, evidence, hz_roi, hz_roiRGB, hz_overlay] = inspectHazelnut(hz_img)

% NOTE: hz = hazelnut
% This function inspects one hazelnut image at a time.

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

% Designed for dark crack and hole defects.
T = adaptthresh(hz_roi, 0.40, "ForegroundPolarity", "dark");

hz_testMask = ~imbinarize(hz_roi, T);

% Remove the hazelnut outer outline.
hz_testMask = imclearborder(hz_testMask);

% Remove small pieces of normal texture.
hz_testMask = bwareaopen(hz_testMask, 25);

% Connect small gaps in the defect.
hz_testMask = imclose(hz_testMask, strel("disk", 2));

% Thicken the detected defect so it becomes a filled white region.
hz_maskEvidence = imdilate(hz_testMask, strel("disk", 1));

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
