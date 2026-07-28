function [bo_maskEvidence, evidence, bo_roi, bo_roiRGB, bo_overlay] = inspectBottle(bo_img)

% NOTE: bo = bottle
% This function inspects one bottle image at a time.
% Designed for broken_large and broken_small defects.

% ---------- STEP 1 - STANDARDIZE THE IMAGE ----------

% Standardize image size so classical masks and metrics are consistent.
classicalSize = [224 224];

bo_standard = imresize(bo_img, classicalSize);

% Convert standardized image to grayscale.
bo_gray = rgb2gray(bo_standard);

% ---------- STEP 2 - PREPROCESS THE IMAGE ----------

% Fairly consistent lighting, so no lighting correction is needed.

% Mild denoising.
bo_denoise = imgaussfilt(bo_gray, 0.5);

% ---------- STEP 3 - DEFINE A REGION OF INTEREST ----------

% Bottle is centered with minimal clutter, so use full image as the ROI.
bo_roi = bo_denoise;
bo_roiRGB = bo_standard;

% ---------- STEP 4 - SEGMENT THE IMAGE ----------

% Get the number of rows and columns in the ROI.
% --> finds the dimensions of the grayscale ROI.
% --> [224, 224]
[numRows, numCols] = size(bo_roi);

% Create x- and y-coordinate matrices for the image.
[x, y] = meshgrid(1:numCols, 1:numRows);

% Calculate the center coordinates of the image/bottle's center.
centerX = (numCols + 1) / 2;
centerY = (numRows + 1) / 2;

% Calculate each pixel's distance from the image center.
% --> distance formula to determine how far every pixel is from the center.
% --> horizontal distance = x - centerX.
% --> vertical distance = y - centerY.
radius = sqrt((x - centerX).^2 + (y - centerY).^2);

% Use a fixed ring because the resized bottle is consistently centered.
% --> creates a logical mask containing only pixels whose distance from the
%     center is between 42 and 78 pixels.
bo_ringMask = radius >= 42 & radius <= 78;

% Calculate local standard deviation around every pixel in a 7-by-7 neighborhood.
% --> for each pixel, MATLAB examines the surrounding 7 x 7 group of pixels
%     and measures how much their intensities vary.
bo_stdImg = stdfilt(bo_roi, true(7)); % NOTE: Smooth regions have low standard deviation and appear dark.
                                      %       Edges, texture, reflections, and damaged areas have high standard deviation and appear bright.
                                      %       The goal is to make irregular broken regions stand out through their local texture.

% Scale the standard-deviation image from 0 to 1.
% --> makes image easier to threshold consistently.
bo_stdImg = mat2gray(bo_stdImg);

% Create an adaptive threshold for bright texture variation.
T = adaptthresh(bo_stdImg, 0.55, "ForegroundPolarity", "bright");

% Convert the texture image into a binary evidence mask.
% --> compares every pixel in bo_stdImg with its corresponding threshold
%     in T
% --> when the local standard deviation is greater than the threshold, the
%     result becomes true and appears white.
bo_maskEvidence = imbinarize(bo_stdImg, T);

% Keep evidence only within the bottle-rim region.
bo_maskEvidence = bo_maskEvidence & bo_ringMask;

% Removes connected white regions containing fewer than 10 pixels.
bo_maskEvidence = bwareaopen(bo_maskEvidence, 10);

% Connect nearby evidence regions.
bo_maskEvidence = imclose(bo_maskEvidence, strel("disk", 2));

% ---------- CREATE RED EVIDENCE OVERLAY ----------

bo_overlay = imoverlay(bo_roiRGB, bo_maskEvidence, "red");

% ---------- STEP 5 - EXTRACT INTERPRETABLE METRICS ----------

% Count the number of separate suspicious regions.
connectedRegions = bwconncomp(bo_maskEvidence);
evidence.numComponents = connectedRegions.NumObjects;

% Find the size of the largest suspicious region.
areaStats = regionprops(bo_maskEvidence, "Area");

if isempty(areaStats)
    evidence.maxArea = 0;
else
    evidence.maxArea = max([areaStats.Area]);
end

% Fraction of the ROI flagged as suspicious.
evidence.areaRatio = nnz(bo_maskEvidence) / numel(bo_maskEvidence);

end
