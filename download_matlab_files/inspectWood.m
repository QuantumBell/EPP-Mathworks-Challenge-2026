function [wo_maskEvidence, evidence, wo_roi, wo_roiRGB, wo_overlay] = inspectWood(wo_img, defectType)

% Convert AI classifier label to a string for the switch statement.
defectType = lower(string(defectType));

% ---------- STEP 1 - STANDARDIZE THE IMAGE ----------

% Standardize image size so classical masks and metrics are consistent.
classicalSize = [224 224];

wo_standard = imresize(wo_img, classicalSize);

% ---------- STEP 2 - PREPROCESS THE IMAGE ----------

% Fairly consistent lighting, so no lighting correction is needed.

% Convert the RGB wood image to Lab color space.
wo_lab = rgb2lab(wo_standard);

% Extract the L channel, which represents lightness.
% --> contains one brightness value per pixel.
% --> can be displayed like a grayscale image.
wo_L = wo_lab(:,:,1);

% Scale lightness values from 0 to 1.
% --> places the values in the standard intensity range.
wo_L = mat2gray(wo_L);

% Mildly smooth the lightness channel.
% --> reduces small wood-grain fluctuations and noise.
wo_roi = imgaussfilt(wo_L, 0.5);

% ---------- STEP 3 - DEFINE A REGION OF INTEREST ----------

% Wood fills the whole image, so no cropping is needed.
% --> use the full processed image and full RGB image as the ROI
wo_roiRGB = wo_standard;

% ---------- STEP 4 - SEGMENT THE IMAGE ----------

switch defectType

  case {"hole_wood", "liquid"}

    % Detect regions darker than their local surroundings.
    T = adaptthresh(wo_roi, 0.35, "ForegroundPolarity", "dark");

    % Invert because darker pixels should become white evidence.
    wo_maskEvidence = ~imbinarize(wo_roi, T);

    % Reduce long, thin vertical wood-grain responses.
    wo_maskEvidence = imopen(wo_maskEvidence, strel("line", 3, 0));

    % Remove very small regions.
    wo_maskEvidence = bwareaopen(wo_maskEvidence, 5);

    % Connect nearby parts of the same defect.
    wo_maskEvidence = imclose(wo_maskEvidence, strel("disk", 2));

  case "scratch"

    % Detect bright scratch regions relative to their surroundings.
    T = adaptthresh(wo_roi, 0.35, "ForegroundPolarity", "bright");

    wo_maskEvidence = imbinarize(wo_roi, T);

    % Remove small isolated responses.
    wo_maskEvidence = bwareaopen(wo_maskEvidence, 10);

    % Connect nearby scratch fragments.
    wo_maskEvidence = imclose(wo_maskEvidence, strel("disk", 1));

  otherwise

    error("Unsupported wood defect type: %s", defectType);
end

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
