function valid=eprecorder_is_valid_data_time_window(EPR,time_win)
    % Chech if the given time window is within the available data. 
    %
    % [INPUT]
    % EPR: The EPR data structure.
    % time_win array<double>: 2-element time(ms) [start,stop] window relative to time 
    %   locking event at t=0.
    % [OUTPUT]
    % valid bool: True if the time window is valid.
    %
    

    % Validate time time window
    valid=true;
    epoch_start_time=EPR.times(1);
    epoch_end_time=EPR.times(end);
    if ((time_win(1)<epoch_start_time) ...
            || (time_win(1)>time_win(2)) ...
            || (time_win(2)>epoch_end_time ...
        ))
        valid=false;
    end
