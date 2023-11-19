classdef eprecorder_response_motor_threshold
    % Motor threshold for, currently only the primary stimulus.
    %   For working with motor threshold such as RMT, etc

    properties(Constant)
        % 'loose': In case the total number of epochs for a stimulus code
        % is less than this.numRMTPresence, the stimulus code will still be
        % identified as a RMT candidate if all those epochs has presence.
        PRESENCE_MODE_LOOSE='loose';

        % 'strict': RMT candidate is never identified for a stimulus code
        % when the total number of epochs for a stimulus code is less than
        % object.numRMTPresence
        PRESENCE_MODE_STRICT='strict';
    end
    
    properties(SetAccess=protected)   
        % Number of reponse presence for a stimulus code
        % to be a candidate for RMT. If this value is less than 1, it will
        % be considered a percentage of the number of epochs for a stimulus
        % code. 
        % int|double
        numRMTPresence=2;

        
        
        presenceModes={eprecorder_response_motor_threshold.PRESENCE_MODE_LOOSE
                        eprecorder_response_motor_threshold.PRESENCE_MODE_STRICT};
        presenceMode=eprecorder_response_motor_threshold.PRESENCE_MODE_STRICT;
    end


    methods(Access=public)
        function this = eprecorder_response_motor_threshold(num_rmt_presence,presence_mode)
            % Construct an instance of this class
            % [INPUT]
            % num_rmt_presence: @see corresponding property declaration.
            % presence_mode: @see corresponding property declaration.
            if nargin>=1
                this.numRMTPresence=num_rmt_presence;
            end

            if nargin>=2
                if ~any(strcmp(this.presenceModes,presence_mode))
                    error('Unknown presence mode: %s',presence_mode);
                end
                this.presenceMode=presence_mode;
            end

        end

        function EPR=detectRMT(this,EPR,chan_nums)
            % Detect RMT.
            % [INPUT]
            % EPR: Epoched main EPR structure.
            % chan_nums int|array<int>|[]: The channel number/s to check.
            %   The detault/[] is all channels.
            % [OUTPUT]
            % EPR: The input structure with updated RMT.
            if nargin<3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            
            stimulus_codes=eprecorder_get_epoch_stimulus_code(EPR,[],true);

            
