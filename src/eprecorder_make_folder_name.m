function folder_name=eprecorder_make_folder_name(dataFolder,subjectId,timepoint,sectionNumber)
    % Create a full folder name for storing data.
    % [INPUT]
    % dataFolder:string The base/parent folder
    % subjectId:string The current subject id
    % timepoint:string The study time point of the session, e.g Baseline.
    % sectionNumber:int The session muber
    % [OUTPUT]
    % folder_name:string Full folder name where data is stored.
    dataFolder=strip(strip(dataFolder,"right",'/'),"right",'\');
    folder_name=[dataFolder '/' subjectId '/' ,timepoint,'/s',mat2str(sectionNumber) '/'];
end