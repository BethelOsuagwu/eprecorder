function channel_data = eprecorder_channel_data(EPR)
%EPRECORDER_CHANNEL_DATA Returns only the actaull continous channel data,
%i.e without time added by simulink, trig and stimulus code.
% [INPUT]
% EPR: EPR structure.
%
% [OUTPUT]
% channel_data: actual channel data in nChannels x time (i.e channels on
% the first dim and time on the second).


channel_data=EPR.data;
channel_data=channel_data(2:end-2,:);% first channel is time, the last two are trigger and stimulus code.
end

