function [is_valid,msg]= eprecorder_validate_merge(EPR,EPR2)
    % Checks that the given are EPR structures can be merged.
    % [INPUT]
    % EPR: The main EPR structure
    % EPR2: EPR data structure contain the data to be merged to EPR.
    % [OUTPUT]
    % is_valid boolean: True for valid merge items
    % msg string: message

    msg='';
    is_valid=true;

    %% Same epoched state
    if(xor(eprecorder_has_epoch(EPR),eprecorder_has_epoch(EPR2)))
        is_valid=false;
        msg='Both dataset must either be epoched or continuous';
        return;
    end


    %% Same samplerate
    if(EPR.Fs~=EPR2.Fs)
        is_valid=false;
        msg='Both dataset must have the Fs';
    end
    
    %% Same number of channels
    if(size(EPR.data,1)~=size(EPR2.data,1))
        is_valid=false;
        msg='Both dataset must have the same number of rows of data';
    end
end

