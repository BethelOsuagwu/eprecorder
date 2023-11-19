function times=eprecorder_sample2time(EPR,samples)
% Convert the samples to their times in seconds equivalent
% [INPUT]
% samples int|array<int>: samples.
% [OUTPUT]
% times double|array<double>: The time/s in seconds
% 


% we subtract 1 b/c the time starts from zero while samples which will be used
% for index in matlab must start from 1. So time zero is sample 1. 
times=(samples-1)/EPR.Fs;
end

