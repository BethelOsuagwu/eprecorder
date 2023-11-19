classdef eprecorder_epoch_qa
    %EPRECORDER_EPOCH_QA Performs quality assurance/assessment of epoched
    %data. 
    %   
    
    properties
        % string: Noise detection method.
        noiseDetectionMethod='confidence_interval';
        
        % double: The number of feature standard
        %   daviations/errors above baseline at which an outlier is
        %   detected. 
        %
        %   TODO: the name of this property may be misleading given that it
        %   serves multiple purposes depending on the set noise detection
        %   method.  
        featureErrorScale=3;
    end

    properties(Access=protected)
        % List of valid noise detection methods
        validNoiseDetectionMethods={
                % An observation is considered noise if a feature value from its prestimulus/baseline is greater than
                % the right confidence limit scaled by the property
                % this.featureErrorScale. The confidence limit is
                % constructed from post-stimulus data.
                'confidence_interval'

                % An observation is considered noise if a feature value from its pre-stimulus/baseline is greater than
                % that from the post-stimulus data by the number of standard deviations given by the property
                % this.featureErrorScale. 
                'nstd'

                % An observation is considered noise if its prestimulus amplitude is greater than
                % the value of the property this.featureErrorScale.
                'max_amplitude'

                % An observation is considered noise if the mean amplitude of its
                % pre-stimulus data points is greater than the value of the property
                % this.featureErrorScale. 
                'mean_amplitude'

                % An observation is considered to be noise if its
                % pre-stimulus peak2peak amplitude is greater than the property
                % this.featureErrorScale.
                'max_peak2peak'
            };
    end
    
    methods
        function this = eprecorder_epoch_qa(noise_detection_method,feature_error_scale)
            %EPRECORDER_QA Construct an instance of this class.
            %   
            % [INPUT]
            % noise_detection_method string: Method for detecting noise.
            % feature_error_scale double: The number of feature standard
            %   daviations/errors above baseline at which an outlier is
            %   detected.
            if nargin>=1 && ~isempty(noise_detection_method)
                this.noiseDetectionMethod=noise_detection_method;
            end
            if nargin>=2
                this.featureErrorScale=feature_error_scale;
            end
            
        end
        
        function is_noisy=isNoisy(this,observation,sample)
            % Check if the given observation is noisy with respect to
            % a noise detection criteria. 
            % [INPUT]
            % observation double|array<double>: The feature to be
            %   checked for noise. If it is an array then noise will be 
            %   detected if any of its entry satisfy a noisy criteria.
            % sample array<double>: A univariat sample of the population 
            %   where the observation is obtained. It is required
            %   depending to the current noise detection method property
            %   this.noiseDetectionMethod. 
            % [OUTPUT]
            % is_noisy boolean: True for a noisy.

            % Criteria for noise detection
            is_noisy=false;
            switch(this.noiseDetectionMethod)
                case 'confidence_interval'
                    sample_size=size(sample,2);
                    
                    if sample_size>30 && lillietest(sample)==0
                        % Define a z-statistics for 95% confidence
                        % interval
                        stats=[-1.96,1.96];
                        
                    else
                        % Define a t-statistics for 95% confidence
                        % interval.
                        dof=sample_size-1;
                        alpha_value=0.05;
                        alpha_value_2tails=[alpha_value/2,1-alpha_value/2];
                        stats=tinv(alpha_value_2tails,dof); 
                    end

                    % Calculate standard error
                    std_error=std(sample)/sqrt(sample_size);

                    % Allow the caller to tune the confidence width.
                    std_error=this.featureErrorScale*std_error;

                    % Construct confidence interval
                    confidence_interval=mean(sample)+(stats*std_error);

                    % Check if the sample_feature is large than
                    % the upper limit of confidence interval of the
                    % baseline mean feature.
                    if(any(observation>confidence_interval(2)))
                        is_noisy=true;
                    end

                case 'nstd'
                    %   For a noise to be detected, a feature (such as
                    %   area) given by sample_feature is required to be N
                    %   times greater than the standard deviations of
                    %   baselineFeature 
                    baseline_feature_nstd=mean(sample)+std(sample)*this.featureErrorScale;
                    if any(observation > baseline_feature_nstd)
                        is_noisy=true;
                    end
                case 'max_amplitude'
                    if any((observation>this.featureErrorScale))
                        is_noisy=true;
                    end
                case 'mean_amplitude'
                    if mean(observation)>this.featureErrorScale
                        is_noisy=true;
                    end
                case 'max_peak2peak'
                    if peak2peak(observation)>this.featureErrorScale
                        is_noisy=true;
                    end
                otherwise
                    error('Unknown noise detection method');
            end

        end

        function [EPR,nrejected]=autoReject(this,EPR)
            % Reject noisy epochs for all channels automatically. An epoch
            % is noisy if its baseline is an outlier greater than the
            % expected baseline. 
            %
            % NOTE:
            % Here we assume that stimulus was delivered at time=0ms. And
            % that regardless of the epoch type i.e stimulus code, the
            % baselines of all epochs are similar and have features that
            % are desimilar to those area of a valid respons.
            %
            % [INPUT]
            % EPR: The EPR data structure.
            %    
            % [OUTPUT]
            % EPR struct: The input EPR with updated epoch rejection. 
            % nrejected int: The number of epochs rejected during this run.

            nrejected=0;

            % Abitrary time offset to avoid using the data in the vicinity
            % of time t=0 for baseline to avoid stimulation artefact. 
            zero_time_offset=eprecorder_sample2time(EPR,100);
            t_end=0-zero_time_offset*1000;

            %
            baseline_time_win=[EPR.epochs.time_win(1),t_end];
            if(baseline_time_win(1)>t_end)
                warning(['There was not suitable baseline for detecting' ...
                    ' the noise automatically']);
                return;
            end            

            % For each channel and epoch, get the features of baseline
            baseline=eprecorder_get_epoch_data(EPR,[],[],baseline_time_win,false);
            baseline(isnan(baseline))=0;% NaNs are not expected though.
            [chans,~,epochs]=size(baseline);
            baseline_area=zeros(chans,epochs);
            baseline_p2p=zeros(chans,epochs);
            for chan=1:chans
                for epoch=1:epochs
                    % Compute the feature, area per sample without caring
                    % for the unit of the area since it is not important
                    % here. 
                    baseline_area(chan,epoch)=trapz(abs(baseline(chan,:,epoch)))/size(baseline_area,2);

                    % Compute the peak to peak feature for baseline
                    baseline_p2p(chan,epoch)=peak2peak(baseline(chan,:,epoch));
                end
            end

            % Detect noise by finding outliers in the baseline features.
            for chan=1:chans  
                for epoch=1:epochs
                    % Criteria for noisy
                    is_noisy=0;
                    switch(this.noiseDetectionMethod)
                        case {'max_amplitude','mean_amplitude','max_peak2peak'}
                            if this.isNoisy(abs(baseline(chan,:,epoch)))
                                is_noisy=1;
                            end
                        otherwise
                            observation_area=baseline_area(chan,epoch);
                            observation_p2p=baseline_p2p(chan,epoch);
        
                            if this.isNoisy(observation_area,baseline_area(chan,:))...
                                && this.isNoisy(observation_p2p,baseline_p2p(chan,:))
                                is_noisy=1;
                            end
                    end

                    % Save rejection
                    nrejected=nrejected+double(is_noisy);
                    EPR=eprecorder_epoch_qa.setAutoReject(EPR,chan,epoch,is_noisy);
                end
            end 
        end

        
    end

    methods(Access=public,Static)
        function EPR=setAutoReject(EPR,chan_nums,epoch_nums,rejects)
            % Mark the given epoch number as rejected or not, as detected
            % automatically. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_nums int|array<int>|[]: The channel number/s. Set to  
            %   empty bracket for all channels.
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial.
            %   Set to empty bracket for all epochs.
            % rejects bool|int|array<bool|int>: True to reject. Must be a
            %   scaler or have the size of [chan_nums,epoch_nums].
            % [OUTPUT] 
            % EPR: The input EPR struct with epoch auto reject updated.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:length(EPR.trials);
            end

            if nargin<4 
                rejects=true;
            end

            if numel(rejects)~=1
                [r,c]=size(rejects);
                if(length(chan_nums)~=r || length(epoch_nums)~=c)
                    error('The input `rejects` has invalid dimension');
                end
            end
            
            EPR.epochs.qa.auto_rejects(chan_nums,epoch_nums)=double(rejects);
        end

        function reject=getAutoReject(EPR,chan_nums,epoch_nums)
            % Get the  auto rejection status. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int|array<int>|[]: The channel number. Set to empty
            %   bracket for all channels.
            % epoch_num int|array<int>|[]: The epoch number of the trial.
            % 
            % [OUTPUT] 
            % reject int|array<int>: 1 for manually rejected epochs and 0
            %   for unrejected epochs. NaN indicates that the value has not
            %   been set. Dimension is [chan_nums,epoch_nums]. 

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:length(EPR.trials);
            end
   
            reject=EPR.epochs.qa.auto_rejects(chan_nums,epoch_nums);
        end
        function EPR=setManualReject(EPR,chan_nums,epoch_nums,reject)
            % Mark the given epoch number as rejected or not as detected
            % manually. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int|array<int>|[]: The channel number. Set to empty
            %   bracket for all channels.
            % epoch_num int|array<int>|[]: The epoch number/s of the trial.
            %   Set to empty bracket for all epochs.
            % reject bool|int|array<bool|int>: True to reject. Must be a
            %   scaler or have the size of [chan_nums,epoch_nums].
            % [OUTPUT] 
            % EPR: The input EPR struct with epoch reject updated.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:length(EPR.trials);
            end

            if nargin<4 
                reject=true;
            end

            if numel(reject)~=1
                [r,c]=size(reject);
                if(length(chan_nums)~=r || length(epoch_nums)~=c)
                    error('The input `reject` has invalid dimension');
                end
            end
            
            EPR.epochs.qa.manual_rejects(chan_nums,epoch_nums)=double(reject);
            
        end

        function reject=getManualReject(EPR,chan_nums,epoch_nums)
            % Get the manual rejection status. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int|array<int>|[]: The channel number. Set to empty bracket
            %   for all channels.
            % epoch_num int|array<int>|[]: The epoch number of the trial.
            % 
            % [OUTPUT] 
            % reject int|array<int>: 1 for manually rejected epochs and 0
            %   for unrejected epochs. NaN indicates that the value has not
            %   been set. Dimension is [chan_nums,epoch_nums].

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:length(EPR.trials);
            end
   
            reject=EPR.epochs.qa.manual_rejects(chan_nums,epoch_nums);
        end
        function reject=isEffectivelyRejected(EPR,chan_nums,epoch_nums)
            % Get the manual rejection status or auto rejection status if
            % manual rejection status is not set.
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int|array<int>|[]: The channel number. Set to empty
            %   bracket for all channels.
            % epoch_num int|array<int>|[]: The epoch number of the trial.
            % 
            % [OUTPUT] 
            % reject boolean|array<boolean>: True for auto rejected
            %   epoch. Dimension is [chan_nums,epoch_nums].

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:length(EPR.trials);
            end
   
            reject=eprecorder_epoch_qa.getManualReject(EPR,chan_nums,epoch_nums);
            if any(isnan(reject))
                reject_auto=eprecorder_epoch_qa.getAutoReject(EPR,chan_nums,epoch_nums);

                % Set the epochs that have a manual reject value of NaN to
                % their corresponding auto_reject value.
                unset_reject=isnan(reject);
                reject(unset_reject)=reject_auto(unset_reject);
            end
            
            reject(isnan(reject))=0;

            reject=~~reject;
        end
    end
end
