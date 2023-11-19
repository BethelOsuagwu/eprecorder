global EPR

%% General
EPR.subjectId='testsubject';
EPR.sectionN=3;
EPR.subsection=1;
EPR.condition='cond_1';%
EPR.conditions={'cond_1','cond_3'};
EPR.param='param_1';% (Currently not used in filenames)
EPR.params={'param_1','param_2'};
EPR.tag='';
EPR.tags={'tag1','tag2'};% Ready made tags
EPR.side='Left-Right';
EPR.sides={'Left','Right','Top','Bottom','Centre','Middle','Left-Right','Top-right','Top-left','Bottom-right','Bottom-left','Front','Back','Others'};
EPR.target='lumber-spine';% 
EPR.targets={'median','ulnar','flexor','extensor','FDS','EDC','hand','leg','lumber-spine','others'};% 
EPR.timepoint='pre';
EPR.timepoints={'pre','mid','post','follow-up','others'};
EPR.date=now;

EPR.info='';
EPR.note='';

%% Data
EPR.data=0;
EPR.Fs=4000;
EPR.channelNames={'Ch1','Ch2','Ch3','Ch4','Ch5','Ch6'};%Channls Excluding the trigger chan. NOTE:
EPR.channelUnits={'raw','raw','raw','raw','raw','raw'};% The units of the data in the channels which have the same number of entries as channels names

%% Peak2peak
EPR.enableP2p=1;%{0=>no, 1=>yes}
EPR.p2pThresh=[0.05,0.05,0.05,0.05,0.05,0.05]; %Peak to peak threshold for each channel in corresponding channelUnits. Must correspond to channelNames. Useful for determining resting motor threshold.

%% Viewer
EPR.enableViewer=1;%{0=>no, 1=>yes}
EPR.viewerChannels=[1,2,3,4,5,6]; %Index to channelNames
EPR.viewerChannelLims={[-3.2,3.2],[],[],[],[],[]};% ylim for each channel. Index of entries correspond to channelNames. Must have the same size as channelNames. Entry with empty matrix indicates no limits.
EPR.viewerTimeWin=[-2,60];% A two element time window in ms. Must lie within one trigger else some subsequent triggers will be ignored.s
EPR.viewerP2pTimeWin=[max(EPR.viewerTimeWin(1),5), min(EPR.viewerTimeWin(2),40)];% TODO: put on the figure % Peak2peak time window of interest in ms. 
EPR.viewerPreviousP2pBufferLen=5;%the number of previous peak to peaks to display.

%% Stimulus
EPR.stimulusTriggerPulseWidth=1;% Stimulus trigger pulsewidth in miliseconds. 

% In milliseconds. Array of entries where each entry is a secondary trigger
% inter stimulus interval relative to the primary stimulus trigger. 
% Currently, only 9 secondary ISIs are implemented. E.g. for 50ms separated
% paired stimulation, set ISI=[50,0,0,0,0,0,0,0,0]; for 3 pulses separated
% by 50ms, set ISI=[50,100,0,0,0,0,0,0,0]. Set to ISI=[0,0,0,0,0,0,0,0,0] 
% to disable the secondary triggers.
EPR.ISI=[0,0,0,0,0,0,0,0,0];%NEW

% Stimulus codes - Set of NUMERIC stimulus intensities/codes.
EPR.stimulusCodes=1:120;
EPR.stimulusCode=20;% This will be recorded on a separate channel dynamically(i.e you can change it while simulation is running).

%% Data storage folder
EPR.dataFolder=[pwd '/data'];

%% Simulink model
EPR.model='EPRModel';
EPR.modelFile='EPRModel.slx';
EPR.stimulusTriggerModel=EPR.model;%NEW
EPR.stimulusTriggerModelFile=EPR.modelFile;%NEW

%% Recording length
EPR.recLength=200;%length of time to record data in seconds if not stopped manually. 
EPR.recLengths=[1,2,3,4,5,10,15,30,60,200,500,inf];


%% Add the src path to EPRecorder in use
addpath([pwd '/src']);

%% User defined actions
% An N by 1 array of cells, where each entry is a two element cell, where
% the first element of the cell is the name of the action and the second is
% callback hanble. The callback will be called with EPR variable as input.   
EPR.actions={
                {'Quick recruitment curve',@eprecorder_recruitment_curve_quick};
            };


%================================================================
%====== STOP CHANGING ===========================================
%================================================================

%% File
EPR.fn2=''; % Ful filename of the resulting dataset.

%% Online system fields - 
% The following fields are only listed here so that their structure can be
% described. ANY VALUE ASSINGED TO THEM HERE WILL BE DISCARDED.
EPR.online.triggerTimes=[];% Times in seconds for triggers detected online for a run. This may be used in place of the trigger channel to trigger the data.
EPR.online.viewerTriggerTimes=[]; % The trigger times that were recieved and and aknowledged/processed by the online viewer. With respect to EPR.viewerTimeWin, these triggers do not collide with each other.
EPR.online.rejectTriggerAtTimes=[];% Times in seconds at which underlying triggers are marked as rejected. The corresponding frames/epochs will be auto regjected online
EPR.online.notes={{3,'note1'},{2,'note2'}}; % Trigger notes.A cell array where each entry is a 2 element cell with the 1st entry as trigger time in seconds and the 2nd a note.

%% Open GUI
runEPR;