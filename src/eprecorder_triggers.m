function [trigs,trig_events,notes,secondary_trigs]=eprecorder_triggers(EPR,trigger_magnitude,primary,secondary_tau)
% Return the trigger points and the related details. Rising edge detection
% using derivative is used.
% [INPUT]
% EPR: EPRecorder main data strcture
% trigger_magnitude double: Transition in the trigger channel that are
%   considered as trigger. A value in the trigger channel derivative higher
%   than or equal to this is considered a trigger. The default is 1. 
% primary bool: If true the secondary stimulus triggers will be removed.
%   The default is true.
% secondary_tau int: Secondary trigger detection tolorance in samples. The
%   relative number of samples with which to widen the segment searched
%   for secondary triggers. The default is  a fourth of the smallest ISI,
%   or 0 if ISI is not defined. 
% [OUTPUTS]
% trigs: Trigger points in samples
% trig_events: The event codes(stimulus codes) associated to the trigger
%   points 
% notes: Notes for frames/epochs. They are copied from EPR.online.notes. 
% secondary_trigs array<int>: Trigger point samples for secondary trigger.
%   The size=len(trigs) x len(find(EPR.ISI)). The rows corresponsd to the primary
%   triggers in output 'trigs' while the columns corresponds to the EPR.ISI
%   values. A nan value indicates a missing secondary trigger.

    if nargin < 2
        trigger_magnitude=1;
    end

    if nargin < 3
        primary=true;
    end

    if nargin < 4
        secondary_tau=0;
        [~,isi]=eprecorder_stimulus_numbers(EPR);
        if(length(isi)>1)
            isi_min=min(isi(2:end));
            secondary_tau=round(isi_min/4/1000*EPR.Fs);% choose arbitrary tau.
        end
    end


    data=EPR.data;
    Trg=data(end-1,:);% the 2nd to last channel is the trigger channel
    events=data(end,:);% last channel is the event

    % Rising edge detection using derivative
    Trg=[0,diff(Trg)];
    T=find(Trg>=trigger_magnitude);

    trigs=T;
    if primary
        trigs=removeSecondaryTriggers(EPR,T,secondary_tau);
    end

    trig_events=events(trigs);

    % Get secondary triggers
    secondary_trigs=[];
    if canContainSecondatryTrigger(EPR)
        for n=1:numel(trigs)
            secondary_trigs(n,:)=getSecondaryTriggers(EPR,T,trigs(n),secondary_tau);
        end
    end
            

    % gets corresponding online notes
    notes={};
    for n=1:length(trigs)
        note_entry=note_entered_online_for(EPR,trigs(n));
        notes{end+1}=note_entry;
    end
    
end
function can=canContainSecondatryTrigger(EPR)
    % Check if the given EPR can have secondary trigger.
    % 
    % [INPUT]
    % EPR struct: EPR data structure
    % [OUTPUT]
    % can bool: True if the structure can contain secondary trigger.

    can=false;
    if length(eprecorder_stimulus_numbers(EPR))>1
        can=true;
    end
end
function TPrimary=removeSecondaryTriggers(EPR,triggers,secondary_tau)
    % Remove triggers for to the secondary stimulus(i.e EPR.ISI(1...end)).
    %
    %
    % [INPUT]
    % EPR struct: EPR data structure
    % triggers array<double>: 1-D array The triggers of primary and
    %   secondary stimuli.
    % secondary_tau int: Secondary trigger detection tolorance in samples. The
    %   relative number of samples with which to widen the segment searched
    %   for secondary triggers.
    % [OUTPUT]
    % TPrimary array<double>: The triggers of only the primary stimuli.
    
    tau=secondary_tau;

    TPrimary=triggers;

    if ~canContainSecondatryTrigger(EPR)
        return;
    end


    % Sort ISI and get the first and last
    [~,ISI]=eprecorder_stimulus_numbers(EPR);
    ISI=sort(ISI);
    ISIRelativeRange=[ISI(1),ISI(end)]/1000*EPR.Fs;

    % Adjust the ISI with tau
    ISIRelativeRange=ISIRelativeRange(1)-tau : ISIRelativeRange(end)+tau;
    

    T_secon=[];
    for i=1:length(triggers)
        ti=triggers(i);
        for j=1:length(triggers)
            tj=triggers(j);
            if ti==tj
                continue;
            end

            ISIAbsoluteRange=ti+ISIRelativeRange;
            if ismember(tj,ISIAbsoluteRange)
                T_secon(end+1)=tj;
            end
        end
    end

    for t=reshape(T_secon,1,[])% Reshape to force T_second to be row vector.
        TPrimary(TPrimary==t)=[];
    end

end

function  Tsecondary=getSecondaryTriggers(EPR,T,primary_trigger,secondary_tau)
    % Extract triggers for secondary stimulus(i.e EPR.ISI(1...end)) for the
    % given primary trigger. 
    %
    %
    % [INPUT]
    % EPR struct: EPR data structure
    % T array<double>: 1-D array The triggers for primary and
    %   secondary stimulus. 
    % trigger int: A primary triggers whos secondary triggers are to be
    %   returned. 
    % secondary_tau int: Secondary trigger detection tolorance in samples. The
    %   relative number of samples with which to widen the segment searched
    %   for secondary triggers.
    % [OUTPUT]
    % TSecondary array<double>: The triggers of only the secondary stimuli.
    %   The size= 1 x len(find(EPR.ISI)). Each element is for the corresponding
    %   entry of EPR.ISI. A nan value indicates a missing secondary
    %   trigger.

    tau=secondary_tau;

    Tsecondary=[];

    if ~canContainSecondatryTrigger(EPR)
        return;
    end

    [~,isi]=eprecorder_stimulus_numbers(EPR);
    Tsecondary=nan(1,length(isi)-1);

    if isempty(Tsecondary)
        return;
    end

    
    isiSamples=isi(2:end)/1000*EPR.Fs;
    for i=1:length(isiSamples)
        ISI=isiSamples(i);

        ISIAbsoluteRange=(ISI-tau : ISI+tau)+primary_trigger;

        for n=1:length(T)
            if ismember(T(n),ISIAbsoluteRange)
                Tsecondary(i)=T(n);
                continue;
            end
        end
    end

end

