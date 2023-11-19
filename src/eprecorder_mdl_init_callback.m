function eprecorder_mdl_init_callback()
% EPRECORDER_MDL_START_CALLBACK. The callback fcn for model initFcn
%
%
global EPR;

if(~isfield(EPR,'temp'))% Note we can remove the if statement if we are not reusing the anything in EPR.temp, and just run the statement insise directly
   EPR.temp=struct;
end

% We define a container to keep count of the current number of events
% we have recieved for YData changes.
%This is equivalent to number of detected triggers, which the
%number of trials shown in the viewer. % We keep record of the
%current value just so we can detect changes. 
EPR.temp.number_of_change_events=0;

% We always recreate an online field for storing run details collected
% online. We recreate it to avoide detail from priouse run being kept in
% the current run.
EPR.online=struct;
EPR.online.triggerTimes=[];
EPR.online.viewerTriggerTimes=[];
EPR.online.rejectTriggerAtTimes=[];
EPR.online.notes={};


if(~EPR.enableViewer)
    return
end

% Create viewer figure
epr_viewer_figs=findobj('Tag','ep-recorder-viewer');
epr_viewer_fig_position=[];

for n=1:length(epr_viewer_figs)
     if(n==1) 
         epr_viewer_fig_position= get(epr_viewer_figs(n),'position');
     end
     close(epr_viewer_figs(n));
end

figure('NumberTitle','off','Name','EPR viewer','Tag','ep-recorder-viewer');
if(epr_viewer_fig_position)
    set(gcf,'position',epr_viewer_fig_position);
end

% Place an info board annotation
EPR.temp.viewerAnnotationObj=annotation('textbox',...
[0.01 0.94 0.98 0.06],...
'Color',[0.494117647058824 0.184313725490196 0.556862745098039],...
'String','Go on, trigger me!',...
'FontWeight','bold',...
'FontSize',8,...
'FitBoxToText','off',...
'EdgeColor',[0.901960784313726 0.901960784313726 0.901960784313726]);

uicontrol('style','pushbutton', ...
    'String','Note', ...
    'units','normalized', ...
    'fontweight','bold', ...
    'position',[0.79,0.95,0.06,0.05], ...
    'ForegroundColor',[0.49,0.18,0.56], ...
    'FontSize',8, ...
    'enable','on', ...
    'Tag','epr-edit-frame-note-btn',...
    'Callback',@editFrameNote, ...
    'Tooltip','Edit frame/epoch note'...
);
uicontrol('style','pushbutton', ...
    'String','Toggle reject', ...
    'units','normalized', ...
    'fontweight','bold', ...
    'position',[0.85,0.95,0.14,0.05], ...
    'ForegroundColor',[0.49,0.18,0.56], ...
    'FontSize',8, ...
    'enable','on', ...
    'Tag','epr-toggle-frame-reject-mark-btn',...
    'Callback',@toggleFrameRejectMark, ...
    'Tooltip','Mark or unmark current frame as rejected'...
);


% Gmeasure
uicontrol('style','pushbutton','string','Measure','units','normalized','fontweight','bold','position',[0.019642857142852,0.019047619047647,0.1,0.050000000000001],'enable','on','Tag','epr-measure-btn','callback',@eprecorder_gmeasure,'Tooltip','Measure two points on a plot');


% Delete and reset ydata postset events listener handles array
if(isfield(EPR.temp,'ydata_postset_listerners'))
    for el =EPR.temp.ydata_postset_listerners
        delete(el{1});
    end
end
EPR.temp.ydata_postset_listerners={};

