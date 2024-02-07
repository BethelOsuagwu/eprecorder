classdef eprecorder_response_norm
    % EP response normalisation
    %   Normalisation of response amplitude.
    
    properties(Constant)
        % Types of normalisation
        TYPE_MVC_RMS='mvc_rms';% The max rms of maximunm voluntary contraction.
        TYPE_MAX_RESPONSE_PEAK2PEAK='max_response_peak2peak';% Average of max responses e.g max response from peripheral stim.
        TYPE_RMT_PEAK2PEAK='rmt_peak2peak';% The peak at RMT.
        TYPE_STIM_INTENSITY='stim_intensity';% The stimulus intensity used to apply each response.
    end

    properties(SetAccess=protected)   
        %% Type of normalisation: The normalisation value can be:
        types={
                eprecorder_response_norm.TYPE_MVC_RMS 
                eprecorder_response_norm.TYPE_MAX_RESPONSE_PEAK2PEAK 
                eprecorder_response_norm.TYPE_RMT_PEAK2PEAK
                eprecorder_response_norm.TYPE_STIM_INTENSITY 
            };
        type=eprecorder_response_norm.TYPE_MVC_RMS;
        sourceDataset="";% the EPR dataset contaning normalisations values.
        chanNums=[]; % The channel indices of the source that that should be considered. The default is all channels.
        
    end

    


    methods(Access=public)
        function this = eprecorder_response_norm(type,sourceDataset,chanNums)
            % Construct an instance of this class
            % [INPUT]
            % type string|[]: The type of normalisation to use.
            % sourceDataset struct: EPR data structures with normalisation
            %   data.
            % chanNums []|array<int>|int: The channels that should be considered. The default is all channels. 

            if nargin >= 3 && ~isempty(chanNums)
                this.chanNums=chanNums;
            end

            if nargin<1 || isempty(type)
                type=this.type;
            end

            if nargin >=2
                is_epoched=eprecorder_has_epoch(sourceDataset);
                switch(type)
                    case eprecorder_response_norm.TYPE_MVC_RMS
                        if is_epoched
                            error('%s requires continuous data',eprecorder_response_norm.TYPE_MVC_RMS)
                        end
                    case {eprecorder_response_norm.TYPE_MAX_RESPONSE_PEAK2PEAK ,eprecorder_response_norm.TYPE_RMT_PEAK2PEAK}
                        if ~is_epoched
                            error('The normalisation type require epoched dataset')
                        end
                end
                this.sourceDataset=sourceDataset;
            end

            if ~any(strcmp(this.types,type))
                error("Unkown normalisation type: %s",type);
            end

            if isempty(this.chanNums) && isstruct(this.sourceDataset)
                this.chanNums=1:length(this.sourceDataset.channelNames);
            end
            

            this.type=type;

        end

        function norms=process(this)
            % Compute and return the normalisation values for all channels.
            % [OUTPUT]
            % norms array<double>: 1D array, shape=(N,1) of normalisation values.
            %   One entry per channel, in the channel order as in EPR.channelNames.
            switch(this.type)
                case eprecorder_response_norm.TYPE_MVC_RMS
                    norms=this.processMvcRms();
                case eprecorder_response_norm.TYPE_MAX_RESPONSE_PEAK2PEAK
                    norms=this.processMaxResponsePeak2peak();
                case eprecorder_response_norm.TYPE_RMT_PEAK2PEAK
                    norms=this.processRmtPeak2Peak();
                case eprecorder_response_norm.TYPE_STIM_INTENSITY
                    error('Normalisation type, %s is not yet implemented',eprecorder_response_norm.TYPE_STIM_INTENSITY)
            end

        end
    end
    methods(Access=protected)
        function norms=processMvcRms(this)
         % Compute and return the mvc_rms normalisation
             % values for specified channels. 
            % [OUTPUT]
            % norms array<double>: 1D array, shape=(N,1) of normalisation values.
            %   One entry per channel in the specified channel order.
            norms=eprecorder_mvc_rms(this.sourceDataset,this.chanNums);
        end
        function norms=processMaxResponsePeak2peak(this)
             % Compute and return the max_response_peak2peak normalisation
             % values for specified channels. 
            % [OUTPUT]
            % norms array<double>: 1D array, shape=(N,1) of normalisation values.
            %   One entry per channel in the specified channel order.

            norms=eprecorder_response.getPeak2peak(this.sourceDataset,this.chanNums,[],[],false,true);
            norms=mean(norms,2,"omitnan");% Assuming that all the epochs corresponds to max peak2peak, e.p in 3 epochs of peripheral stim.
        end

        function norms=processRmtPeak2Peak(this)
            % Compute and return the rmt_peak2peak normalisation
            % values for specified channels. 
            % [OUTPUT]
            % norms array<double>: 1D array, shape=(N,1) of normalisation values.
            %   One entry per channel in the specified channel order.
            
            % Get the RMT stim codes.
            rmt_stim_codes=eprecorder_response_motor_threshold.getRMT(this.sourceDataset);
            if all(isnan(rmt_stim_codes))
                warning('No RMT stimulus code found. Be sure to process the source dataset with eprecorder_response_motor_threshold');
            end
            
