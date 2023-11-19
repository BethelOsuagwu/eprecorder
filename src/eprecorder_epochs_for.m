function [epoch_nums,data]=eprecorder_epochs_for(EPR,stimulus_codes)
    % Return epochs for a given stimulus code.
    %
    % [INPUT]
    % EPR: EPR structure.
    % stimulus_codes double|[]: The main time locking event code found in
    %   EPR.epochs.codes; Default is the code for all epochs.
    % [OUTPUT]
    % epoch_nums array<int>: The epoch numbers.
    % data array: Epochs for the given event. 3-D array (chan x time x trials).
    
    if nargin < 2 || isempty(stimulus_codes) 
        stimulus_codes=EPR.epochs.codes;
    end

    if(~eprecorder_has_epoch(EPR))
        error('No epoched data found');
    end


    code_bool_idx=ismember(EPR.epochs.codes,stimulus_codes); 

    epoch_nums=find(code_bool_idx);
    if(nargout>1)
        data=EPR.data(:,:,code_bool_idx);
    end

end

