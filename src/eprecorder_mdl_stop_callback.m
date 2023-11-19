
% No need to keep temp data field added online. Also no particular reason
% reason to remove it also apart discarding unwanted info.
EPR=rmfield(EPR,'temp');

% Save data if required
if str2double(get_param([EPR.model '/EPRCore/dataRecording'],'value'))==1
      load(EPR.fn2);
      EPR.data=EPdata;
      save(EPR.fn2,'EPR');

      msgbox(['Success, end of recording. "' EPR.fn2 '" is saved'],'End of recording');
      clear EPdata
     set_param(EPR.model,'StopTime','inf')
end

% Click the stop btn on figure if is not clicked already

epr_main_guis=findobj('Tag','epr-main-gui');

for n=1:length(epr_main_guis)
    epr_stop_btn=findobj(epr_main_guis(n),'Tag','epr-stop-btn');
    if(length(epr_stop_btn)==1)
        if strcmp(get(epr_stop_btn(1),'enable'),'on')
            epr_stop_btn_callback_=get(epr_stop_btn(1),'callback');
            epr_stop_btn_callback_(epr_stop_btn(1),[]);
        end
    end
end

% Disable buttons that are only available online
epr_disable_btn=findobj('Tag','epr-toggle-frame-reject-mark-btn');
epr_disable_btn.Enable='off';

epr_disable_btn=findobj('Tag','epr-edit-frame-note-btn');
epr_disable_btn.Enable='off';




% Clear up
clear epr_main_guis epr_stop_btn epr_stop_btn_callback_ epr_diable_btn
