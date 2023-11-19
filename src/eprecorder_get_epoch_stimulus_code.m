function stimulus_codes=eprecorder_get_epoch_stimulus_code(EPR,epoch_nums,is_unique)
    % Return epochs' stimulus code.
    % [INPUT]
    % EPR: EPR structure.
    % epoch_nums int|array<int>: Epoch numbers. The default is all epochs.
    % is_unique boolean: If true the stimulus codes returned will be
    %   unique. The default is false.
    % [OUTPUT]
    % stimulus_codes array<double>: The epoch stimulus_codes. (1 x nEpochs).
    %
    % [EXAMPLE]
    % Return all available stimulus codes in the dataset:
    %   sc=stimulus_codes=eprecorder_get_epoch_stimulus_code(EPR,[],true)
    %

    if nargin<2
        epoch_nums=[];
    end

    if nargin<3
        is_unique=false;
    end
    
    if(~eprecorder_has_epoch(EPR))
        error('No epoched data found');
    end

    if isempty(epoch_nums)
        stimulus_codes=EPR.epochs.codes();
    else
        stimulus_codes=EPR.epochs.codes(epoch_nums);
    end

    if is_unique
       stimulus_codes= unique(stimulus_codes,'sorted');
    end

end

