function EPR=eprecorder_merge_epoch(AllEPR,save_filename)
    % Merge epoched dataset
    % [INPUT]
    % AllEPR cell<struct>|string: A string or cell array of EPR data
    %   structures. If it is a string, it will be assumed to be a folder
    %   and all EPR file in the folder will be loaded to create AllEPR.
    % save_filename string: The filename to save the resultant dataset
    %   with.
    % [OUTPUT]
    % EPR struct: The merge resultant dataset.

    if nargin < 2
        save_filename=[];
    end
    
    folder=[];
    if ~iscell(AllEPR)
        folder=AllEPR;
        fprintf('Attempting to load data from %s', AllEPR);
        AllEPR=get_dataset_from_folder(AllEPR);
    end
    
    EPR=AllEPR{1};
    for i = 2:length(AllEPR)
        EPR=merge_datasets(EPR,AllEPR{i});
    end

    if save_filename
        folderPath=fullfile(folder,'merged');

        if exist(folderPath, 'dir') ~= 7
            mkdir(folderPath);
        end

        
        fn=fullfile(folderPath,[save_filename,'.mat']);
        if exist(fn,"file")
            error([fn,' already exists']);
        end

        save(fn,"EPR");
    end
end

function datasets=get_dataset_from_folder(folder)
    % Get all the EPR dataset in a folder.
    % folder string:
    % datasets cell<struct>: Cell of EPR structs.
    
    files = dir(fullfile(folder, '*.mat'));
     
    datasets={};
    for i = 1:length(files)
        filen = fullfile(folder, files(i).name);
        c = load(filen);
    
        if isfield(c, 'EPR')
            datasets{end+1}=c.EPR;
            
            fprintf('Loading file: %s, Number of epochs: %d\n', filen, c.EPR.trials);
            
        end
    end
end


function EPR1 = merge_datasets(EPR1,EPR2)
    % Merge EPR2 into EPR1.
    
    EPR1.subjectId=strjoin(unique([string(EPR1.subjectId),string(EPR2.subjectId)]),',');
    EPR1.sectionN=strjoin(unique(string([EPR1.sectionN,EPR2.sectionN])),',');
    EPR1.subsection=strjoin(unique(string([EPR1.subsection,EPR2.subsection])),',');
    EPR1.condition=strjoin(unique({EPR1.condition,EPR2.condition}),',');
    EPR1.param=strjoin(unique({EPR1.param,EPR2.param}),',');
    EPR1.tag=strjoin(unique({EPR1.tag,EPR2.tag}),',');
    EPR1.side=strjoin(unique({EPR1.side,EPR2.side}),',');
    EPR1.target=strjoin(unique({EPR1.target,EPR2.target}),',');
    EPR1.timepoint=strjoin(unique({EPR1.timepoint,EPR2.timepoint}),',');
    
    if any(EPR1.ISI - EPR2.ISI)
        warning('Merging epocked datasets: Differences in ISI detected');
    end
    EPR1.stimulusCodes=unique([EPR1.stimulusCodes,EPR2.stimulusCodes]);
    EPR1.name=strjoin(unique({EPR1.name,EPR2.name}),'-');

    if length(EPR1.times)~=length(EPR2.times) || any(abs(EPR1.times-EPR2.times)>eps)
        error('Merging epocked datasets: annot merge datasets with different times');
    else
        EPR1.data=cat(3,EPR1.data,EPR2.data);
    end

    EPR1.trials=EPR1.trials+EPR2.trials;

    EPR1.epochs.original_codes=[EPR1.epochs.original_codes,EPR2.epochs.original_codes];
    EPR1.epochs.codes=[EPR1.epochs.codes,EPR2.epochs.codes];

    
    
    if true % TODO: Note that for now we do not add the trigs as it is a bit tricky given that the two datasets do not necessarily follow each other in time. Set to true to add the trigs anyways.
        EPR1.epochs.original_trigs=[EPR1.epochs.original_trigs,EPR2.epochs.original_trigs];
        EPR1.epochs.trigs=[EPR1.epochs.trigs,EPR2.epochs.trigs];
        EPR1.epochs.secondary_trigs=[EPR1.epochs.secondary_trigs;EPR2.epochs.secondary_trigs];
    else
        EPR1.epochs.trigs=[];
        EPR1.epochs.secondary_trigs=[];
        EPR1.epochs.original_trigs=[];
    end
    
    EPR1.epochs.notes=[EPR1.epochs.notes,EPR2.epochs.notes];

    EPR1.epochs.info=strjoin(unique({EPR1.info,EPR2.info}),'. ');

    

    % events
    EPR1.epochs.events=[EPR1.epochs.events,EPR2.epochs.events];

   
    %
    EPR1=eprecorder_epoch_qa.merge(EPR1,EPR2);

    EPR1=eprecorder_response.merge(EPR1,EPR2);

    EPR1=eprecorder_label.merge(EPR1,EPR2);




end





