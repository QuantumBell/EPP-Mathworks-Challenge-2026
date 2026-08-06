

function [metrics, red_overlay] = inspectGrid(img, defectType)
defectType = lower(string(defectType));

switch defectType

    case{"broken"}
        se = strel('disk', 7);
        closedse = strel('disk', 3);
        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        scale = 1.4826 * mad(area, 1);

        upperCutoff = medArea + 3*scale;
        selection = area > upperCutoff;
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");

    case{"glue"}

        se = strel('disk', 10);
        closedse = strel('disk', 5);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        stdArea = std(area);
        areaCutoff = medArea - (1.5 * stdArea);
        selection = (area < areaCutoff);
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");

    case{"metal_contamination"}
        
        se = strel('disk', 7);
        closedse = strel('disk', 3);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        stdArea = std(area);
        areaCutoff = medArea - (2.5 * stdArea);
        selection = (area < areaCutoff);
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");


    case{"thread"}

        se1 = strel('disk', 20);
        se2 = strel('disk', 18);
        finalimg = imbinarize(img);
        img_inv = ~finalimg;
        finalimg = imopen(img_inv , se1);
        BW2 = imclose(finalimg, se2);


        red_overlay = imoverlay(img, finalimg, "red");

    case{"bent"}
        se = strel('disk', 10);
        closedse = strel('disk', 5);

        binarizedimage = imbinarize(img);

        BW = imdilate(binarizedimage, strel('disk',1));
        openimage = imopen(BW, se);
        filledimage = imfill(openimage, "holes");
        closedimage = imclose(filledimage,closedse);
        finalImg = imfill(closedimage, "holes");
        holes = imclearborder(finalImg);
        CC = bwconncomp(holes);
        stats = regionprops("table", CC, "Area", "BoundingBox");
        area = stats.Area;

        medArea = median(area);
        stdArea = std(area);
        areaCutoff = medArea + (1.8 * stdArea);
        selection = (area > areaCutoff);
        BW2 = cc2bw (CC, ObjectsToKeep = selection);
        red_overlay = imoverlay(img, BW2, "red");



    otherwise
        warning("Unrecognized defect type: '%s'. Returning empty defect mask.", defectType);

end

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