%             foreach chan
%                 foreach stimcode
%                     get all corresponding epochs
%                         check if we have at least x presence
%                             if we do, then record the current stimcode as the RMT & break.
%                                 
            for chan_num=reshape(chan_nums,1,[])
                rmt_stimulus_code=NaN;
                for n=1:length(stimulus_codes)
                    stimulus_num=1;
                    epoch_nums=eprecorder_epochs_for(EPR,stimulus_codes(n));
                    presence=eprecorder_response.has(EPR,chan_num,epoch_nums,stimulus_num);
                    
                    x=this.numRMTPresence;
                    if x<1
                        x=numel(presence) * x;
                        x=max([round(x),1]);
                    end
                    loose=eprecorder_response_motor_threshold.PRESENCE_MODE_LOOSE;
                    if(numel(find(presence)) >= x) || ( strcmp(this.presenceMode,loose) && (numel(find(presence)))==(numel(presence)) )
                        rmt_stimulus_code=stimulus_codes(n);
                        break;
                    end
                    
                end
                EPR=eprecorder_response_motor_threshold.setAutoRMT(EPR,chan_num,rmt_stimulus_code);
            end
                

        end
    end
    methods(Access=protected)
        

    end

    methods(Access=public,Static)
        function EPR=addFields(EPR,force)
            % Add motor threshold fields to the EPR data structure. An
            % error will occur if the fields already exists unless
            % input 'force'==true.
            % [INPUT]
            % EPR: Epoched main EPR structure.
            % force boolean: When true the fields will be added even if it 
            %   already exists. The default is false.
            % [OUTPUT]
            % EPR: The input structure with
            %   features.response.motor_threshold field added: 
            %       features.response.motor_threshold.auto_rmt_stimulus_code array:
            %           Auto computed resting motor thresold stimulus code.
            %           Each entry is for corresponding channel.
            %           Dimension is [nchannels x 1].
            %       features.response.motor_threshold.manual_rmt_stimulus_code array:
            %           mannually resting motor thresold stimulus code.
            %           Each entry is for corresponding channel.
            %           Dimension is [nchannels x 1]. 
     
            if nargin<2
                force=false;
            end
            if ~isfield(EPR.epochs.features,'response')
                error('response field is missing');
            end
            
            if(~force)
                if(isfield(EPR.epochs.features.response,'motor_threshold'))
                    error('motor_threshold field already exists');
                end
            end

            v=nan(length(EPR.channelNames),1);
            EPR.epochs.features.response.motor_threshold.auto_rmt_stimulus_code=v;
            EPR.epochs.features.response.motor_threshold.manual_rmt_stimulus_code=v;                        
        end
        
        function EPR=setAutoRMT(EPR,chan_nums,rmts)
            % Set auto rmt values.
            % [INPUT]
            % EPR.
            % chan_nums []|array<int>: The channels to which the 
            %   values are set. The default is all channels.
            % rmts double|array<double>: 1D array of rmt values.
            %   If one value is given, it will be broadcast to match the
            %   length of chan_nums.
            % [OUTPUT]
            % EPR.
            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if max(chan_nums) > length(EPR.channelNames)
                error("Incompatible channel number values")
            end

            if length(chan_nums)~=length(rmts)
                error("Number of resting motor threshold values does not match number of channels specified");
            end

            if length(rmts)==1
                rmts=repmat(rmts,1,length(chan_nums));
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'motor_threshold' field during epoching.
            if ~isfield(EPR.epochs.features.response,'motor_threshold')
                EPR=eprecorder_response_motor_threshold.addFields(EPR);
            end 

            %
            EPR.epochs.features.response.motor_threshold.auto_rmt_stimulus_code(chan_nums)=rmts;
        end
        

        function rmts =getAutoRMT(EPR,chan_nums)
            %  Get the auto rmt values.
            % [INPUT]
            % chan_nums []|array<int>: The channels to which the 
            %   values are got. The default is all channels.
            % [OUTPUT]
            % rmts double|array<double>: 1D array of rmt values.
            %   One entry per channel. The values are NaN when not set.


            if nargin < 2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if max(chan_nums) > length(EPR.channelNames)
                error("Incompatible channel number values")
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'motor_threshold' field during epoching.
            if ~isfield(EPR.epochs.features.response,'motor_threshold')
                EPR=eprecorder_response_motor_threshold.addFields(EPR);
            end 

            rmts=EPR.epochs.features.response.motor_threshold.auto_rmt_stimulus_code(chan_nums);
        end
        
        function EPR=setManualRMT(EPR,chan_nums,rmts)
            % Set maunally derived rmt values.
            % [INPUT]
            % EPR.
            % chan_nums []|array<int>: The channels to which the 
            %   values are set. The default is all channels.
            % rmts double|array<double>: 1D array of rmt values.
            %   If one value is given, it will be broadcast to match the
            %   length of chan_nums.
            % [OUTPUT]
            % EPR.
            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if max(chan_nums) > length(EPR.channelNames)
                error("Incompatible channel number values")
            end

            if length(chan_nums)~=length(rmts)
                error("Number of resting motor threshold values does not match number of channels specified");
            end

            if length(rmts)==1
                rmts=repmat(rmts,1,length(chan_nums));
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'motor_threshold' field during epoching.
            if ~isfield(EPR.epochs.features.response,'motor_threshold')
                EPR=eprecorder_response_motor_threshold.addFields(EPR);
            end 

            %
            EPR.epochs.features.response.motor_threshold.manual_rmt_stimulus_code(chan_nums)=rmts;
        end
        

        function rmts =getManualRMT(EPR,chan_nums)
            %  Get the manually derived rmt values.
            % [INPUT]
            % chan_nums []|array<int>: The channels to which the 
            %   values are got. The default is all channels.
            % [OUTPUT]
            % rmts double|array<double>: 1D array of rmt values.
            %   One entry per channel. The values are NaN when not set.


            if nargin < 2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if max(chan_nums) > length(EPR.channelNames)
                error("Incompatible channel number values")
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'motor_threshold' field during epoching.
            if ~isfield(EPR.epochs.features.response,'motor_threshold')
                EPR=eprecorder_response_motor_threshold.addFields(EPR);
            end 

            rmts=EPR.epochs.features.response.motor_threshold.manual_rmt_stimulus_code(chan_nums);
        end

        function rmts =getRMT(EPR,chan_nums)
            %  Get the effective rmt values. The auto values are considered
            %  when the manual values are not set. 
            % [INPUT]
            % chan_nums []|array<int>: The channels from which the 
            %   values are fetched. The default is all channels.
            % [OUTPUT]
            % rmts double|array<double>: 1D array of rmt values.
            %   One entry per channel. The values are NaN when not set.

            if nargin < 2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            rmts=eprecorder_response_motor_threshold.getManualRMT(EPR,chan_nums);

            % Get the channel number of items without manual rmts
            unset_chan_num_idx=find(isnan(rmts));
            unset_chan_nums=chan_nums(unset_chan_num_idx);

            if ~isempty(unset_chan_nums)
                auto_rmts=eprecorder_response_motor_threshold.getAutoRMT(EPR,unset_chan_nums);
                rmts(unset_chan_num_idx)=auto_rmts;
            end

        end
    end
end