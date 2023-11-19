function EPR=eprecorder_epoch(EPR,epoch_time_win, ...
    trigger_magnitude,trigger_primary,trigger_secondary_tau)
%Epoch the data into trials using the given time window
%codes.
% [INPUT]
% EPR: EPR structure.
% epoch_time_win array: The time window in ms with which to epoch the data. 
%   A two element vector where the first element is the start time and the 
%   second is the end time. Default is [-10,60] 
% trigger_magnitude double: Transition in the trigger channel that are
%   considered as trigger. The default is 1. 
% trigger_primary bool: see eprecorder_triggers() (i.e primary).
%   The default is true. 
% trigger_secondary_tau int: see eprecorder_triggers() (i.e secondary_tau).
%   The default is 0. 
% [OUTPUT]
% EPR struct: EPR structure with epoched data. It will be empty on fail. 
%   The following fields will be added replaced to the structure on
%   success: 
%       data: the epoche data(:,:,ntrials) with events and trigger channels
%       removed.
%       trials int: The number of epochs in data.
%       times array<double>: Row vector of times in ms for the epoched
%       data. Has the same length as the number of samples in an epoch.
%       epochs.time_win: The time window  in ms used to epoch.
%       epochs.original_codes array<double>: the event codes for 
%           corresponding trials in data. Including those corresponding to 
%           rejected triggers. Dimension is 1xntrials  and corresponds to 
%           the 3rd axis of data. 
%       epochs.original_trigs array<double>: the trigger in sample for each 
%           trial in data. Including those corresponding to rejected
%           triggers. Dimension is 1xntrials  and corresponds to the 3rd 
%           axis of data. 
%       epochs.codes array<double>: the stimulus codes for corresponding 
%           trials is data. Not including those corresponding to rejected
%           triggers. This should be used for uniquely identifying the time
%           locking event code for each trial. Dimension is 1xntrials  and
%           corresponds to the 3 axis of data.
%       epochs.trigs array<double>: primary triggers in samples for each 
%           trial in data. Not including those corresponding to rejected
%           triggers. Dimension is 1xntrials  and corresponds to the 3rd 
%           axis of data. 
%       epochs.secondary_trigs array<double>: secondary triggers in samples 
%           corresponding to epochs.trigs output. Row n corresponds to
%           column n of epochs.trigs. Dimension is 
%           len(epochs.trigs) x len(find(EPR.ISI)).
%       epochs.events struct: A structure equivalent to EEGLab's EEG.epoch
%           with fields 'type' and 'latency' where the fields 'type' and
%           'latency' are equivalent to eventtype and eventlatency
%           respectively and specify event code and latency. The latency
%           is relative to the time locking event, epochs.codes, which has 
%           a latency of zero, and it is in ms. 
%       epochs.qa.auto_rejects array<int>:{0,1,NaN(default)} An array where 
%           an entry with 1 implies that the corresponding channel's epoch 
%           has been automatically marked for rejection. Epochs rejected 
%           online are not included here. NaN value implies that the value 
%           is not set. Dimension is [nchannels x ntrials] and corresponds
%           to the first and 3rd axis of data.
%       epochs.qa.manual_rejects array<int>:{0,1,NaN(default)} An array
%           where an entry with 1 implies that the corresponding channel's
%           epoch has been manually marked for rejection. Epochs rejected
%           online are not included here. NaN value implies that the value
%           is not set. Dimension is [nchannels x ntrials] and corresponds
%           to the first  and 3rd axis of data.
%       epochs.notes cell: Notes for frames. They are copied from
%           EPR.online.notes.  Dimension is 1xntrials  and corresponds to
%           the 3rd axis of data. Each cell entry is a 1x2 cell with values
%           as {current_trig_time<float>,note<string>}.
%       epochs.info string: Data text information.
%       epochs.features.mep struct: A struct for EP response features
%           described in the function @see eprecorder_response.addFields()  

if nargin < 2
    epoch_time_win=[-10,60];
end

if nargin < 3
    trigger_magnitude=1;
end

if nargin < 4
    trigger_primary=true;
end

if nargin < 5
    trigger_secondary_tau=0;
end

epochs.time_win=epoch_time_win;

pre_trig=floor(epoch_time_win(1)*EPR.Fs/1000);
post_trig=floor(epoch_time_win(2)*EPR.Fs/1000);

[trigs,event_codes,notes,secondary_trigs]=eprecorder_triggers( ...
    EPR,trigger_magnitude,trigger_primary,trigger_secondary_tau);

if(isempty(trigs))
    % No point to continue.
    EPR=[];
    return
end

epochs.original_codes=event_codes;
epochs.original_trigs=trigs;

epochs.codes=event_codes;
epochs.trigs=trigs;

epochs.secondary_trigs=secondary_trigs;

epochs.notes=notes;

epochs.info="The data field has only channel data with time " + ...
    "on the 2nd axis " + ...
    "with sweeps on the 3rd axis. The nth index in the 3rd " + ...
    "axis corresponsd to nth index in fields event.trigs/codes";

channel_data=eprecorder_channel_data(EPR);

trials=[];

for n=1:length(trigs)
    T=trigs(n);
    time_idx=T+pre_trig:T+post_trig-1;

    % The time must fit within the epoch and epoch must not be rejected
    is_rejected=eprecorder_is_trigger_rejected(EPR,T);
    if(time_idx(1)<1  || time_idx(end)>size(channel_data,2) || is_rejected)
        % remove the associated events and trigs, notes etc.
        epochs.codes(n)=[];
        epochs.trigs(n)=[];
        epochs.notes(n)=[];

        % because it will be empty if there are no EPR.ISI(see
        % eprecorder_triggers()). 
        if ~isempty(epochs.secondary_trigs)
            epochs.secondary_trigs(n,:)=[];
        end

        %
        continue;
    end

    trial=channel_data(:,time_idx);
    if(isempty(trials))
        trials=trial;
    else
        trials(:,:,end+1)=trial;
    end
end

% channels are on 1st axis and time is on 2nd axis.
EPR.data=trials;% overwrite the data


% The time
L=size(EPR.data,2);
ts=(0:1:L-1)*1/EPR.Fs;
ts=ts*1000;% to ms
ts=ts+epochs.time_win(1);%offset with epoch window start time
EPR.times=ts;

% Additional fields
n_channels=size(EPR.data,1);
n_epochs=size(EPR.data,3);
epochs.qa.auto_rejects=nan(n_channels,n_epochs);
epochs.qa.manual_rejects=epochs.qa.auto_rejects;


% Create events struct similar to EEGlab but placed in EPR.epochs.events.
% And also add the the time locking event, epochs.codes as event with the
% same type as codes and latency of zero.
latency=zeros(1,n_epochs);% time locking event latencies is always zero.
epochs.events=struct('type',num2cell(epochs.codes),'latency', ...
    num2cell(latency));

EPR.trials=n_epochs;
EPR.epochs=epochs;

EPR=eprecorder_response.addFields(EPR,true);
end

