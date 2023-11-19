function runEPR

global EPR;
EPR.version='v0.3.7';
%dataCollection=-1;

f=figure('name',['Evoked Potential Recording (EPR) tool ' EPR.version ' - Bethel Osuagwu'],'toolbar','none','NumberTitle','off','Tag','epr-main-gui','menubar','none');

side_str=EPR.sides;
target_str=EPR.targets;
timepoint_str=EPR.timepoints;
whitclr=[1,1,1];

sId_label=uicontrol('style','text','string','Subject ID','units','normalized','position',[0.05,0.8,0.1,0.05]);
sId_edit=uicontrol('BackgroundColor',whitclr, 'style','edit','string',EPR.subjectId,'units','normalized','position',[0.155,0.8,0.1,0.05]);

sN_label=uicontrol('style','text','string','Section #','units','normalized','position',[0.3,0.8,0.1,0.05]);
sN_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',EPR.sectionN,'units','normalized','position',[0.405,0.8,0.1,0.05]);

trial_label=uicontrol('style','text','string','Trial #','units','normalized','position',[0.55,0.8,0.1,0.05]);
trial_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',EPR.subsection,'units','normalized','position',[0.655,0.8,0.1,0.05]);

side_label=uicontrol('style','text','string','Side','units','normalized','position',[0.3,0.88,0.1,0.05]);
side_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',side_str,'units','normalized','position',[0.405,0.88,0.1,0.05]);

uicontrol('style','text','string','Target','units','normalized','position',[0.55,0.88,0.1,0.05]);
target_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',target_str,'units','normalized','position',[0.655,0.88,0.1,0.05]);


timepoint_label=uicontrol('style','text','string','Timepoint','units','normalized','position',[0.05,0.88,0.1,0.05]);
timepoint_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',timepoint_str,'units','normalized','position',[0.155,0.88,0.1,0.05]);

condition_label=uicontrol('style','text','string','Condition','units','normalized','position',[0.05,0.72,0.1,0.05]);
condition_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',EPR.conditions,'units','normalized','position',[0.155,0.72,0.1,0.05]);

param_label=uicontrol('style','text','string','Param','units','normalized','position',[0.3,0.72,0.1,0.05]);
param_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',EPR.params,'units','normalized','position',[0.405,0.72,0.1,0.05]);

tag_label=uicontrol('style','text','string','Tag','units','normalized','position',[0.55,0.72,0.1,0.05]);
tag_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',EPR.tag,'units','normalized','position',[0.655,0.72,0.1,0.05], 'Callback',@tagOnchange_Callback);

uicontrol('style','text','string','Ready tags','units','normalized','position',[0.8,0.68,0.1,0.05]);
tags_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',[{''},EPR.tags],'units','normalized','position',[0.8,0.72,0.1,0.05],'Callback',@tagsOnchange_Callback,'Tooltip','Read made tags');

note_label=uicontrol('style','text','string','Note','units','normalized','position',[0.05,0.64,0.1,0.05]);
note_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',EPR.note,'units','normalized','position',[0.155,0.64,0.1,0.05]);


% Viewer settings
viewer_chnls_label=uicontrol('style','text','string','Viewer Cha','units','normalized','position',[0.05,0.55,0.1,0.05]);
viewer_chnls_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',mat2str(EPR.viewerChannels),'units','normalized','position',[0.155,0.55,0.1,0.05]);

viewer_time_win_label=uicontrol('style','text','string','Viewer win','units','normalized','position',[0.3,0.55,0.1,0.05]);
viewer_time_win_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',mat2str(EPR.viewerTimeWin),'units','normalized','position',[0.405,0.55,0.1,0.05]);

enable_viewer_label=uicontrol('style','text','string','Enbl View.','units','normalized','position',[0.55,0.55,0.1,0.05]);
enable_viewer_edit=uicontrol('BackgroundColor',whitclr,'style','checkbox','min',0,'max',1,'units','normalized','position',[0.655,0.55,0.1,0.05]);

uicontrol('style','text','string','V. p2p win','units','normalized','position',[0.7,0.55,0.1,0.05]);
viewer_p2p_time_win_edit=uicontrol('BackgroundColor',whitclr,'style','edit','string',mat2str(EPR.viewerP2pTimeWin),'units','normalized','position',[.8,0.55,0.1,0.05],'Tooltip','Viewer peak2peak time windows. Should be within viewer time window');



% Recording
uicontrol('style','text','string','Rec len','units','normalized','position',[0.05,0.45,0.1,0.05]);
rec_len_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',EPR.recLengths,'units','normalized','position',[0.155,0.45,0.1,0.05]);