% Create viewer axes
nChanls=length(EPR.viewerChannels);
for n=1:nChanls
     %% Single trial axes
     ax=subplot(nChanls,2,2*n-1);
     EPR.temp.singleLines(n)=double(plot(ax,0,0,'DisplayName','Channel data'));
     EPR.temp.ydata_postset_listerners{n}=addlistener(EPR.temp.singleLines(n),'YData','PostSet',@eprecorder_single_axis_ydata_change_callback);
     hold(ax,'all');
     title(['Channel ',mat2str(EPR.viewerChannels(n)), ' - ', EPR.channelNames{EPR.viewerChannels(n)}]);
     ylabel(['Amplitude (',EPR.channelUnits{n},')']);
     xlabel('Time(ms)');

     % set y limit
     lim=EPR.viewerChannelLims{n};
     if(lim)
         ylim(ax,lim);
     end         

     lne=handle(EPR.temp.singleLines(n));
     lne.UserData.viewer_channel=n;

     if(EPR.enableP2p)
         % More plot on the axis for characterising the current line
         single_marker_min=plot(ax,0,0,'ro','markersize',7,'DisplayName','Peak2peak min');
         single_marker_max=plot(ax,0,0,'r.','markersize',20,'DisplayName','Peak2peak max');
         single_marker_txt=text(ax,0,0,'0.0','Color','red','DisplayName','Peak2peak');
         
         % Save the plots characterising the current line
         lne.UserData.peak2peak.single_marker_min=single_marker_min;
         lne.UserData.peak2peak.single_marker_max=single_marker_max;
         lne.UserData.peak2peak.single_marker_txt=single_marker_txt;

         % To avoid plotting so much lines, lets just plot the peak to peak
         % indication bar on just one axis
         if(n==1)
             plot(ax,[EPR.viewerP2pTimeWin],[0,0],'r--','DisplayName','Peak2peak window');
         end
    end

     %% Avg axes
     avg_ax=subplot(nChanls,2,2*n);
     EPR.temp.avgLines(n)=double(plot(avg_ax,0,0,'DisplayName','Averaged channel data'));
     hold(avg_ax,'all');
     title(['Channel ',mat2str(EPR.viewerChannels(n)), ' - ',EPR.channelNames{EPR.viewerChannels(n)}]);
     ylabel([' Avg amplitude (',EPR.channelUnits{n},')']);
     xlabel('Time(ms)')

     % 

     % set y limit for avg axis
     %lim=EPR.viewerChannelLims{n};
     %if(lim)
     %    ylim(avg_ax,lim);
     %end

     % peak to peak
     if(EPR.enableP2p)
         % Peak to peak threshold
         y1=EPR.p2pThresh(EPR.viewerChannels(n));
         y=[y1,y1];
         x=[EPR.viewerTimeWin(1),EPR.viewerTimeWin(2)];
         plot(avg_ax,x,y,'m-.','DisplayName','Peak2peak threshold','LineWidth',2);

         % Resting motor threshold alert
         x=(EPR.viewerTimeWin(2)-EPR.viewerTimeWin(1))/2;%i.e way in the viewer.
         y=EPR.p2pThresh(EPR.viewerChannels(n));
         rmt_alert=text(avg_ax,x,y,'Bam, we''ve hit RMT','Color','green','FontSize',18,'FontWeight','bold','Visible','off');
         lne.UserData.peak2peak.rmtAlertObj=rmt_alert;% Keep it in the singles line obj so that we can update it when the line object is updated.

         % Previous peak2peak
         % The previous peak2peaks will be plotted on the average axis
         y=NaN(1,EPR.viewerPreviousP2pBufferLen);
         x=linspace(EPR.viewerTimeWin(1),EPR.viewerTimeWin(2),length(y));%we don't care about what these values are, we just use then to plot the p2p.
         prev_p2p_line=plot(avg_ax,x,y,'.g','markersize',25,'DisplayName','Previous peak2peaks');
         
         % Keep it in the singles line obj so that we can update it when
         % the line object is updated.
         lne.UserData.peak2peak.lineObj=prev_p2p_line;

         % Special datatip for the previouse peak2peaks
         prev_p2p_line.DataTipTemplate.DataTipRows(2).Label="Previous Peak2peak";

         row = dataTipTextRow("n(latest=0)",flip(1:EPR.viewerPreviousP2pBufferLen)-1);
         prev_p2p_line.DataTipTemplate.DataTipRows(1) = row;

         
         % Highest peak2peak
         % The highest peak2peaks will be plotted on the average axis
         
         y=[NaN,NaN];
         x=[EPR.viewerTimeWin(1),EPR.viewerTimeWin(2)];%we don't care about what these values are, we just use then to plot the p2p.
         largest_p2p_line=plot(avg_ax,x,y,'--g','DisplayName','Run largest peak2peak','LineWidth',1.3);
         
         % Keep it in the singles line obj so that we can update it when
         % the line object is updated.
         lne.UserData.peak2peak.largestLineObj=largest_p2p_line;

         % Special datatip for the largest peak2peak
         largest_p2p_line.DataTipTemplate.DataTipRows(2).Label="Largest Peak2peak";         
     end

end




