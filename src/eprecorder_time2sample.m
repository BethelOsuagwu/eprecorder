function samples=eprecorder_time2sample(EPR,times,intval)
% Convert the times in seconds to their samples equivalent
% [INPUT]
% EPR struct: EPR data structure
% times double|array<double>: The time/s (seconds) to convert.
% intval bool: If true resturned values will be floored to integer/s. The
%   default is false. 
% [OUTPUT]
% samples double|array<double>: Samples
% 
if nargin<3
    intval=false;
end

% we add 1 b/c the time starts from zero while samples which will be used
% for index in matlab must start from 1. So time zero is sample 1. 
samples=times*EPR.Fs+1;

if(intval)
    samples=floor(samples);
end