% Stimulus code
uicontrol('style','text','string','Stim code','units','normalized','position',[0.3,0.45,0.1,0.05]);
stimulus_code_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',EPR.stimulusCodes,'units','normalized','position',[0.405,0.45,0.1,0.05],'Callback',@stimulusCodeOnchange_Callback);

% Stimulus button
stimulusBtn=uicontrol('style','pushbutton','string','Stimulate','units','normalized','fontweight','bold','position',[0.55,0.45,0.1,0.05],'callback',@stimulusBtn_Callback);

%% Settings to figure
tf=strcmp(EPR.side,side_str);
if any(tf)
    set(side_edit,'value',find(tf));
end

tf=strcmp(EPR.timepoint,timepoint_str);
if any(tf)
    set(timepoint_edit,'value',find(tf));
end

tf=strcmp(EPR.target,target_str);
if any(tf)
    set(target_edit,'value',find(tf));
end

tf=strcmp(EPR.condition,EPR.conditions);
if any(tf)
    set(condition_edit,'value',find(tf));
end

tf=strcmp(EPR.param,EPR.params);
if any(tf)
    set(param_edit,'value',find(tf));
end

tf=strcmp(EPR.tag,EPR.tags);
if any(tf)
    set(tags_edit,'value',find(tf));
end

set(enable_viewer_edit,'value',EPR.enableViewer);

tf=(EPR.recLength==EPR.recLengths);
if any(tf)
    set(rec_len_edit,'value',find(tf));
end

tf=(EPR.stimulusCode==EPR.stimulusCodes);
if any(tf)
    set(stimulus_code_edit,'value',find(tf));
end


% Operations
saveSettingsBtn=uicontrol('style','pushbutton','string','Apply','units','normalized','fontweight','bold','position',[0.05,0.35,0.1,0.05],'callback',@saveSettingsBtn_Callback);
%startrec=uicontrol('style','edit','string','s1_s1_thumbMovement.mat');
startMdlBtn=uicontrol('style','pushbutton','string','Start recording','units','normalized','fontweight','bold','position',[0.203,0.35,0.2,0.05],'callback',@startMdlBtn_Callback);
startNoRecMdlBtn=uicontrol('style','pushbutton','string','Start with no recording','units','normalized','fontweight','bold','position',[0.458,0.35,0.3,0.05],'callback',@starNoRecMdlBtn_Callback);
stopMdlBtn=uicontrol('style','pushbutton','string','Stop','units','normalized','fontweight','bold','position',[0.8,0.35,0.1,0.05],'enable','off','Tag','epr-stop-btn','callback',@stopMdlBtn_Callback);

% Actions
action_names={};
for action_n=1:size(EPR.actions,1)
    action=EPR.actions{action_n};
    action_names{action_n}=action{1};
end
uicontrol('style','text','string','Actions ','units','normalized','position',[0.68,0.1,0.1,0.1]);
actions_edit=uicontrol('BackgroundColor',whitclr,'style','popupmenu','string',action_names,'units','normalized','position',[0.7,0.06,0.2,0.1],'callback',@actions_Callback);


%create info
hlpTxt=sprintf('Evoked \nPotential \nRecorder \n(EPR)');
hlpTxt_label=uicontrol('BackgroundColor',[0.8 0.8 0.8],'style','text','string',hlpTxt,'units','normalized','position',[0.78,0.8,0.27,0.2],'fontunits','normalized','fontsize',0.21,'fontweight','bold','ForegroundColor',[0.5,0.8,0.2],'HorizontalAlignment','center');

status_lable=uicontrol('BackgroundColor',[0.8 0.8 0.8],'style','text','string','Ready','units','normalized','position',[0.05,0.1,0.5,0.1],'fontunits','normalized','fontsize',0.70,'fontweight','bold','ForegroundColor',[0.5,0.8,0.2],'HorizontalAlignment','center');

detailsTxt=sprintf('Model: %s.          Fs: %s Hz.\nData folder: %s.',[EPR.modelFile ',' EPR.model],mat2str(EPR.Fs),EPR.dataFolder);
uicontrol('style','text','string',detailsTxt,'units','normalized','position',[0.05,0.008,0.48,0.06],'fontunits','normalized','fontsize',0.40,'HorizontalAlignment','left');

% Info Keys
annotation('textbox',...
    [0.52 0.015 0.46 0.09],...
    'Color',[1 0.0745098039215686 0.650980392156863],...
    'String',{'Keys:','^1Triggers may be missed, so FRAMES is approx.'},...
    'FontSize',8,...   'FontAngle','italic',...
    'FitBoxToText','off',...
    'EdgeColor',[0.901960784313726 0.901960784313726 0.901960784313726]);


% Preload system so its easy to relaod later when starting Mdl
load_system(EPR.modelFile);
if hasSeparateTriggerModel()
    load_system(EPR.stimulusTriggerModelFile);
