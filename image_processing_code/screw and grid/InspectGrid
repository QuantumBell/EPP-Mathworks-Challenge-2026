function [metrics, redOverlay] = inspectGrid(img, defectType)


    se = strel('disk', 7);
    closedse = strel('disk', 3);
    defectType = lower(string(defectType));

    rawImg = imread(img);

    binarizedimage = imbinarize(rawImg);

    BW = imdilate(binarizedimage, strel('disk',1));
    openimage = imopen(BW, se);
    filledimage = imfill(openimage, "holes");
    closedimage = imclose(filledimage,closedse);
    finalImg = imfill(closedimage, "holes");
    holes = imclearborder(finalImg);
    CC = bwconncomp(holes);
    stats = regionprops("table", CC, "Area", "BoundingBox");
    area = stats.Area;

switch defectType

    case{"broken"}

    medArea = median(area);
    scale = 1.4826 * mad(area, 1);

    upperCutoff = medArea + 3*scale;
    selection = area > upperCutoff;
    BW2 = cc2bw (CC, ObjectsToKeep = selection);

    redChannel = uint8(BW2) * 255; 

    greenChannel = zeros(size(BW2), 'uint8');
    blueChannel  = zeros(size(BW2), 'uint8');

    redOverlay = cat(3, redChannel, greenChannel, blueChannel);

    metricMask = bwconncomp(BW2);

    metrics = metricMask.NumObjects;


    case{"glue"}

     medArea = median(area);
     stdArea = std(area);
     areaCutoff = medArea - (2.5 * stdArea);
     selection = (area < areaCutoff);
     BW2 = cc2bw (CC, ObjectsToKeep = selection);

     redChannel = uint8(BW2) * 255; 

     greenChannel = zeros(size(BW2), 'uint8');
     blueChannel  = zeros(size(BW2), 'uint8');

     redOverlay = cat(3, redChannel, greenChannel, blueChannel);
  
     metricMask = bwconncomp(BW2);

     metrics = metricMask.NumObjects;



end



