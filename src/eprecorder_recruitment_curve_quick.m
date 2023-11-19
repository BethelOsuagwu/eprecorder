function eprecorder_recruitment_curve_quick(EPR)
% EPRECORDER_RECRUITMENT_CURVE Plots a rough estimation recruitment curve
% relative to stimulus codes which are assumed to be stimulus intensities.
% This is a rough estimation.
%
% [INPUT]
% EPR: EPR structure. 



disp('Plotting recruiment curve')

if(~eprecorder_has_epoch(EPR))
    epoch_win=[-20,50];
    epoch_win=inputdlg('Epoch time window (ms)', ...
        'Recruitment curve: Epoching',1,{mat2str(epoch_win)});
    epoch_win=str2num(epoch_win{1});
    EPR=eprecorder_epoch(EPR,epoch_win);
end

peak2peak_time_win=inputdlg([ ...
    'Peak2peak time window (ms): max' mat2str(EPR.epochs.time_win)], ...
    'Recruitment curve',1,{mat2str(EPR.epochs.time_win)});
peak2peak_time_win=str2num(peak2peak_time_win{1});

epoch_time_win=EPR.epochs.time_win;

peak2peak_time_win=peak2peak_time_win-epoch_time_win(1);%offset epoch time window.

peak2peak_sample_win=eprecorder_time2sample(EPR,peak2peak_time_win/1000);

p2p_start=peak2peak_sample_win(1);
p2p_end=peak2peak_sample_win(2)-1;% If we don't subtract one, we will go over by one sample.

unique_codes=unique(EPR.epochs.codes);
codes_p2ps={};
for code=unique_codes
    [~,epochs]=eprecorder_epochs_for(EPR,code);
    epochs=epochs(:,p2p_start:p2p_end,:);

    %% peak to peak per trial
        
    % get the peak2peak for each row, dim 2. i.e this is done for each
    % channel and frame/epoch.  
    p2sks=peak2peak(epochs,2);

    % Squeeze out the dim 3 so that peak2peak for each channel is in row.
    % i.e each row contains all the peak2peak for the corresponding
    % channel. 
    p2ps=squeeze(p2sks);

    % transpose to have columns as channels
    p2ps=p2ps';

    codes_p2ps{end+1}=p2ps;
end


nChnls=size(codes_p2ps{1},2);%number of channels
nCodes=length(codes_p2ps);


%plot
figure
for chnl=1:nChnls

    subplot(nChnls,1,chnl);

    % Not: we will assume that the event codes are stimulus intensities so
    % that we can use it directly on the x-axis
    
    code_p2ps=zeros(1,nCodes);
    code_p2p_errors=zeros(1,nCodes);
    for code_n=1:nCodes

        trials=codes_p2ps{code_n}(:,chnl);% For the current channel and code read out all trials
        code_p2ps(code_n)=mean(trials);
        code_p2p_errors(code_n)=std(trials)/sqrt(length(trials));

        % Plot all trials for the same code
        % TODO: plot on a separate axis maybe?
        xdata=repmat(unique_codes(code_n),1,length(trials));
        plot(xdata,trials,'.','Color',[160,160,160]/255);
        hold on
    end


    errorbar(unique_codes,code_p2ps,code_p2p_errors);
    xlabel('Stimmus intensity')
    ylabel(['Amplitude (',EPR.channelUnits{chnl},')'])
    title(EPR.channelNames{chnl})
    hold off
end



