function mvc_rms=eprecorder_mvc_rms(EPR,chan_nums)
% Caculate MVC rms for each channel
% [INPUTS]
% EPR: EPR struct for cotaining MVC
% chan_nums []|array<int>|int: The channels to consider.
%[OUTPUTS]
% mvc_rms array: 1D array shape=(N,1) which contains MVC RMS values for the
%   corresponding side, in the specified channel order.   

if nargin < 2
    chan_nums=1:length(EPR.channelNames);
end

if eprecorder_has_epoch(EPR)
    error("The given dataset is epoched, a continuous dataset is required")
end
fig=figure;
rms_samples=round(EPR.Fs/4);% Number of samples to use for moving average;
mvc_rms=[];
for n=1:length(chan_nums)
    chan_num=chan_nums(n);
    adjusted_chan_num=chan_num+1;% +1 b/c first channel is actually time in continouse data.
    plot(EPR.data(adjusted_chan_num,:))
    title(['Select the window to be used to calculate MVC rms for this channel:', EPR.channelNames{chan_num}])
    xy=ginput(2);
    x=round(xy(:,1));
    emg=EPR.data(adjusted_chan_num,x(1):x(2));% ;;
   
    envelope(emg,rms_samples,'rms');
    title(['Your selected window for: ', EPR.channelNames{chan_num},'. Press a key to continue'])
    r=max(envelope(emg,EPR.Fs,'rms')); 
    if r <0
        r=abs(r);
    end
    answer=questdlg(['RMS: ',mat2str(r)],'RMS value','Cancel','Continue','Continue');
    switch(answer)
        case 'Cancel'
            close(fig);
            error("User cancel");
        case 'Continue'
    end

    mvc_rms(end+1)=r;
end

close(fig);

mvc_rms=mvc_rms';