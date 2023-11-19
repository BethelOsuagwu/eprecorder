function EPR = eprecorder_merge(EPR,EPR2)
% Merge the data of EPR2 to EPR. Information such as fn2, etc in EPR2 are
% discarded as the ones in EPR are kept.
% [INPUT]
% EPR: The main EPR structure
% EPR2: EPR data structure containing the data to be merged to EPR.
% [OUTPUT]
% EPR: The input structure with merged data

[is_valid,msg]=eprecorder_validate_merge(EPR,EPR2);
if(~is_valid)
    error(msg)
end

original_samp=size(EPR.data,2);
original_time=eprecorder_sample2time(EPR,original_samp);

EPR.onlie.triggerTimes=[EPR.online.triggerTimes,EPR2.online.triggerTimes+original_time];
EPR.online.viewerTriggerTimes=[EPR.online.viewerTriggerTimes,EPR2.online.viewerTriggerTimes+original_time];
EPR.online.rejectTriggerAtTimes=[EPR.online.rejectTriggerAtTimes,EPR2.online.rejectTriggerAtTimes+original_time];
for n=1:length(EPR2.online.notes)
    entry=EPR2.online.notes{n};
    trigger=entry{1};
    note=entry{2};
    EPR.online.notes{end+1}={trigger+original_time,note};
end


% Data
if(eprecorder_has_epoch(EPR))
    error('Merging of epoched data is not implemented yet');
else  
    % Adjust the time for EPR2. Note that row 1 is time.
    data1_end_time=EPR.data(1,end);
    EPR2.data(1,:)=EPR2.data(1,:)+data1_end_time;

    % Merge data
    EPR.data=[EPR.data,EPR2.data];
end


action=sprintf('EPR=eprecorder_merge(EPR,EPR2)');
EPR=eprecorder_add_history(EPR,action,['Merge',EPR2.fn2],now);

name='merged';
if(isfield(EPR,'name'))
    name=[EPR.name,' merge'];
    if(isfield(EPR2,'name'))
        name=[EPR.name ' merged with ' EPR2.name];
    end
end
EPR.name=name;