function eprecorder_single_axis_ydata_change_callback(src,evt)
    % Performs additional operations when ydata changes on an axis.
    % The operations include:
    % - Determine and display peak2peak value.
    % 
    %

    is_new_event=false;

    % We keep count of the number of events in each event object, just
    % so we can detect change when this number increases.
    if(~isfield(evt.AffectedObject.UserData,'number_of_change_events'))
        evt.AffectedObject.UserData.number_of_change_events=0;% 
    end
    evt.AffectedObject.UserData.number_of_change_events=evt.AffectedObject.UserData.number_of_change_events+1;
    

    % Update the number of events
    if(EPR.temp.number_of_change_events < evt.AffectedObject.UserData.number_of_change_events)
        EPR.temp.number_of_change_events=evt.AffectedObject.UserData.number_of_change_events;

        % This is a new event since the number of events has increased
        is_new_event=true;
    end
    
    if(is_new_event)
        
        % We use this oppurtunity to display infor that are done only onece per
        % event, rather than per event object on every event

        % Update the number of trials displayed; which needs to be done only once per
        % trial
        EPR.temp.viewerAnnotationObj.String=['STIMULUS CODE: ',mat2str(EPR.stimulusCode),'    FRAME TIME: ',mat2str(EPR.online.viewerTriggerTimes(end)),'s.    FRAMES^1: ~',mat2str(EPR.temp.number_of_change_events)];
    end

    %
    if(EPR.enableP2p)
        show_peak2peak(evt.AffectedObject);

        update_rmt_alert(evt.AffectedObject);
    end

end

function show_peak2peak(lineObj)
    %% Determine and display peak2peak value for the given line object.
    % [INPUT]
    % lineObj: Matlab line object such as that returned by plot(...).

    p2pWin=floor(EPR.viewerP2pTimeWin*EPR.Fs/1000)+1;%change to samples. and then add 1 to cater for matlab index starting from 1.

    % The data we recieve does not necessarily start from time=0, instead it is between
    % within viewer time window, so we need to offset peak2peak window with the
    % start of viewer window 
    viewerWin=floor(EPR.viewerTimeWin*EPR.Fs/1000)+1;%change to samples. and then add 1 to cater for matlab index starting from 1.
    p2pWin=p2pWin-viewerWin(1) +1;% offset with viewer starting point. We also need to add 1 again since offset result of e.g 0 will actuall be 1 in matlab indexing. 
    p2pWin(p2pWin<1)=1;% reject numbers less than 1.

    % Now read the required offset peak2peak win.
    peak2peak_data=lineObj.YData(p2pWin(1):p2pWin(2));
    
    minVal=min(peak2peak_data);
    minValIdx=find(peak2peak_data==minVal);% find the first occurance of min data
    minValIdx=p2pWin(1)+minValIdx(1);% the index of the min value with respect to the viewer.

    maxVal=max(peak2peak_data);
    maxValIdx=find(peak2peak_data==maxVal);
    maxValIdx=p2pWin(1)+maxValIdx(1);%the index of the max value with respect to the viewer.

    p2p=round(maxVal-minVal,3);%peak to peak value

    % Previous peak to peaks
    previous_peak2peaks=lineObj.UserData.peak2peak.lineObj.YData;
    % do fifo
    previous_peak2peaks=flip(previous_peak2peaks);%we have to flip to do fifo
    previous_peak2peaks(2:end)=previous_peak2peaks(1:end-1);
    previous_peak2peaks(1)=p2p;
    
    
    
    % Get the largest peak2peak sofar
    largest_p2p=lineObj.UserData.peak2peak.largestLineObj.YData;
    largest_p2p=largest_p2p(1);
    if(isnan(largest_p2p)||p2p>largest_p2p)
        largest_p2p=p2p;
        set(lineObj.UserData.peak2peak.largestLineObj,'YData',[p2p,p2p]);
    end
    

    % Update min marker
    set(lineObj.UserData.peak2peak.single_marker_min,'YData',minVal);
    set(lineObj.UserData.peak2peak.single_marker_min,'XData',lineObj.XData(minValIdx));

    % Update max maker
    set(lineObj.UserData.peak2peak.single_marker_max,'YData',maxVal);
    set(lineObj.UserData.peak2peak.single_marker_max,'XData',lineObj.XData(maxValIdx));

    % Peak2peak txt
    data_unit=EPR.channelUnits{lineObj.UserData.viewer_channel};
    lineObj.UserData.peak2peak.single_marker_txt.String=[mat2str(p2p),' ',data_unit,' p2p (largest:',mat2str(largest_p2p),')'];


    %position peak2peak text
    marker_text_time_offset=5;% An offset to control the position of the marker text along the time axis.
    lineObj.UserData.peak2peak.single_marker_txt.Position=[lineObj.XData(maxValIdx)+marker_text_time_offset,maxVal,0];

    % Update peak to peaks plot
    set(lineObj.UserData.peak2peak.lineObj,'YData',flip(previous_peak2peaks));% the peak2peak was recorded with fifo, we flip it here so that the latest value is ploted rightmost.
    
    
