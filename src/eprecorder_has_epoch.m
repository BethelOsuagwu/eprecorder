function has_epoch= eprecorder_has_epoch(EPR)
%EPRECORDER_HAS_EPOCH Checks if data has been epoched
%
% [INPUT]
% EPR: EPR structure.
% 
%
% [OUTPUT]
% has_epoch: bool  True if data has been epoched.
if(~isfield(EPR,'epochs') || ~isfield(EPR.epochs,'codes') || isempty(EPR.epochs.codes))
    has_epoch=false;
    return
end

has_epoch=true;

