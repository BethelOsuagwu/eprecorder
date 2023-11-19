function data=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,time_win,rejected_as_nan)
    % Return epoch data for the specified channels, epochs, and time
    % window. 
    %
    % [INPUT]
    % EPR: The EPR data structure.
    % chan_num int|array<int>: The channel number. Set to empty [] for all
    %   channels. 
    % epoch_num int|array<int>: The epoch number. Set to empty [] for all
    %   epochs.
    % time_win array<double>: 2-element time(ms) [start,stop] window to extract relative to time 
    %   locking event at t=0. The default all.
    % rejected_as_nan boolean: If True rejected epochs will have a value of
    %   NaN in the returned data. Default is false.
    % [OUTPUT]
    % data array<double>: The data whose size/dimension depends on the
    %   inputs i.e Dim is [len(chan_num) x len(time_win) x len(epoch_num)].
    %   The unit of each channel corresponds to the unit given in
    %   EPR.channelUnits(chan_num).
    %
    if(~eprecorder_has_epoch(EPR))
        error('No epoched data found');
    end
    if nargin<4
        time_win=[EPR.times(1),EPR.times(end)];
    end

    if nargin<5
        rejected_as_nan=false;
    end

    % Validate time time window
    epoch_start_time=EPR.times(1);
    epoch_end_time=EPR.times(end);
    if (~eprecorder_is_valid_data_time_window(EPR,time_win))
        error(['Incompactible time window: [%g,%g]. The epoch time ' ...
            'window range is [%g,%g]'], time_win(1),time_win(2), ...
            epoch_start_time,epoch_end_time);
    end

    %
    if isempty(chan_num)
        chan_num=1:length(EPR.channelNames);
    end
    if isempty(epoch_num)
        epoch_num=1:size(EPR.data,3);
    end

    
    
    time_win=time_win - epoch_start_time;% Make time_wim relative to epoch start rather that time locking epoch.

    s=eprecorder_time2sample(EPR,time_win/1000); % convert time_win to samples.
    data=EPR.data(chan_num,s(1):s(2),epoch_num);


    if rejected_as_nan
        % Mark rejected as NaN
        is_rejected=eprecorder_epoch_qa.isEffectivelyRejected(EPR,chan_num,epoch_num);
    
        % Convert is_rejected to be the same size as the data.
        [rs,cs]=size(is_rejected);
        is_rejected=reshape(is_rejected,[rs,1,cs]);
        is_rejected=repmat(is_rejected,1,size(data,2),1);
    
        % Now turn the rejected epochs into NaN
        data(is_rejected)=NaN;
    end


end

