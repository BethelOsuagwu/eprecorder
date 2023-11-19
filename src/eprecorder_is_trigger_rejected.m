function is_rejected=eprecorder_is_trigger_rejected(EPR,trig)
    % Check if the given trigger is rejected. It currently uses the triger 
    % times that were rejected.
    % [INPUT]
    % EPR: EPR structure.
    % trig: A trigger time in samples
    % [OUTPUT]
    % is_rejected: boolean True if the trig is rejected

    online_rejected_triggers= eprecorder_time2sample(EPR,EPR.online.rejectTriggerAtTimes);
    is_rejected=any(online_rejected_triggers==trig);
end
