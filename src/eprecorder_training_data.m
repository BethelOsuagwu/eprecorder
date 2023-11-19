function [data, targets]=eprecorder_training_data(EPR,filename,pre_stimulus,stim_artefact_chans,stim_artefact_time_wins)
% Export epoched data as tranning evoked potential detector classifier. The
% data should be processed with EP 'onset' and 'stop' clearly marked.
%
% [INPUTS]
% EPR struct: EPR data structure.
% filename string: The csv filename (excluding '.csv') to save the data as.
%   If a file with the name name already exists a warning is given. Default
%   none. 
% pre_stimulus bool: When true, pre stimulus data will be added to
%   increase the background data. The default is true.
% stim_artefact_chans array<double> 1D array where each entry is index of a
%   channel that contans stim artefact.
% stim_artefact_time_wins array<double>: Nx2 array of stimulus artefact
%   times[start end] in ms, relative to time locking event at t=0. Each
%   row corresponds to an entry in the stim_artefact_chans. 
%   This time should be only provided for the first stimulus; the time for
%   the other stimuli, if any, will be calculated. 
% [OUTPUTS]
% data array<double>: Concatenated data of all
%   channels, epochs and stimulus numbers. Rejected epochs and epoch
%   without response are not included. Dim is column.
% targets: One hot encoding for data. First column is for background noise;
%   second column is stimulus artefact and the third column is for an
%   entire EP wave. Dim is len(data) x num_classes. 
if nargin<2
    filename=[];
end

if nargin <3
    pre_stimulus=true;
end

if nargin < 4 
    stim_artefact_chans=[1,4];
    stim_artefact_time_wins=[4,10];
end


if size(stim_artefact_time_wins,1)==1 && length(stim_artefact_chans)~=1
    stim_artefact_time_wins=repmat(stim_artefact_time_wins,length(stim_artefact_chans),1);
end
if size(stim_artefact_time_wins,1) ~= length(stim_artefact_chans)
    error(['Incorrect number for stim artifact time windows. The number ' ...
        'of stim artefact time windows musch the number of stim ' ...
        'artefact channels.']);
end

% If you would like to include the background data enclosed within a
% channel's response time window, then set this following to true.  
use_all_response_window=true;

% Between stimulus and response, any sample that is neither stimulus
% artefact nor response is considered a baseline data. Set the following to
% false to disable labeling those samples as baseline data.
label_post_stim_artefact_pre_response_as_bg=false;

%
[~,isi]=eprecorder_stimulus_numbers(EPR,false);

num_classes=3;
data=[];
targets=[];
units={};
epoch_nums=eprecorder_epochs_for(EPR);
stimulus_nums=eprecorder_stimulus_numbers(EPR);
for chan_num=1:length(EPR.channelNames)
    for epoch_num=epoch_nums
        for stimulus_num=stimulus_nums
            if ~eprecorder_epoch_qa.isEffectivelyRejected(EPR,chan_num,epoch_num)
                if eprecorder_response.has(EPR,chan_num,epoch_num,stimulus_num)
                    
                    % Response window
                    time_win=eprecorder_response.getTimeWin(EPR,chan_num,stimulus_num);

                    % Response onset and offset
                    onset=eprecorder_response.getEffectiveOnsetTime(EPR,chan_num,epoch_num,stimulus_num);
                    offset=eprecorder_response.getEffectiveStopTime(EPR,chan_num,epoch_num,stimulus_num);

                    % In case the onset/offset is not within the response 
                    % window; in which case we use the the onset/offset
                    % as the start/stop of the reponse window.
                    time_win(1)=min(onset,time_win(1));
                    time_win(2)=max(offset,time_win(2));

                    

                    % Response data
                    if use_all_response_window
                        data_time_win=time_win;
                    else
                        data_time_win=[onset,offset];
                    end
                    data_temp=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,data_time_win);
                    data_temp=data_temp';

                    % Adjust times to be relative to tim win start
                    onset_adj=onset-data_time_win(1);
                    offset_adj=offset-data_time_win(1);

                    % Convert times to samples
                    onset_adj=eprecorder_time2sample(EPR,onset_adj/1000);
                    offset_adj=eprecorder_time2sample(EPR,offset_adj/1000);


                    % Create target
                    targets_temp=zeros(size(data_temp,1),num_classes);
                    %%targets_temp(:,1)=1;% background
                    %targets_temp(onset_adj:offset_adj,1:2)=repmat([0,1],[length(onset_adj:offset_adj),1]);
                    targets_temp(onset_adj:offset_adj,num_classes)=1;% EP
                    % Post stimulus background
                    if use_all_response_window
                        if label_post_stim_artefact_pre_response_as_bg
                            targets_temp(targets_temp(:,num_classes)==0,1)=1;% Background       
                        else
                            do_not_select=false(offset_adj,1);% i.e do not consider all samples before response offset/stop
                            select_within=targets_temp(offset_adj+1:end,num_classes)==0;
                            select_idx=[do_not_select;select_within];
                            if length(select_idx) ~= size(targets_temp,1)
                                error('Incorrect indexing of targets');
                            end
                            targets_temp(select_idx,1)=1;
                        end
                    end

                    % Sanity check
                    if size(data_temp,1) ~=size(targets_temp,1)
                        error('Something is wrong with the time/samples calculations, as #rows of data_temp and target_temp differ:: channel:%i, epoch:%i, stimulus#:%i',chan_num,epoch_num,stimulus_num);
                    end
                    
                    % Prestimulus data to increase the amount of background
                    % data
                    pre_stim_data=[];
                    pre_stim_targets=[];
                    if pre_stimulus
                        pre_stim_time=[EPR.times(1) 0];
                        pre_stim_data=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,pre_stim_time);
                        pre_stim_data=pre_stim_data';
                        pre_stim_targets=zeros(size(pre_stim_data,1),num_classes);
                        pre_stim_targets(:,1)=1;% more background
                    end

                    % Stim artifact
                    stim_artefact_data=[];
                    stim_artefact_targets=[];
                    idx=find(stim_artefact_chans==chan_num);
                    if ~isempty(idx)
                        artefact_win=stim_artefact_time_wins(idx,:);
                        artefact_win=artefact_win+isi(stimulus_num);% adjust the artefact time window based on the stimulus number.
                        stim_artefact_data=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,artefact_win);
                        stim_artefact_data=stim_artefact_data';
                        stim_artefact_targets=zeros(size(stim_artefact_data,1),num_classes);
                        stim_artefact_targets(:,2)=1;% for now we label stim artefacts different from background
                    end

                    

                    % Merge data
                    data=[data;pre_stim_data;stim_artefact_data;data_temp];
                    targets=[targets;pre_stim_targets;stim_artefact_targets;targets_temp];


                    units{end+1}=EPR.channelUnits{chan_num};
                    units=unique(units);

                end
            end
        end
      
    end
end

% Discard unlabelled data
unlabelled_idxs=find(sum(targets,2)==0);
data(unlabelled_idxs)=[];
targets(unlabelled_idxs,:)=[];

% Save sata
if ~isempty(filename)
    filename=[filename,'.csv'];
    if ~exist(filename,"file")
        writematrix([data,targets],filename);
        T = array2table([data,targets]);
        T.Properties.VariableNames(1:1+num_classes) = {['potential(', strjoin(units,'/'),')'],'background label','stimulation noise label','evoked potential label'};
        writetable(T,filename);
    else
        warning([filename ' already exists']);
    end
end
end