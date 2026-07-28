function [wo_maskEvidence, evidence, wo_roi, wo_roiRGB, wo_overlay] = inspectWood(wo_img)

% ---------- STEP 1 - STANDARDIZE THE IMAGE ----------

% Standardize image size so classical masks and metrics are consistent.
classicalSize = [224 224];

wo_standard = imresize(wo_img, classicalSize);

% Convert standardized image to grayscale.
wo_gray = rgb2gray(wo_standard);

% ---------- STEP 2 - PREPROCESS THE IMAGE ----------

% Fairly consistent lighting, so no lighting correction is needed.

% Mild denoising.
wo_denoise = imgaussfilt(wo_gray, 0.5);

% ---------- STEP 3 - DEFINE A REGION OF INTEREST ----------

% Wood fills the image with minimal clutter, so use the full image as the ROI.
wo_roi = wo_denoise;
wo_roiRGB = wo_standard;

% ---------- STEP 4 - SEGMENT THE IMAGE ----------

% Convert the RGB wood image to Lab color space.
wo_lab = rgb2lab(wo_roiRGB);

% Extract the L channel, which represents lightness.
wo_L = wo_lab(:,:,1);

% Scale lightness values from 0 to 1.
% --> makes image easier to use with thresholding functions.
wo_L = mat2gray(wo_L);

% Mildly smooth the lightness channel.
% --> reduces tiny wood-grain fluctuations and noise before thresholding.
wo_L = imgaussfilt(wo_L, 0.5);

% Detect regions darker than their local surroundings.
T = adaptthresh(wo_L, 0.35, "ForegroundPolarity", "dark");

% Invert because darker pixels should become white evidence.
wo_maskEvidence = ~imbinarize(wo_L, T);

% Reduce long, thin vertical wood-grain responses.
wo_maskEvidence = imopen(wo_maskEvidence, strel("line", 3, 0));

% Remove very small regions.
wo_maskEvidence = bwareaopen(wo_maskEvidence, 5);

% Connect nearby parts of the same defect.
wo_maskEvidence = imclose(wo_maskEvidence, strel("disk", 2));

% ---------- CREATE RED EVIDENCE OVERLAY ----------

wo_overlay = imoverlay(wo_roiRGB, wo_maskEvidence, "red");

% ---------- STEP 5 - EXTRACT INTERPRETABLE METRICS ----------

% Count the number of separate suspicious regions.
connectedRegions = bwconncomp(wo_maskEvidence);
evidence.numComponents = connectedRegions.NumObjects;

% Find the size of the largest suspicious region.
areaStats = regionprops(wo_maskEvidence, "Area");

if isempty(areaStats)
    evidence.maxArea = 0;
else
    evidence.maxArea = max([areaStats.Area]);
end

% Fraction of the ROI flagged as suspicious.
evidence.areaRatio = nnz(wo_maskEvidence) / numel(wo_maskEvidence);

end
