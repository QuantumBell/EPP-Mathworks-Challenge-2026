%This function utilizes area metrics to distinguish where the defect is in a Grid.
%I always used the median, and decided to stray away from using the mean, since it was unreliable.

function [metrics, red_overlay] = inspectGrid(img, defectType)
defectType = lower(string(defectType));

switch defectType
%For a grid with breaks, these breaks will allow to holes to conjoin together, ultimately creating a bigger area.
%We can then look for these abnormally     bigger holes, and mask them as defects.
    case{"broken"}
        se = strel('disk', 7);
        closedse = strel('disk', 3);
        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        %Always clear the border, holes on the edges skew and mess with the calculations due to their abnormal sizes.
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        % Calculate a reliable measure of area variation using the median absolute deviation.
        % The factor 1.4826 scales MAD to approximate the standard deviation for normal data.
        scale = 1.4826 * mad(area, 1);

        upperCutoff = medArea + 3*scale;
        selection = area > upperCutoff;
        %Create the mask, this keeps only the defect areas in the image.
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");

    case{"glue"}
%To detect if there is glue, we look for smaller than normal holes. 
%Having glue on the grid makes the holes a bit smaller than normal, using this, we can look for defects.
        se = strel('disk', 10);
        closedse = strel('disk', 5);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        %Always clear the border, holes on the edges skew and mess with the calculations due to their abnormal sizes.
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        stdArea = std(area);
        %Here we subtract the median, from the std deviation, using 1.5 as a scalar.The lower this number is , the more sensitive and picky it is.
        %1.5 Isn't a magic number, just the number I decided to use after multiple trial and errors.
        areaCutoff = medArea - (1.5 * stdArea);
        selection = (area < areaCutoff);
        %Create the mask, this keeps only the defect areas in the image.
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");

    case{"metal_contamination"}
    %Similar to the glue, having metal contamination near the holes results in a much smaller hole than usual.
    
        se = strel('disk', 7);
        closedse = strel('disk', 3);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
         %Always clear the border, holes on the edges skew and mess with the calculations due to their abnormal sizes.
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        stdArea = std(area);
        %We subtract 2.5 times the standard deviation from the median area to create a lower area threshold.
        areaCutoff = medArea - (2.5 * stdArea);
        selection = (area < areaCutoff);
        %Create the mask, this keeps only the defect areas in the image.
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");


    case{"thread"}
    %This one was tricky, I could not clear the border because the thread sometimes extends from two edges of the image.
    %I used simple morphological operations, opening and closing, and adjusted the structuring element sizes to pinpoint where the thread is.
    %This works for MOST of the images, however on one or two, it struggles a bit. (Still detects the fault, but with slight noise in the area around it)
        se1 = strel('disk', 20);
        se2 = strel('disk', 18);
        finalimg = imbinarize(img);
        img_inv = ~finalimg;
        finalimg = imopen(img_inv , se1);
        BW2 = imclose(finalimg, se2);


        red_overlay = imoverlay(img, finalimg, "red");

    case{"bent"}
    %A bent grid, also creates bigger holes, because if one hole is bent, this means the hole adjacent to it will have its size altered.
        se = strel('disk', 10);
        closedse = strel('disk', 5);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        %Always clear the border, holes on the edges skew and mess with the calculations due to their abnormal sizes.
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;
        
        medArea = median(area);
        stdArea = std(area);
        %Here we check for larger than normal holes.
        %We add 1.8 times the standard deviation to the median area to create a higher area threshold.
        areaCutoff = medArea + (1.8 * stdArea);
        selection = (area > areaCutoff);
        %Create the mask, this keeps only the defect areas in the image.
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");



    otherwise
        warning("Unrecognized defect type: '%s'. Returning empty defect mask.", defectType);

end

%Metrics for the images, this includes what the biggest defect area was, the number of regions, and the ratio.
connectedRegions = bwconncomp(BW2);
metrics.numComponents = connectedRegions.NumObjects;

areaStats = regionprops(BW2, "Area");

if isempty(areaStats)
    metrics.maxArea = 0;
else
    metrics.maxArea = max([areaStats.Area]);
end

metrics.areaRatio = nnz(BW2) / numel(BW2);

end
