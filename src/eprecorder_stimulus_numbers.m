function [numbers,isi]=eprecorder_stimulus_numbers(EPR,only_secondary)
    % Get the number/indexes of epoch triggers/stimulus that were delivered
    % as a group within an epoch. 
    %
    % [INPUT]
    % EPR: The EPR data structure.
    % only_secondary bool: If true only secondary trigger number will be
    %   included. The default is false; 
    % [OUTPUT]
    % numbers array<int>: The stimulus numbers. 1 is for primary trigger.
    %   Dimension = 1 x 1+len(find(EPR.ISI)) when only_secondary=false.
    % isi array<int>: Inter stimulus intervals in milliseconds. Same dim
    %   as the output: numbers.

    if nargin < 2
        only_secondary=false;
    end

    ISInterval=[];
    if isfield(EPR,'ISI')% backward compactibility
        ISInterval=EPR.ISI;
    end
    isi=ISInterval(ISInterval~=0);
    numbers=1:length(isi);% ISI with zeros do not count
    numbers=numbers+1;

    if only_secondary==false
        isi=[0,isi];
        numbers=[1,numbers];
    end
    
end