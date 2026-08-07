%This script is used to change and match the directory of the user to
% be able to use the previously allocated test set from a previous
% training session of the classifiers.

%Load the table
load("testSetoftestingScriptNetworksAndClasses.mat");

%User chooses dataset folder
newRoot = uigetdir(pwd,...
    "Select the mvtec_anomaly_detection_USED_v5 folder");

if isequal(newRoot,0)
    error('No folder selected.');
end

datasetName = "mvtec_anomaly_detection_USED_v5";

for k = 1:height(testSet)

    oldPath = testSet.Filename(k);

    %Convert to character vector
    oldPathChar = char(oldPath);

    %Normalize separators so this works regardless of the OS that
    % originally created the table.
    oldPathChar = strrep(oldPathChar,'\','/');

    idx = strfind(oldPathChar,char(datasetName));

    if isempty(idx)
        warning('Could not update row %d.',k);
        continue;
    end

    %Keep everything after the dataset folder
    relativePath = extractAfter(string(oldPathChar),datasetName);

    %Convert separators for the current OS
    relativePath = strrep(relativePath,'\',filesep);
    relativePath = strrep(relativePath,'/',filesep);

    %Build new path
    testSet.Filename(k) = string(fullfile(newRoot,char(relativePath)));

end

disp('Finished updating all paths to match your path of the test set');