end

function update_rmt_alert(lineObj)
    % Update the rmt alert depending on whether we have hit RMT or not, for
    % the given line object. 
    %
    % [INPUT]
    % lineObj: Matlab line object such as that returned by plot(...)
    %
    peak2peaks=lineObj.UserData.peak2peak.lineObj.YData;

    % Check if we have the required number of peak2peaks. The buffer was
    % initialised with NaNs so the presence of NaN is indicates unfilled
    % buffer.
    has_full_buffer=true;
    if any(isnan(peak2peaks))
        has_full_buffer=false;
    end
    
    %
    hit=false;

    if(has_full_buffer)
        channel_idx=line_to_channel_index(lineObj);
        thresh=EPR.p2pThresh(channel_idx);
    
        % Approximation of standard RMT criteria.
        % Note that this is only an approximation to standard RMT which is
        % defined as the least intensity to elicit EP of peak2peak of
        % magnitude >= threshold for AT LEAST HALF of the time. But here we
        % are approximating it at exactly half of the time.
        rmt_criteria=0.5;%i.e if half of the peak2peak >= peak2peak threshold, then we are at RMT. 
        active=length(find(peak2peaks>=thresh));% number of peak2peaks >= peak2peak threshold
        if(active==round(length(peak2peaks)*rmt_criteria) )
            hit=true;
        end
    end

    visible='Off';
    if(hit)
        visible='On';
    end

    lineObj.UserData.peak2peak.rmtAlertObj.Visible=visible;

end

function channel_idx=line_to_channel_index(lineObj)
    % Get the data channel index that is associated to the given single
    % axes line (i.e non-average) line. 
    %
    % [INPUT]
    % lineObj: Matlab line object such as that returned by plot(...).
    channel_idx=lineObj.UserData.viewer_channel;
end

function current_trigger_time=currentViewerTriggerTime()
    % Return the time of the latest trigger aknowledged/processed by the
    % viewer 
    % [OUTPUT]
    % current_trigger_time: double Trigger time in seocnds.
    current_trigger_time=EPR.online.viewerTriggerTimes(end);
end

function toggleFrameRejectMark(src,event)
    % Mark the current frame/epoch as rejected or not.
    % 

    if(isempty(EPR.online.triggerTimes))
        error('No trigger times found')
    end

    current_trig_time=currentViewerTriggerTime();
    found=EPR.online.rejectTriggerAtTimes==current_trig_time;

    feedback_str='  -  Rejected';
    
    if(any(found))
        EPR.online.rejectTriggerAtTimes(found)=[];
        EPR.temp.viewerAnnotationObj.String=strrep(EPR.temp.viewerAnnotationObj.String,feedback_str,'');
    else
        EPR.online.rejectTriggerAtTimes(end+1)=current_trig_time;
        EPR.temp.viewerAnnotationObj.String=[EPR.temp.viewerAnnotationObj.String ,feedback_str];
    end
end


function editFrameNote(src,event)
    %  Edit the note of the current frame/epoch.
    % 
    
    if(isempty(EPR.online.triggerTimes))
        error('No trigger times found')
    end

    current_trig_time=currentViewerTriggerTime();
    
    
    note='';
    [note_entry,note_idx]=note_entered_online_for(EPR,current_trig_time);
    if(~isempty(note_entry))
        note=note_entry{2};
    end

    for n_note=1:length(EPR.online.notes)
        note_entry=EPR.online.notes{n_note};
        if(note_entry{1}==current_trig_time)
            note=note_entry{2};
            note_idx=n_note;
        end
    end

    note_new=inputdlg('note','Frame note',3,{note});
    if(~isempty(note_new))
        note=note_new{1};
    end
    
    if(isempty(note_idx))
        note_idx=length(EPR.online.notes)+1;
    end

    EPR.online.notes{note_idx}={current_trig_time,note};

end

end

