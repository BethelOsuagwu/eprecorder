classdef eprecorder_importer
    % Data importer or external and old version.

    properties
        % int: Data sample rate.
        Fs=1;

        % cell<string>: Channels names.
        channelNames={};

        % cell<string>: Channels units.
        channelUnits={};

        % int: Index of channel in raw data that holds times for
        % samples
        timeChannelIndex=[];

        % int: Index of channel in raw data that holds trigger.
        triggerChannelIndex=[];

        % int: Index of channel in raw data that holds stimulus code.
        stimulusCodeChannelIndex=[];
    end

    properties(Access=protected)
        % struct: The default structure for EPR.
        defaultEPR=struct;
    end
    
    methods
        function this = eprecorder_importer()
            % Contruct a new instance.
            %
            runEPR='';% Prevent opening of the GUI by overriding gui script.
            initEPR;% NOTE: This will produce the EPR structure.

            % Clear the default values
            fields=fieldnames(EPR);
            for fd=fields'
                field=fd{1};
                val=EPR.(field);
                switch(class(EPR.(field)))
                    case 'char'
                        val='';
                    case 'double'
                        val=[];
                    case 'cell'
                        val={};
                    case 'struct'
                    otherwise
                end
                EPR.(field)=val;
            end

            %
            this.defaultEPR=EPR;

        end

        function EPR=raw(this, data)
            % Import raw data
            %
            % [INPUT]
            % data array<double>: Unepoched 2-D array to be imported. The 
            %   channels is in the first axes while time is in the second
            %   axes.
            % [OUTPUT]
            % EPR struct: EPR data structure extracted.

            EPR=this.defaultEPR;
            EPR.Fs=this.Fs;
            samples=size(data,2);

            % Time channel
            time_channel=eprecorder_sample2time(EPR,1:samples);
            if not(isempty(this.timeChannelIndex))
                time_channel=data(this.timeChannelIndex,:);
                data(this.timeChannelIndex,:)=[];
            end

            % Trigger channel
            trigger_channel=[0,5,zeros(1,samples-2)];% trigger channel with a trigger near the start
            if not(isempty(this.triggerChannelIndex))
                trigger_channel=data(this.triggerChannelIndex,:);
                data(this.triggerChannelIndex,:)=[];
            end

            % Stimulus code channel
            stimulus_code_channel=zeros(1,samples);
            if not(isempty(this.stimulusCodeChannelIndex))
                trigger_channel=data(this.stimulusCodeChannelIndex,:);
                data(this.stimulusCodeChannelIndex,:)=[];
            end


            % Channel names
            chans=size(data,1);
            EPR.channelNames=this.channelNames;
            if isempty(EPR.channelNames)
                EPR.channelNames=num2cell(1:chans);
                EPR.channelNames=cellfun(@(c)mat2str(c),EPR.channelNames,'UniformOutput',false);
            end

            % Channel units
            EPR.channelUnits=this.channelUnits;
            if isempty(EPR.channelUnits)
                EPR.channelUnits=cellstr(repmat('unit?',chans,1))';
            end

            % Overal data
            EPR.data=[
                time_channel
                data;% Channel data
                trigger_channel;
                stimulus_code_channel
            ];
            
        end

        function EPR=legacy(this,EPRdata)
            % Import unepoched data from an older version of EPR.
            % [INPUT]
            % EPRdata struct: An older EPR data strcuture
            % [OUTPUT]
            % EPR struct: EPR data structure extracted.
            EPR=this.defaultEPR;

            % Update the field values
            fields=fieldnames(EPR);
            for fd=fields'
                field=fd{1};
                if isfield(EPRdata,field)
                    EPR.(field)=EPRdata.(field);
                end
            end

            % Channel units
            chans=size(EPRdata.data,1);
            if isempty(EPR.channelUnits)
                EPR.channelUnits=cellstr(repmat('unit?',chans,1))';
            end

            % Stimulus code channel
            samples=size(EPRdata.data,2);
            stimulus_code_channel=zeros(1,samples);

            % Overal data
            EPR.data=[
                EPRdata.data;
                stimulus_code_channel
            ];
        end
    end
end

