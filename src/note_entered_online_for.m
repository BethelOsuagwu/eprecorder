function [trig_note_entry,note_idx]=note_entered_online_for(EPR,trig)
    % Retrieve note that were entered online for the given trigger. 
    %
    % [INPUT]
    % EPR: EPRecorder main data strcture
    % trig: int Trigger, in samples, at which the note was entered. 
    %
    % [OUTPUTS]
    % trig_note_entry: cell A 2 element cell array where the 1st entry is
    %   the trig time in seconds and the 2nd is the note. 
    % note_idx: int The array index in the online notes where the note
    % for the given trig was found. This will be empty matrix if no note is
    % found

    trig_note_entry={};
    note_idx=[];
    trig_time=eprecorder_sample2time(EPR,trig);
    for n_note=1:length(EPR.online.notes)
        note_entry=EPR.online.notes{n_note};
        if(note_entry{1}==trig_time)
            trig_note_entry=note_entry;
            note_idx=n_note;
        end
    end
end