end

% Get handles of blocks.
stimTrigBlockHandle=getSimulinkBlockHandle([EPR.stimulusTriggerModel '/Stimulus/trigger']); 

    function startMdlBtn_Callback(source,event)
           % Reload system incase it has been closed
           load_system(EPR.modelFile);

           if hasSeparateTriggerModel()
                load_system(EPR.stimulusTriggerModelFile);
            end
           stimTrigBlockHandle=getSimulinkBlockHandle([EPR.stimulusTriggerModel '/Stimulus/trigger']);
           
           updateSettings();

           if(exist(EPR.fn2,'file'))
               warndlg([EPR.fn2,' exists. it seems data has already been recorded with these settings. Change at least the "trial #."'],'Overwrite data');
               return;
           end
           
           enableInputs('off');
           set(stopMdlBtn,'enable','on');
           setStatus('Sooooooo busy!');
        
           
        set_param(EPR.model,'SimulationCommand','Stop');
        set_param([EPR.model '/EPRCore/dataRecording'],'value','1');
        set_param([EPR.model '/EPRCore/doRecording/To File'],'filename',EPR.fn2)
        set_param(EPR.model,'StopTime',mat2str(EPR.recLength));

        if(stimTrigBlockHandle~=-1)
            set_param(stimTrigBlockHandle,'value','0');
        end
        
        set_param(EPR.model,'SimulationCommand','Start');
        if hasSeparateTriggerModel()
            set_param(EPR.stimulusTriggerModel,'SimulationCommand','Start');
        end
        
    end
    function starNoRecMdlBtn_Callback(source,event)
        load_system(EPR.modelFile);% Reload system in case it has been closed
        if hasSeparateTriggerModel()
            load_system(EPR.stimulusTriggerModelFile);
        end
        stimTrigBlockHandle=getSimulinkBlockHandle([EPR.stimulusTriggerModel '/Stimulus/trigger']);

        updateSettings();
        
        enableInputs('off');
        set(stopMdlBtn,'enable','on');
        setStatus('Quite busy, no rec');
        
        set_param(EPR.model,'SimulationCommand','Stop');
        set_param([EPR.model '/EPRCore/dataRecording'],'value','0');
        set_param(EPR.model,'StopTime','inf')
        
        set_param([EPR.model '/EPRCore/doRecording/To File'],'filename','EPRNoData.mat')

        if(stimTrigBlockHandle~=-1)
            set_param(stimTrigBlockHandle,'value','0');
        end

        set_param(EPR.model,'SimulationCommand','Start');
        if hasSeparateTriggerModel()
            set_param(EPR.stimulusTriggerModel,'SimulationCommand','Start');
        end
    end
    function saveSettingsBtn_Callback(source,event)
       updateSettings();
       
       msgbox('Settings saved','Save settings')
    end

    function stopMdlBtn_Callback(source,event)
        try
            set_param(EPR.model,'SimulationCommand','Stop');
            if hasSeparateTriggerModel()
                set_param(EPR.stimulusTriggerModel,'SimulationCommand','Stop');
            end
        catch me
            % The models may not be loaded but that is fine.
        end
        enableInputs('on');
        setStatus('Ready for you');
        set(stopMdlBtn,'enable','off');
    end

    function actions_Callback(src,event)
        % Execute a callback of an action with current EPR variable as argument.
        
        
        % Get the action
        idx=get(src,'Value');
        action=EPR.actions{idx};
        action_callback=action{2};

        % call the action
        if(exist(EPR.fn2,'file'))
            c=load(EPR.fn2);
            action_callback(c.EPR);
        else
            action_callback(EPR);
            disp('No file has been recorded')
        end
        
    end
    
    function tagOnchange_Callback(src,event)
        % Reset the selested value of the ready made tags since the value
        % of tag is being chnaged directly
        set(tags_edit,'Value',1);
    end
    function tagsOnchange_Callback(src,event)
        tags=get(src,'String');
        idx=get(src,'Value');

        % return to prevent possible endless loop b/w callbacks of
        % tag_edit and tags_edit. Currently no loop is occuring.
        %if(idx==1),return;end% idx=>1 is empty selection

        tag=tags{idx,:};

        % Set the value of the ready made tag
        set(tag_edit,'String',tag);
    end
    function stimulusCodeOnchange_Callback(src,event)
        codes=get(src,'String');
        idx=get(src,'Value');
        code=str2double(codes(idx,:));

        EPR.stimulusCode=code;

        set_param([EPR.model '/EPRCore/stimulusCode'],'value',mat2str(code));
    end

    function stimulusBtn_Callback(src,event)
        
        if(stimTrigBlockHandle==-1)
            error('The stimulus trigger block could not be found');
        end

            
        if ~isfield(EPR.online,'stimulus')
            EPR.online.stimulus.count=0;
        end
        EPR.online.stimulus.count=EPR.online.stimulus.count+1;

        set_param(stimTrigBlockHandle,'value',mat2str(EPR.online.stimulus.count));
    end

    function hasSeparate=hasSeparateTriggerModel()
        % Check if a separate model exists for stimulus trigger.
        hasSeparate=all([~isempty(strtrim(EPR.stimulusTriggerModelFile)), ~strcmp(EPR.modelFile,EPR.stimulusTriggerModelFile)]);
    end

    function setStatus(txt)
        %% Set the status of the app
        % txt=the status status
        set(status_lable,'string',txt);
    end
    function is_valid= validateSettings()
        % Validate the settings values and for now silently correct bad
        % settings.

        % The peak2peak time wim must be within the viewer time win
        p2p_time_win=str2num(get(viewer_p2p_time_win_edit,'string'));
        p2p_time_win_copy=p2p_time_win;
        if(EPR.viewerTimeWin(1)>p2p_time_win(1))
            p2p_time_win(1)=EPR.viewerTimeWin(1);
        end
        if(EPR.viewerTimeWin(2)<p2p_time_win(2))
            p2p_time_win(2)=EPR.viewerTimeWin(2);
        end
        
        if(any(p2p_time_win_copy-p2p_time_win))
            % silent correction
            set(viewer_p2p_time_win_edit,'string',mat2str(p2p_time_win))
        end

        is_valid=true;
    end
    function updateSettings()
            
            validateSettings();
            
           EPR.subjectId =get(sId_edit,'string');
           EPR.sectionN= str2double(get(sN_edit,'string'));
           EPR.subsection= str2double( get(trial_edit,'string'));


            v=get(side_edit,'value');
           EPR.side=(side_str{v});

           v=get(timepoint_edit,'value');
           EPR.timepoint=(timepoint_str{v});

            v=get(target_edit,'value');
            EPR.target=(target_str{v});

            v=get(condition_edit,'value');
            EPR.condition=(EPR.conditions{v});

            v=get(param_edit,'value');
            EPR.param=(EPR.params{v});

            EPR.tag= get(tag_edit,'string');

            EPR.enableViewer=0;
            if (get(enable_viewer_edit,'Value') == get(enable_viewer_edit,'Max'))
                EPR.enableViewer=1;
            end

            EPR.viewerChannels= str2num( get(viewer_chnls_edit,'string'));
            EPR.viewerTimeWin= str2num( get(viewer_time_win_edit,'string'));
            EPR.viewerP2pTimeWin=str2num(get(viewer_p2p_time_win_edit,'string'));

            EPR.note= get(note_edit,'string');

            v=get(rec_len_edit,'value');
            EPR.recLength=(EPR.recLengths(v));

           EPR.date=now;

           fd=eprecorder_make_folder_name(EPR.dataFolder,EPR.subjectId,EPR.timepoint,EPR.sectionN);
           if(~exist(fd ,'dir'))
                mkdir(fd)
           end
           %EPR.fn2=[fd EPR.subjectId '_s' mat2str(EPR.sectionN) '_' EPR.timepoint '_' EPR.side '_' EPR.condition '_' EPR.tag '_s' mat2str(EPR.subsection) '.mat'];%syntax for filename of saved data;
           EPR.fn2=makeFilename(EPR.subjectId,EPR.sectionN,EPR.timepoint,EPR.side,EPR.target,EPR.condition,EPR.subsection,EPR.tag);
           EPR.fn2=[fd,EPR.fn2];
    end
    

    function enableInputs(enable_state)
        %% Enable of disable all inputs
        % 
        % enable_state={'on','off','inactive'}
        %
        
        % TODO instead of creating this cell array, we culd just get all
        % the children of the figure programatically so that we don't need
        % to come here every time we add a new item
        ui_inputs={actions_edit,saveSettingsBtn,startMdlBtn,startNoRecMdlBtn,stopMdlBtn, sId_edit,sN_edit,trial_edit,side_edit,target_edit,timepoint_edit,condition_edit,param_edit,param_edit,tag_edit,tags_edit,note_edit,viewer_chnls_edit,viewer_time_win_edit,enable_viewer_edit,viewer_p2p_time_win_edit,rec_len_edit};
        for n=1:length(ui_inputs)
            set(ui_inputs{n},'enable',enable_state);
        end

        
    end


set_param([EPR.model '/EPRCore/dataRecording'],'value','0');

set_param([EPR.model '/EPRCore/stimulusCode'],'value',mat2str(EPR.stimulusCode));
%close_system('zebris_measure.mdl');
end

