%The following creates a table, where the code can be reused to separate
% labels in other data sets that follow the same structure (part type
% pass/fail, along with the defect types in the fail folder)
%This whole section (except for the first line below) will be placed 
% in a function file named "organizeDataSet." The input into the function
% is the users chosen directory, and the output will be "dataSetTable"
rawData = "directory to dataset goes here";

imds = imageDatastore(rawData, IncludeSubfolders=true);

%Store text of file names in array
files = string(imds.Files);
elem = numel(files);

parts = strings(elem, 1);
condition = strings(elem, 1);
defectType = strings(elem, 1);


for k = 1:elem
    %Goes through the directory each time and splits objects based on
    %filename
    folderNames = split(files(k), filesep);

    idx = length(folderNames);
    
    %Assigns label to each image based on folder type
    if folderNames(idx-1) == "PASS"
        parts(k) = folderNames(idx-2);
        condition(k) = "PASS";
        defectType(k) = "NONE";
    else
        parts(k) = folderNames(idx-3);
        condition(k) = "FAIL";
        defectType(k) = folderNames(idx-1);
    end
end


dataSetTable = table(files, categorical(parts), categorical(condition),...
 categorical(defectType), 'VariableNames', {'Filename', 'Part', 'Part Condition', 'Defect Type'})