%             rec=eprecorder_recruitment_curve([],[],'peak2peak');
%             rec.excludeNoResponse=true;
%             rec.normalisationType="none";
%             cvs=rec.get(this.sourceDataset);
% 
%             % Get the peak2peak for the RMT stim codes.
%             rmt_peak2peak_idxs=rec.stimulusCodes==rmt_stim_codes;
%             norms=nan(size(rmt_peak2peak_idxs,1),1);
%             for chan=1:size(rmt_peak2peak_idxs,1)
%                 idx=rmt_peak2peak_idxs(chan,:);
%                 norms(chan)=cvs(chan,idx);
%             end


           nchans=length(this.chanNums);
           norms=nan(nchans,1);
            for n=1:nchans
                chan=this.chanNums(n);
                epochs_p2p=eprecorder_response.getPeak2peak(this.sourceDataset,chan,[],rmt_stim_codes(chan),true,true);
                norms(n,1)=mean(epochs_p2p,2,"omitnan");
            end
        end

    end

    methods(Access=public,Static)
        function EPR=addFields(EPR,force)
            % Add Normalisation fields to the EPR data structure. An
            % error will occur if the fields already exists unless
            % input 'force'==true.
            % [INPUT]
            % EPR: Epoched main EPR structure.
            % force boolean: When true the fields will be added even if it 
            %   already exists. The default is false.
            % [OUTPUT]
            % EPR: The input structure with features.response.normalisation
            %   field added:
            %       features.response.normalisation.mvc_rms array:@see
            %           definition of corresponding 'type' in class
            %           properties. Each entry is for corresponding
            %           channel's max MVC rms. Dimension is [nchannels x 1].
            %       features.response.normalisation.max_response_peak2peak array: @see
            %           definition of corresponding 'type' in class
            %           properties. Each entry is for corresponding
            %           channel's average of max responses e.g max response
            %           from peripheral stim. Dimension is [nchannels x 1]. 
            %       features.response.normalisation.rmt_peak2peak array:@see
            %           definition of corresponding 'type' in class
            %           properties. Each entry is for corresponding
            %           channel's RMT peak2peak. Dimension is [nchannels x 1].
 
     
            if nargin<2
                force=false;
            end
            if ~isfield(EPR.epochs.features,'response')
                error('response field is missing');
            end
            
            if(~force)
                if(isfield(EPR.epochs.features.response,'normalisation'))
                    error('normalisation fields already exists');
                end
            end

            v=nan(length(EPR.channelNames),1);
            EPR.epochs.features.response.normalisation.mvc_rms=v;
            EPR.epochs.features.response.normalisation.max_response_peak2peak=v;
            EPR.epochs.features.response.normalisation.rmt_peak2peak=v;


                        
        end
        
        function EPR=set(EPR,type,chan_nums,norms)
            % Set nomalisation values.
            % [INPUT]
            % EPR.
            % type string: Normalisation type. See the eprecorder_response_norm.type.
            % chan_nums []|array<int>: The channels to which the norm
            %   values are set. The default is all channels.
            % norms double|array<double>: 1D array of normalisation values.
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

            if length(chan_nums)~=length(norms)
                error("Number of normalisation values does not match number of channels specified");
            end

            if length(norms)==1
                norms=repmat(norms,1,length(chan_nums));
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'normalisation' field during epoching.
            if ~isfield(EPR.epochs.features.response,'normalisation')
                EPR=eprecorder_response_norm.addFields(EPR);
            end 

            %
            EPR.epochs.features.response.normalisation.(type)(chan_nums)=norms;
        end
        
        function EPR=setFromDataset(EPR,type,chan_nums,sourceDataset)
            % Set normalisation values from a dataset.
            % [INPUT]
            % EPR struct: The destination dataset.
            % type string: The type of normalisation data in the source
            %   dataset
            % chan_nums []|array<int>: The channels to consider
            % sourceDataset struct: EPR data structure with normalisation
            %   raw values.
            % [OUTPUT]
            % EPR struct: EPR dataset.

            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            normalizer=eprecorder_response_norm(type,sourceDataset,chan_nums);
            norms=normalizer.process();
            EPR=eprecorder_response_norm.set(EPR,type,chan_nums,norms);
        end

        function norms =get(EPR,type,chan_nums)
            %  Get the normalisation values.
            % [INPUT]
            % type string: Normalisation type. See the eprecorder_response_norm.type.
            % chan_nums []|array<int>: The channels from which the norm
            %   values are retrieved. The default is all channels.
            % [OUTPUT]
            % norms double|array<double>: 1D array of normalisation values.
            %   One entry per channel. The values are NaN when not set.
            if nargin<2 
                type=eprecorder_response_norm().type;
            end

            if nargin < 3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if max(chan_nums) > length(EPR.channelNames)
                error("Incompatible channel number values")
            end

            % In case field is not added, add it. TODO: remove after adding
            % 'normalisation' field during epoching.
            if ~isfield(EPR.epochs.features.response,'normalisation')
                EPR=eprecorder_response_norm.addFields(EPR);
            end 

            norms=EPR.epochs.features.response.normalisation.(type)(chan_nums);
        end

        function vals=normalise(type,vals,norms)
            % Normalise the given values
            % [INPUT]
            % type string: Normalisation type.
            % vals array<double>: Values to be normalised.
            % norms double|array<double>: The normalisation value/s. If norms has more than one element then each row of vals
            %   corresponds to a single entry in norms. 
            % [OUTPUT]
            % vals array<double>: The normalised input.
            if any(isnan(norms))
                warning(['Some channels will be normalised with NaN causing ' ...
                    'them to become NaN. Ensure that normalisation values' ...
                    ' are set for all data when possible. Ignore this ' ...
                    'warning if the nomalisation with NaN is deliberate e.g. ' ...
                    'missing normalisation value.']);
            end
            switch(type)
                case eprecorder_response_norm().types
                    vals=vals.*(1/norms);
                otherwise
                    error('Unknown normalisation type: %s',type);
            end
        end
    end
end