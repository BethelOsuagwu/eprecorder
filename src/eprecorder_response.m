classdef eprecorder_response < handle
    % EP response
    %   Manipulate evoked potential response features.
    
    properties(SetAccess=protected)   
        %% Valide change time auto detection methods. This are methods used to detect the time when a signal changes significantly.
        validAutoChangeTimeDetectionMethods={'findchangepts','mep_classifier'};

        % The change time auto detection method
        autoChangeTimeDetectionMethod='findchangepts';

        % Cell of 2-element cells of name value pairs of data required by
        % change time detection method specified 
        autoChangeTimeDetectionMethodData={{'statistic','mean'},{'MaxNumChanges',10}};

        %% Valid response presence detection methods. These are methods used to detect the presence of EP on a signal.
        validAutoPresenceDetectionMethods={'findchangepts','mep_classifier'};

        % Response presence detection method
        autoPresenceDetectionMethod='findchangepts';

        % Cell of 2-element cells of name value pairs of data required by
        % response detection method specified 
        %autoPresenceDetectionMethodData={{'driver','default'}}; Use this for mep_classifier method. 
        autoPresenceDetectionMethodData={{'statistic','mean'},{'MaxNumChanges',10}};

        
        
        % Valid methods for response validation.
        % 'none': Responses are not validated.
        % 'peak2peak_threshold': A response is valid if its peak2peak is
        %   above a threshold.
        % 'features_nstd': For a response to be detected, a
        %   feature (such as response area) computed from the effective
        %   response feature is required to be N times 
        %   greater than the standard deviation of the same feature
        %   computed for the time window before stimulus. THIS METHOD
        %   EQUIVALENT 'none' when autoChangeTimeDetectionMethod='mep_classifier';
        % 'features_confidence_interval': For a response to be valid its features (e.g peak2peak, area) must be larger than
        %   the upper limit of confidence interval of the
        %   baseline mean feature. If confidence interval cannot be
        %   constructed for a baseline feature due to limited sample size then features_nstd method will be used
        %   instead. THIS METHOD EQUIVALENT 'none' when autoChangeTimeDetectionMethod='mep_classifier';
        validAutoPresenceValidationMethods={'none','peak2peak_threshold','features_nstd','features_confidence_interval'}

        % The method to be used to validate a response.
        autoPresenceValidationMethod='peak2peak_threshold';

        %% Response classifier
        % MEPClassifierContract.
        classifier;
    end

    properties(Access=private)
        cache=eprecorder_cache(20000,true,7*60*60);
    end

    properties(Access=public)
        % Determines the threshold value of peak2peak for a response to be
        % detected as present.
        presencePeak2peakThreshold=0.05;
        
        % When true prestimulus data will be checked to ensure lack of
        % activities when detecting a response.
        presenceBackgroundCheck=true; 

        % The minimum width of a valid response in milliseconds.
        presenceMinWidth=5;

        % Verbosity of output
        % 0: not verbose
        % 1: verbose
        verbose=1
    end

    
    

    methods(Access=public)
        function this = eprecorder_response( ...
                autoChangeTimeDetectionMethod, ...
                autoChangeTimeDetectionMethodData, ...
                autoPresenceDetectionMethod, ...
                autoPresenceDetectionMethodData, ...
                autoPresenceValidationMethod)
            % Construct an instance of this class
            % [INPUT]
            % autoChangeTimeDetectionMethod string: The change time auto
            %   detection method. The default is 'findchangepts'.
            % autoChangeTimeDetectionMethodData cell: Cell of 2-element
            %   cells of name value pairs of data required by the chosen
            %   change time detection method. @property definition for
            %   default value; 
            % autoPresenceDetectionMethod string: The presence auto
            %   detection method. The default is 'findchangepts'.
            % autoPresenceDetectionMethodData cell: Cell of 2-element
            %   cells of name value pairs of data required by the chosen
            %   presence detection method. @property definition for
            %   default value;
            % autoPresenceValidationMethod string: @see corresponding
            %   property definition dfor details and default.
            
            if nargin>=1
                this.autoChangeTimeDetectionMethod=autoChangeTimeDetectionMethod;
            end
            if nargin>=2
                this.autoChangeTimeDetectionMethodData=autoChangeTimeDetectionMethodData;
            end

            if nargin>=3
                this.autoPresenceDetectionMethod=autoPresenceDetectionMethod;
            end
            if nargin>=4
                this.autoPresenceDetectionMethodData=autoPresenceDetectionMethodData;
            end

            if nargin>=5
                this.autoPresenceValidationMethod=autoPresenceValidationMethod;
            end



            tf=strcmp(this.autoChangeTimeDetectionMethod,this.validAutoChangeTimeDetectionMethods);
            if not(any(tf))
                error(['Uknown auto response change time detection method, ',this.autoChangeTimeDetectionMethod]);
            end

            tf=strcmp(this.autoPresenceDetectionMethod,this.validAutoPresenceDetectionMethods);
            if not(any(tf))
                error(['Uknown auto response presence detection method, ',this.autoPresenceDetectionMethod]);
            end


            tf=strcmp(this.autoPresenceValidationMethod,this.validAutoPresenceValidationMethods);
            if not(any(tf))
                error('Invalid value, %s, for property autoPresenceValidationMethod',this.autoPresenceValidationMethod);
            end
            
        end
        function c=getCache(this)
            c=this.cache;
        end
    end
    methods(Access=protected)
        function [start_idx,stop_idx,preds]=classify(this,x,Fs,peak2peak_thresh,min_response_width)
            % Classify the the given data to check
            % if it is a response.
            % [INPUTS]
            % x double: 1D data. It will be forced to be a column vector.
            % Fs double: The samplerate of Data x.
            % peak2peak_thresh double|[]: Threshold peak2peak amplitude for a 
            %   valid response in the unit of the input data x. Default is this.presencePeak2peakThreshold.
            % min_response_width double|[]: Min time width in milliseconds for a response.
            % [OUTPUTS]
            % start_idx []|int|NaN: Response start index. []=>invalid response. NaN =>not found.
            % stop_idx []|int|NaN: Response offset index. []=>invalid response. NaN=>not found.
            % preds []|array<double>: Probabilities. Shape currently depends 
            %  on classifier. TODO Need to make this return deterministic
            %  shape. []=>invalid response.

            if nargin < 4 || isempty(peak2peak_thresh)
                peak2peak_thresh=this.presencePeak2peakThreshold;
            end

            if nargin < 5 || isempty(min_response_width)
                min_response_width=5;
            end


            start_idx=[];
            stop_idx=[];
            preds=[];

            % If response less than 50mV it is not acceptable
            if peak2peak(x)<peak2peak_thresh
                return;% Early return
            end
            
            % Get the driver
            for n=1:length(this.autoPresenceDetectionMethodData)
                if strcmp(this.autoPresenceDetectionMethodData{n}{1},'driver')
                    driver=this.autoPresenceDetectionMethodData{n}{2};
                end
            end

            % Build the classifier just in time
            if isempty(this.classifier) || ~strcmp(this.classifier.getDriver(),driver) % On 23/11/2023: this class was change to a handle class to fix the following =>TODO: [this condition is always true since this.classifier is never saved as this object is not a handle.]
                path=fileparts(mfilename('fullpath'));
                path=fullfile(path,'classification');
                addpath(path);
                this.classifier=mepclassifier.ClassifierManager().classifier(driver);   
            end
            if isrow(x)
                x=x';
            end


            % Get the classification results
            cache_key=[char(this.classifier.getDriver()) '__' sprintf('%.2g',x) '__' sprintf('%.1f',Fs)];%TODO: this key depends on the length of the signal x, so can be too long.
            %this.cache.clearCache()
            cached=this.cache.get(cache_key);
            if ~isempty(cached)
                start_idx=cached.start_idx;
                stop_idx=cached.stop_idx;
                preds=cached.preds;
            else
                [start_idx,stop_idx,preds]=this.classifier.classify(x,Fs,min_response_width);

                % Cache the result
                cached.start_idx=start_idx;
                cached.stop_idx=stop_idx;
                cached.preds=preds;
                this.cache.put(cache_key,cached);
            end

            
            

            % Return if nothing was found
            if isnan(start_idx) || isnan(stop_idx)
                return
            end

            % Now check again that the peak2peak criteria is certified
            % this time within start and stop indices
            if peak2peak(x(start_idx:stop_idx))<peak2peak_thresh
                % TODO: Note that this condition may cause a few false
                % negatives?
                start_idx=NaN;
                stop_idx=NaN;
                return;
            end
            

            % If response width is too small, it is not acceptable
            if (stop_idx - start_idx) < round(Fs*min_response_width/1000)
                start_idx=NaN;
                stop_idx=NaN;
            end
        end
    end

    methods(Access=protected,Static)
        function name_val_pairs=lineariseNameValuePairs(pairs)
            % Linearise name value pairs
            % [INPUT]
            % pairs cell: Cell of cells of name-value pairs e.g. {{'statistic','mean'},{'MaxNumChanges',2}}
            % [OUTPUT]
            % name_val_pairs: The linearised name-value pairs {'statistic','mean','MaxNumChanges',2}
            name_val_pairs={};
            for n=1:length(pairs)
                name_val_pairs{end+1}=pairs{n}{1};
                name_val_pairs{end+1}=pairs{n}{2};
            end
        end
    end

    methods(Access=public)
            function passed=checkBackground(this,EPR,chan_num,epoch_num,stimulus_num)
            % Check if the given epoch has an acceptable background for
            % evoked response. Background is not acceptable if it has too
            % much activities.
            % [INPUT]
            % EPR: The EPR data structure. 
            % chan_num int: The channel number to consider. 
            % epoch_num int: The epoch number of the trial.
            % stimulus_number int: The stimulus number to consider
            % [OUTPUT]
            % passed boolean: True if the background is acceptable.


            nstd=0.5;%response must be this amount(arbitrary) of stds greater than background/pre-stim activities.
            

            % Get bg data
            %
            % Abitrary time offset to avoid using the data in the vicinity
            % of time t=0 for baseline to avoid stimulation artefact. 
            zero_time_offset=eprecorder_sample2time(EPR,100);
            t_end=0-zero_time_offset*1000;

            baseline_time_win=[EPR.epochs.time_win(1),t_end];
            if(baseline_time_win(1)>t_end)
                % So we compromise and use data near the vicinity of stim artefact.
                zero_time_offset=eprecorder_sample2time(EPR,5);
                t_end=0-zero_time_offset*1000;

                baseline_time_win=[EPR.epochs.time_win(1),t_end];
                if(baseline_time_win(1)>t_end)
                    warning(['Skipping background check: There was not suitable baseline for detecting' ...
                        ' for bacground check']);
                    return;
                end
            end            

            % For each channel and epoch, get the features of baseline
            baseline=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,baseline_time_win,true);                

            % Response data
            response_data=[];
            time_win=this.getTimeWin(EPR,chan_num,stimulus_num);
            response_data=[response_data; eprecorder_get_epoch_data(EPR,chan_num,epoch_num,time_win)];
            
            passed=false;
            baseline=abs(baseline); % Take absolute value to avoid amplitude cansulation.
            response_data=abs(response_data);
            if mean(response_data) > (mean(baseline) + nstd*std(baseline))
                passed=true;
            end
            
        end
        function EPR=autoDetectOnsetTimes(this,EPR,chan_nums,epoch_nums,stimulus_nums)
            % Auto detect response onset for all channels and epochs.
            % 
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            % stimulus_nums int|array<int>: The stimulus number/s to
            %   consider.
            % [OUTPUT]
            % EPR: The input EPR with updated auto response onset times.
            if nargin <3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <4 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            if nargin<5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

            if this.verbose
                tot=numel(stimulus_nums)*numel(chan_nums)*numel(epoch_nums);
                counter=0;
            end
            for stimulus_num=reshape(stimulus_nums,1,[])

                %
                for chan=reshape(chan_nums,1,[])
                    time_win=this.getTimeWin(EPR,chan,stimulus_num);
                    for epoch=reshape(epoch_nums,1,[])

                        if this.verbose
                            counter=counter+1;
                            fprintf('Detecting onset %d/%d\n',counter,tot);
                        end

                        x=eprecorder_get_epoch_data(EPR,chan,epoch,time_win);
                        switch(this.autoChangeTimeDetectionMethod)
                            case 'findchangepts'
                                idx=this.autoDetectChangeTimeIndex(x);
                            case 'mep_classifier'
                                [idx,~,~]=this.classify(x',EPR.Fs);
                            otherwise
                                error('Unknow autoChangeTimeDetectionMethod, %s', this.autoChangeTimeDetectionMethod);
                        end


                        idx_time=eprecorder_sample2time(EPR,idx);
                        
                        onset_time=NaN;
                        if not(isempty(idx_time))
                            % Convert back to ms.
                            idx_time=idx_time*1000; 
        
                            % Correct the offset deu to a sub window being used to
                            % obtain idx_time.
                            onset_time=idx_time+time_win(1);
                        end                    
    
                        % Record data
                        EPR=eprecorder_response.setAutoOnsetTime(EPR,chan,epoch,onset_time,stimulus_num);
                    end
                end
            end

        end
        function EPR=autoDetectStopTimes(this,EPR,chan_nums,epoch_nums,stimulus_nums)
            % Auto detect response stop time for all channels and epochs.
            % 
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            % stimulus_nums int|array<int>: The stimulus number/s to
            %   consider.
            % [OUTPUT]
            % EPR: The input EPR with updated auto response stop times.
            
            if nargin <3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <4 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            if nargin<5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

            if this.verbose
                tot=numel(stimulus_nums)*numel(chan_nums)*numel(epoch_nums);
                counter=0; 
            end
            for stimulus_num=reshape(stimulus_nums,1,[])

                %
                for chan=reshape(chan_nums,1,[])
                    time_win=this.getTimeWin(EPR,chan,stimulus_num);
                    for epoch=reshape(epoch_nums,1,[])
                        if this.verbose
                            counter=counter+1;
                            fprintf('Detecting stop time %d/%d\n',counter,tot);
                        end
                        x=eprecorder_get_epoch_data(EPR,chan,epoch,time_win);
    
                        
                        switch(this.autoChangeTimeDetectionMethod)
                            case 'findchangepts'
                                % To find the stop time, find the first changepoint of 
                                % the flipped epoch.
                                x_flipped=flip(x);
                                idx_flipped=this.autoDetectChangeTimeIndex(x_flipped);
                                % Since the epoch was flipped, the time is in reverse
                                % and should now be corrected.
                                idx=size(x,2)-idx_flipped;
                            case 'mep_classifier'
                                [~,idx,~]=this.classify(x',EPR.Fs);
                            otherwise
                                error('Unknow autoChangeTimeDetectionMethod, %s', this.autoChangeTimeDetectionMethod);
                        end
    
                        
    
                        %
                        idx_time=eprecorder_sample2time(EPR,idx);
                        
                        stop_time=NaN;
                        if not(isempty(idx_time))
                            % Convert back to ms.
                            idx_time=idx_time*1000; 
        
                            % Correct the offset deu to a sub window being used to
                            % obtain idx_time.
                            stop_time=idx_time+time_win(1);
                        end                    
    
                        % Record data
                        EPR=eprecorder_response.setAutoStopTime(EPR,chan,epoch,stop_time,stimulus_num);
                    end
                end
            end

        end
        function EPR=detectPresenceUsingClassifier(this,EPR,chan_nums,epoch_nums)
            % Detect response presence for all channels and epochs
            % automatically using classifeir.
            % [INPUT]
            % EPR: The EPR data structure. 
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            % [OUTPUT]
            % EPR: The input EPR with updated response auto presence. 


            if nargin <3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <4 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end

            stimulus_nums=eprecorder_stimulus_numbers(EPR);
            if this.verbose
                tot=numel(stimulus_nums)*numel(chan_nums)*numel(epoch_nums);
                counter=0;
            end
            for stimulus_num=stimulus_nums
                for chan=reshape(chan_nums,1,[])
                    time_win=this.getTimeWin(EPR,chan,stimulus_num);
                    for epoch=reshape(epoch_nums,1,[])
                        if this.verbose
                            counter=counter+1;
                            fprintf('Detecting presence %d/%d\n',counter,tot);
                        end
                        presence=0;
                        if ~this.presenceBackgroundCheck || this.checkBackground(EPR,chan,epoch,stimulus_num)
                            response_data=eprecorder_get_epoch_data(EPR,chan,epoch,time_win);
        
                            switch(this.autoPresenceValidationMethod)
                                case 'peak2peak_threshold'
                                    peak2peak_thresh=this.presencePeak2peakThreshold;
                                otherwise
                                    peak2peak_thresh=0;
                            end
                            [start_idx]=this.classify(response_data',EPR.Fs,peak2peak_thresh,this.presenceMinWidth);
                                
                            % Criteria for presence
                            presence= ~isempty(start_idx) && ~isnan(start_idx);
                        end
    
                        % Save the presence
                        EPR=eprecorder_response.setAutoPresence(EPR,chan,epoch,presence,stimulus_num);
                    end
                end
            end
        end
        function EPR=detectPresence(this,EPR,feature_error_scale,chan_nums,epoch_nums)
            % Detect response presence for all channels and epochs
            % automatically. 
            %
            % NOTE:
            % Here we assume that stimulus was delivered at time=0ms. And
            % that regardless of the epoch type i.e stimulus code, the
            % baselines of all epochs are similar and have features that
            % are desimilar to those area of a valid respons.
            %
            % [INPUT]
            % EPR: The EPR data structure.
            % feature_error_scale double|[]: The number of feature standard
            %   daviations/errors above baseline at which response is detected.
            %   The default is 15. 
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            %
            % [OUTPUT]
            % EPR: The input EPR with updated response auto presence.   

            

            if nargin<3 || isempty(feature_error_scale)
                feature_error_scale=15;
            end

            if nargin <4 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <5 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end

            % If auto detection method is mew_classifier we will redirect.
            % TODO: reorganise presence detection to avoid this redirection.
            if strcmp(this.autoPresenceDetectionMethod,'mep_classifier')
                EPR=this.detectPresenceUsingClassifier(EPR,chan_nums,epoch_nums);
                return;
            end
            

            if any(strcmp({'features_nstd','features_confidence_interval'},this.autoPresenceValidationMethod))
                % Abitrary time offset to avoid using the data in the vicinity
                % of time t=0 for baseline to avoid stimulation artefact. 
                zero_time_offset=eprecorder_sample2time(EPR,100);
                t_end=0-zero_time_offset*1000;
    
                baseline_time_win=[EPR.epochs.time_win(1),t_end];
                if(baseline_time_win(1)>t_end)
                    warning(['There was not suitable baseline for detecting' ...
                        ' the presence responses automatically']);
                    return;
                end            
    
                % For each channel and epoch, get the features of baseline
                baseline=eprecorder_get_epoch_data(EPR,chan_nums,epoch_nums,baseline_time_win,true);
                baseline(isnan(baseline))=0;
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
            end


            stimulus_nums=eprecorder_stimulus_numbers(EPR);
            if this.verbose
                tot=numel(stimulus_nums)*numel(chan_nums)*numel(epoch_nums);
                counter=0;
            end
            % Detect the reponse by comparing the features computed from
            % baseline with the same feature from the response region.
            for stimulus_num=stimulus_nums
                for chan=reshape(chan_nums,1,[])
                    
                    for epoch=reshape(epoch_nums,1,[])
                        if this.verbose
                            counter=counter+1;
                            fprintf('Detecting presence %d/%d\n',counter,tot);
                        end
                        onset_time=eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
                        stop_time=eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
                        time_win=[onset_time,stop_time];
    
                        response_data=eprecorder_get_epoch_data(EPR,chan,epoch,time_win);
    
                        % Compute the area per sample again without caring for the unit of
                        % the area since it is not important here.
                        if any(strcmp({'features_nstd','features_confidence_interval'},this.autoPresenceValidationMethod))
                            response_area=trapz(abs(response_data))/size(response_data,2);
                        end
    
                        % Compute the the peak2peak of potential response.
                        response_p2p=peak2peak(response_data);
    
                        
                        % Criteria for presence
                        presence=0;
                        if diff(time_win) >= this.presenceMinWidth
                            if ~this.presenceBackgroundCheck || this.checkBackground(EPR,chan,epoch,stimulus_num)
                                switch(this.autoPresenceValidationMethod)
                                    case 'none'
                                        presence=1;
                                    case 'peak2peak_threshold'
                                        if(response_p2p > this.presencePeak2peakThreshold) 
                                            presence=1;
                                        end
                                    otherwise
                                        if (isLikeResponse(baseline_area(chan,:),response_area,feature_error_scale)...
                                            || isLikeResponse(baseline_p2p(chan,:),response_p2p,feature_error_scale)...
                                            ) && (response_p2p > this.presencePeak2peakThreshold) 
                                            presence=1;
                                        end
                                end
                            end
                        end
    
                        
                        % Save the presence
                        EPR=eprecorder_response.setAutoPresence(EPR,chan,epoch,presence,stimulus_num);
                    end
                end
            end

            function is_response=isLikeResponse(baseline_feature,response_feature,feature_error_scale,presence_validation_method)
                % Check if the given response feature sample looks like a
                % response  with respect to the baseline corresponding
                % feature. 
                % [INPUT]
                % baseline_feature array<double>: A feature computed from 
                %   baseline epochs where each entry is from an epoch.
                % response_feature double: The corresponding feature for one epoch. 
                %   It will be tested if this epoch is greater than those 
                %   from the baseline. 
                % feature_error_scale double: The number of feature 
                %   standard daviations/errors above baseline at which 
                %   response is detected. The default is 15. 
                % presence_validation_method string: The criteria for
                %   presence validation. {'features_nstd','features_confidence_interval'}.
                %   'nstd' is a fallback when confidence interval cannot be
                %   constructed deu to limited samples in baseline_feature.
                % [OUTPUT]
                % is_response boolean: True if it looks like a response.

                if nargin<3
                    feature_error_scale=15;
                end

                if nargin <4
                    presence_detection_criteria='confidence_interval';
                else
                    presence_detection_criteria=presence_validation_method;
                end

                % Criteria for response detection
                if length(baseline_feature)==1
                    presence_detection_criteria='features_nstd';
                end

                is_response=false;
                switch(presence_detection_criteria)
                    case 'features_confidence_interval'
                        sample_size=size(baseline_feature,2);
                        
                        if sample_size>30 && lillietest(baseline_feature)==0
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
                        std_error=std(baseline_feature)/sqrt(sample_size);

                        % Allow the caller to tune/scale the confidence width.
                        std_error=feature_error_scale*std_error;

                        % Construct confidence interval
                        confidence_interval=mean(baseline_feature)+(stats*std_error);

                        % Check if the response_feature is large than
                        % the upper limit of confidence interval of the
                        % baseline mean feature.
                        if(response_feature>confidence_interval(2))
                            is_response=true;
                        end

                    case 'features_nstd'
                        %   For a response to be detected, a
                        %   feature (such as response area) computed from the effective
                        %   response feature is required to be N times 
                        %   greater than the standard deviation of the same feature
                        %   computed for the time window before stimulus.
                        %
                        % NOTE here that feature_error_scale is less useful 
                        % when length(baseline_feature)==1 (i.e std==0), especially 
                        % when epsilon is very small.
                        epsilon=eps;
                        baseline_feature_nstd=mean(baseline_feature)+ (std(baseline_feature) +epsilon)*feature_error_scale; % epsilon ensures the std is not exactly zero which e.g happens when length(baseline_feature)==1.
                        if response_feature > baseline_feature_nstd
                            is_response=true;
                        end
                end

            end
            
        end
        function EPR=detectPeak2peaks(this,EPR,chan_nums,epoch_nums)
            % Detect response peak2peaks for all channels and epochs.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            % [OUTPUT]
            % EPR: The input EPR with updated response peak2peaks.
            if nargin <3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <4 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end

            for stimulus_num=eprecorder_stimulus_numbers(EPR)
                for chan=reshape(chan_nums,1,[])
                    
                    for epoch=reshape(epoch_nums,1,[])
                        onset_time=eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
                        stop_time=eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
                        time_s=[onset_time,stop_time];
    
                        x=eprecorder_get_epoch_data(EPR,chan,epoch,time_s);
                        p2p=peak2peak(x);
                        EPR=eprecorder_response.setPeak2peak(EPR,chan,epoch,p2p,stimulus_num);
                    end
                end
            end
            
        end
        function EPR=detectArea(this,EPR,chan_nums,epoch_nums)
            % Detect response area for all channels and epochs.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number/s to consider. 
            % epoch_nums int|array<int>|[]: The epoch number/s of the trial/s.
            % [OUTPUT]
            % EPR: The input EPR with updated response areas.
            if nargin <3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <4 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            
            for stimulus_num=eprecorder_stimulus_numbers(EPR)
                for chan=reshape(chan_nums,1,[])
                    
                    for epoch=reshape(epoch_nums,1,[])
                        onset_time=eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
                        stop_time=eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
                        time_win=[onset_time,stop_time];
    
                        y=eprecorder_get_epoch_data(EPR,chan,epoch,time_win);
    
                        % Comput area in 'channel unit  x s'
                        y_area=trapz(abs(y))*1/EPR.Fs;
    
                        % Conver area to 'channel unit x ms'
                        y_area=y_area*1000;
    
                        % Save the area
                        EPR=eprecorder_response.setArea(EPR,chan,epoch,y_area,stimulus_num);
                    end
                end
            end
            
        end

        
        
    end

    
    methods(Access=protected)
        function idx=autoDetectChangeTimeIndex(this,x)
            % Find the begining of the response. The find the end of the
            %   response, you should flip x first.
            % [INPUT]
            % x array: 1d array to find response on.
            % [OUTPUT]
            % idx int|[]: The index of the response starting point or []
            % when point could not be detected.

            switch(this.autoChangeTimeDetectionMethod)
                case 'findchangepts'
                    params=this.autoChangeTimeDetectionMethodData;
                    
                    params=eprecorder_response.lineariseNameValuePairs(params);
                    idx=this.findChangePoints(x,params);
                    if isempty(idx)
                        idx=[];
                    else
                        idx=idx(1);
                    end
                case 'mep_classifier'
                    error('mep_classifier for autoDetectChangeTimeIndex is not yet implemented. You should instead call the classify() method directly');
                otherwise
                    error('Unknown change time detection method');
            end
        end
        function ipt=findChangePoints(this,x,name_val_pairs)
            % Use Changepoint function to detect changepoints in x.
            % [INPUT]
            % x array: to detect change in x.
            % name_val_pairs cell: Name-value pairs as findchangepts params e.g. {'statistic','mean'}
            % [OUTPUT]
            % ipt int|array: The index|indexes of the column of x with
            %   change point. 

            % 
            ipt = findchangepts(x,name_val_pairs{:});
        end
    end

    methods(Static)
        function EPR=addFields(EPR,force)
            % Add EP response feature fields to the EPR data structure. An
            % error will occur if the MEP fields already exists unless
            % input 'force'==true.
            % [INPUT]
            % EPR: Epoched main EPR structure.
            % force boolean: When true the fields will be added even if it 
            %   already exists. The default is false.
            % [OUTPUT]
            % EPR: The input structure with features.response field added.
            %      Each added field of response is a cell of size=1 x 1+len(find(EPR.ISI)). 
            %      The first entry corresponds to the primary trigger and 
            %      the other correspond to non-zero EPR.ISI entries:---------------
            %       features.response.time_win_start cell:@see EPR above. Each entry is: Response time(ms) window starting point within which
            %           EP response features should be computed for each channel. This
            %           time is relative to the time locking event (e.g. t=0 for primary trigger). Dimension is  
            %           [nchannels x 1].
            %       features.response.time_win_end cell: @see EPR above. Each entry is: EP response time(ms) window end
            %           point within which response features should be computed for each channel.
            %           This time is relative to the time locking event(e.g. t=0 for primary trigger). Dimension is
            %           [nchannels x 1].  
            %       features.response.auto_presence cell: @see EPR above. Each entry is: An array where an entry with 1 implies
            %           that the corresponding epoch channel has EP response as automatically 
            %           detected. This time is relative to the time locking event(e.g. t=0 for primary trigger).
            %           Dimension is [nchannels x ntrials] and ntrials corresponds to 
            %           the 3rd axis of data.
            %       features.response.manual_presence cell: @see EPR above. Each entry is:  An array where an entry with 1 implies
            %           that the corresponding epoch channel has EP response as manually 
            %           detected. This time is relative to the time locking event(e.g. t=0 for primary trigger).
            %           Dimension is [nchannels x ntrials] and ntrials corresponds to 
            %           the 3rd axis of data.
            %       features.response.auto_onset_time cell: @see EPR above. Each entry is:  An array where an entry indicates the
            %           automatically detected onset time(ms) of response. This time is relative to the time
            %           locking event(e.g. t=0 for primary trigger). A NaN entry indicates that the entry is not set.
            %       features.response.auto_stop_time: Similar to auto_start_time but
            %           but for end time(ms).
            %       features.response.manual_onset_time cell: Similar to auto_start_time but
            %           manually entered time(ms).
            %       features.response.manual_stop_time cell: Similar to manual_start_time but
            %           but for end time(ms).
            %       features.response.peak2peak: cell: @see EPR above. Each entry is:  Response peak to peak
            %           amplitude channel unit for each epoch and channel.
            %           Dimension is [nchannels x ntrials]. 
            %       features.response.area  cell: @see EPR above. Each entry is:  The response area for each epoch
            %           and channel. Dimension is [nchannels x ntrials].
            %       
            if nargin<2
                force=false;
            end
            if ~eprecorder_has_epoch(EPR)
                error('Epoched data is required in order to add response feature');
            end
            
            if(~force && isfield(EPR.epochs,'features'))
                if(isfield(EPR.epochs.features,'response'))
                    error('EP response feature fields already exists');
                end
            end
            
            
            n_epochs=size(EPR.data,3);
            n_channels=size(EPR.data,1);
            
            response.time_win_start=nan(n_channels,1);
            response.time_win_end=nan(n_channels,1);

            
            
            response.auto_presence=nan(n_channels,n_epochs);
            response.manual_presence=response.auto_presence;
            
            response.auto_onset_time=nan(n_channels,n_epochs);
            response.auto_stop_time=nan(n_channels,n_epochs);
            
            response.manual_onset_time=nan(n_channels,n_epochs);
            response.manual_stop_time=nan(n_channels,n_epochs);
            
            response.peak2peak=zeros(n_channels,n_epochs);
            
            response.area=zeros(n_channels,n_epochs);
            
            % Now make the entries for primary and secondary stimuli
            [~,isi]=eprecorder_stimulus_numbers(EPR);
            fields=fieldnames(response);
            for n=1:length(fields)
                for m=1:length(isi)
                    resp_val=response.(fields{n});
                    if strcmp(fields{n},'time_win_start')
                        [resp_val,~]=eprecorder_response.defaultTimeWin(EPR,m,n_channels);
                    end
                    if strcmp(fields{n},'time_win_end')
                        [~,resp_val]=eprecorder_response.defaultTimeWin(EPR,m,n_channels);
                    end
                    EPR.epochs.features.response.(fields{n}){m}=resp_val;
                end
            end
            
            
        end
        function [time_win_start,time_win_end] =defaultTimeWin(EPR,stimulus_num,chan_count)
            % A helper to compute the default values for response
            % time_win_start/end. 
            %
            % [INPUT]
            % EPR struct: EPR data structure.
            % stimulus_num int|[]: The stimulus number. The default is the
            %   number for the primary stimulus.
            % chan_count int: Number of data channels. The default is
            %   the total number of channels.
            % [OUTPUT]
            % time_win_start array<double>: Start of response time window in
            %   milliseconds. Size= chan_count x 1.
            % time_win_end array<double>: End of response time window in
            %   milliseconds. Size= chan_count x 1.
            %

            if nargin <2 || isempty(stimulus_num)
                stimulus_num=1;
            end

            if nargin < 3
                chan_count=length(EPR.channelNames);
            end

            [~,stimuli]=eprecorder_stimulus_numbers(EPR);
            
            % Start time
            time_win_start=stimuli(stimulus_num);
            if ~isempty(EPR.viewerP2pTimeWin)
                time_win_start=time_win_start+EPR.viewerP2pTimeWin(1);
            end
            time_win_start=repmat(time_win_start,chan_count,1);
            
            % End time
            if(stimulus_num==length(stimuli))
                % For the last one the last viewer window is a good
                % default time_win_end
                time_win_end=nan;
                if ~isempty(EPR.viewerP2pTimeWin)
                    time_win_end=stimuli(stimulus_num)+EPR.viewerP2pTimeWin(2);
                end
            else
                % Otherwise we use the adjusted time of the next
                % stimulus.
                step_back_by=5;% milliseconds.

                %The subtraction is to move back by an arbitrary amount
                %to void including the next stim artifact. 
                time_win_end=stimuli(stimulus_num+1) - step_back_by; 
            end
            time_win_end=repmat(time_win_end,chan_count,1);
            
        end
        function EPR=setTimeWin(EPR,chan_nums,time_win,stimulus_num)
            % Define a response time window for a given channel/s.
            % [INPUT]
            % EPR struct: EPR data structure
            % chan_nums int|array<int>|[]: A scalar or 1-D array of channel
            %   numbers. Set empty, [] for all channels.
            % time_win array: A 2-element vector where the first element is
            %   the time window start and the 2nd is the stop.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR struct: The EPR structure with reponse time window
            %   updated.
            if nargin<4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end


            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            EPR.epochs.features.response.time_win_start{stimulus_num}(chan_nums)=time_win(1);
            EPR.epochs.features.response.time_win_end{stimulus_num}(chan_nums)=time_win(2);
            
        end
        function time_win=getTimeWin(EPR,chan_num,stimulus_num)
            % Get a define response time window for a given channel.
            % [INPUT]
            % EPR struct: EPR data structure
            % chan_num int: The channel.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % time_win array<double>: A 2-element vector where the first element is
            %   the time(ms) window start and the 2nd is the stop.

            if nargin < 3
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            time_win=[EPR.epochs.features.response.time_win_start{stimulus_num}(chan_num),...
                EPR.epochs.features.response.time_win_end{stimulus_num}(chan_num)
            ];
        end
        
        function EPR=setManualPresence(EPR,chan_num,epoch_num,presence,stimulus_num)
            % Set the EP presence status of the given epoch according to
            % manual detection. 
            % [INPUT]
            % EPR struct: The EPR structure
            % chan_num integer: The Channel whos EP presence is to be set.
            % epoch_num integer: The epoch number of the trial.
            % presence boolean|int|NaN: True to set that EP is present in the
            %   given epoch. NaN to unset.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR struct: The EPR structure with reponse presence updated.

            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if(islogical(presence))
                presence=double(presence);
            end
            EPR.epochs.features.response.manual_presence{stimulus_num}(chan_num,epoch_num)=presence;
            %EPR.epochs.features.response.manual_presence{stimulus_num}(4,:)=presence;%DELETE
        end
        function responses=getManualPresence(EPR,chan_nums,epoch_nums,stimulus_num)
            % Check if the epoch given by epoch number has manually
            % detected EP response. 
            % [INPUT]
            % EPR struct: The EPR structure
            % chan_nums int|array<int>: The channel number/s to check in
            %   the trial. 
            % epoch_nums int|array<int>: The epoch number/s of the trial.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % has_responses int|array<int>: An entry of 1 where an epoch/s
            %   has EP response, 0 otherwise. A value of nan implies the response status
            %   has not be set manually. Dimension is [nchan_nums x nepoch_nums]. 

            if nargin<4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            responses=EPR.epochs.features.response.manual_presence{stimulus_num}( ...
                chan_nums,epoch_nums);
            
        end
        function EPR=setAutoPresence(EPR,chan_num,epoch_num,presence,stimulus_num)
            % Set the EP presence status of the given epoch according to
            % automatic detection. 
            % [INPUT]
            % EPR struct: The EPR structure
            % chan_num integer: The Channel whos EP presence is to be set.
            % epoch_num integer: The epoch number of the trial.
            % presence boolean|int|NaN: True to set that EP is present in the
            %   given epoch. NaN to unset.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR struct: The EPR structure with reponse presence updated.

            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if(islogical(presence))
                presence=double(presence);
            end
            EPR.epochs.features.response.auto_presence{stimulus_num}(chan_num,epoch_num)=presence;
        end
        function responses=getAutoPresence(EPR,chan_nums,epoch_nums,stimulus_num)
            % Check if the epoch given by epoch number has automatically
            % detected EP response. 
            % [INPUT]
            % EPR struct: The EPR structure
            % chan_nums int|array<int>: The channel number/s to check in
            %   the trial. 
            % epoch_nums int|array<int>: The epoch number/s of the trial.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % has_responses int|array<int>: An entry of 1 where an epoch/s
            %   has EP response, 0 otherwise. A value of nan implies the response status
            %   has not be set automaticaly. Dimension is [nchan_nums x nepoch_nums]. 

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            responses=EPR.epochs.features.response.auto_presence{stimulus_num}( ...
                chan_nums,epoch_nums);
        end
        function has_responses=has(EPR,chan_nums,epoch_nums,stimulus_num)
            % Check if the epoch given by epoch number has manually or auto
            % detected EP response. The automatic response status is only
            % used when the manual status is not set. 
            % [INPUT]
            % EPR struct: The EPR structure
            % chan_nums int|array<int>|[]: The channel number/s to check in
            %   the trial. The detault/[] is all channels.
            % epoch_nums int|array<int>|[]: The epoch number/s of the
            %   trial. The detault/[] is all epochs.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % has_responses boolean|array<boolean>: True where an epoch/s
            %   has EP response. An entry will have a false value if both
            %   manual and auto response presense are not set. 
            %   Dimension is [nchan_nums x nepoch_nums]. 

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3 || isempty(epoch_nums)
                epoch_nums=1:EPR.trials;
            end
            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            has_responses=eprecorder_response.getManualPresence(EPR,chan_nums,epoch_nums,stimulus_num);
            auto=eprecorder_response.getAutoPresence(EPR,chan_nums,epoch_nums,stimulus_num);
            auto(isnan(auto))=0;
            for n=1:numel(has_responses)
                if isnan(has_responses(n))
                    has_responses(n)=auto(n);
                end
            end
            has_responses=~~has_responses;
        end
        
        function EPR=setAutoOnsetTime(EPR,chan_num,epoch_num,onset_time,stimulus_num)
            % Set the auto detected response onset time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % onset_time double:The onset time (ms) relative to the time
            %   locking event at t=0.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response onset time.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            EPR.epochs.features.response.auto_onset_time{stimulus_num}(chan_num,epoch_num)=onset_time;
        end
        function onset_time=getAutoOnsetTime(EPR,chan_nums,epoch_num,stimulus_num)
            % Get the auto detected response onset time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % onset_time double|array<double>: The onset time (ms) relative to the time
            %   locking event at t=0. It is a row vector for all epochs if
            %   epoch_num is not given.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if nargin<3
                epoch_num=[];
            end

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            onset_time=EPR.epochs.features.response.auto_onset_time{stimulus_num}(chan_nums,:);
            if not(isempty(epoch_num))
                onset_time=onset_time(:,epoch_num);
            end
        end
        function EPR=setAutoStopTime(EPR,chan_num,epoch_num,stop_time,stimulus_num)
            % Set the auto detected response stop time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % stop_time double:The stop time (ms) relative to the time
            %   locking event at t=0.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response auto stop time.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            EPR.epochs.features.response.auto_stop_time{stimulus_num}(chan_num,epoch_num)=stop_time;
        end
        function stop_time=getAutoStopTime(EPR,chan_nums,epoch_num,stimulus_num)
            % Get the auto detected response stop time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % stop_time double|array<double>: The stop time (ms) relative to the time
            %   locking event at t=0. It is a row vector for all epochs if
            %   epoch_num is not given.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3
                epoch_num=[];
            end

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            stop_time=EPR.epochs.features.response.auto_stop_time{stimulus_num}(chan_nums,:);
            if not(isempty(epoch_num))
                stop_time=stop_time(:,epoch_num);
            end
        end
        function EPR=setManualOnsetTime(EPR,chan_num,epoch_num,onset_time,stimulus_num)
            % Set the manually entered onset time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % onset_time double:The onset time (ms) relative to the time
            %   locking event at t=0.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response onset time.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end
            EPR.epochs.features.response.manual_onset_time{stimulus_num}(chan_num,epoch_num)=onset_time;
        end
        function onset_time=getManualOnsetTime(EPR,chan_nums,epoch_num,stimulus_num)
            % Get the manually entered response stop time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % onset_time double|array<double>: The onset time (ms) relative to the time
            %   locking event at t=0. It is a row vector for all epochs if
            %   epoch_num is not given.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            
            if nargin<3
                epoch_num=[];
            end
            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            onset_time=EPR.epochs.features.response.manual_onset_time{stimulus_num}(chan_nums,:);
            if not(isempty(epoch_num))
                onset_time=onset_time(:,epoch_num);
            end
        end
        function EPR=setManualStopTime(EPR,chan_num,epoch_num,onset_time,stimulus_num)
            % Set the manually entered response end time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % onset_time double:The end time (ms) relative to the time
            %   locking event at t=0.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response end time.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end
            EPR.epochs.features.response.manual_stop_time{stimulus_num}(chan_num,epoch_num)=onset_time;
        end
        function stop_time=getManualStopTime(EPR,chan_nums,epoch_num,stimulus_num)
            % Get the manually eneterd response end time
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % stop_time double|array<double>: The end onset time (ms) relative to the time
            %   locking event at t=0. It is a row vector for all epochs if
            %   epoch_num is not given.

            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3
                epoch_num=[];
            end

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            stop_time=EPR.epochs.features.response.manual_stop_time{stimulus_num}(chan_nums,:);
            if not(isempty(epoch_num))
                stop_time=stop_time(:,epoch_num);
            end
        end
        function onset_time=getEffectiveOnsetTime(EPR,chan_num,epoch_num,stimulus_num)
            % Return the response onset time depending on the first found
            % value in the following order:
            % manual_onset_time,auto_onset_time,time_win_start or the start of epoch.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % onset_time double: The onset time (ms) relative to the time
            %   locking event at t=0.

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            % Use manual time_win if set, otherwise use auto detected one
            onset_time=eprecorder_response.getManualOnsetTime(EPR,chan_num,epoch_num,stimulus_num);
            if isnan(onset_time)
                onset_time=eprecorder_response.getAutoOnsetTime(EPR,chan_num,epoch_num,stimulus_num);
            end

            if isnan(onset_time)
                % Check if there is a defined response time window and use
                % it
                time_win=eprecorder_response.getTimeWin(EPR,chan_num,stimulus_num);
                onset_time=time_win(1);
            end

            if isnan(onset_time)
                onset_time=EPR.times(1);
            end
                
        end
        function onset_times=getEffectiveOnsetTimes(EPR,chan_nums,epoch_nums,stimulus_code,exclude_no_response,exclude_reject,stimulus_num)
            % Get the effective response onset times. This method is the
            % plural of the method .getEffectiveOnsetTime. 
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums int|array<int>: The channel number.
            % epoch_nums int|array<int>: The epoch numbers. Set to [] when
            %   providing event_code.
            % stimulus_code int|[]: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % exclude_no_response boolean: When true epochs without a
            %   response will have a corresponding value of NaN. The
            %   default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will have a corresponding value of NaN. The default is
            %   false.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % onset_times array <double>: Onset times (ms) (@see
            %   getEffectiveStopTime). Dimension is [nchan_nums x nepoch_nums], 
            %   where when input is [], nepoch_nums is determined using the
            %   stimulus code.
            if nargin<4
                stimulus_code=[];
            end
            if nargin<5
                exclude_no_response=false;
            end

            if nargin<6
                exclude_reject=false;
            end

            if nargin < 7
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end
            
            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
            end

            onset_times=zeros(length(chan_nums),length(epoch_nums));
            for m=1:length(chan_nums)
                chan_num=chan_nums(m);
                for n=1:length(epoch_nums)
                    epoch_num=epoch_nums(n);
                    onset_times(m,n)=eprecorder_response.getEffectiveOnsetTime( ...
                        EPR,chan_num,epoch_num,stimulus_num);

                    % Exclude no response
                    if exclude_no_response
                        has_response=eprecorder_response.has( ...
                                        EPR,chan_num,epoch_num,stimulus_num);
                        if not(has_response)
                            onset_times(m,n)=NaN;
                        end
                    end

                    % Exclude rejects
                    if exclude_reject
                        is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                                        EPR,chan_num,epoch_num);
                        if is_rejected
                            onset_times(m,n)=NaN;
                        end
                    end
                end
            end
        end
        function stop_time=getEffectiveStopTime(EPR,chan_num,epoch_num,stimulus_num)
            % Return the response stop time depending on the first found
            % value in the following order:
            % manual_stop_time, auto_stop_time time_win_end, or the end of epoch.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % onset_time double: The stop time (ms) relative to the time
            %   locking event at t=0.

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end


            % If the manual stop time is not set, we will use the defined 
            % response time window or the end of trial in that order.
            stop_time=eprecorder_response.getManualStopTime( ...
                EPR,chan_num,epoch_num,stimulus_num);
            if isnan(stop_time)
                stop_time=eprecorder_response.getAutoStopTime( ...
                    EPR,chan_num,epoch_num,stimulus_num);
            end
            if isnan(stop_time)
                % Check if there is a defined response time window and use
                % it
                time_win=eprecorder_response.getTimeWin(EPR,chan_num,stimulus_num);
                stop_time=time_win(2);%i.e time_win_end
            end
            if isnan(stop_time)
                % Then use the end of the epoch.
                stop_time=EPR.times(end);
            end
        end
        function stop_times=getEffectiveStopTimes(EPR,chan_nums,epoch_nums,stimulus_code,exclude_no_response,exclude_reject,stimulus_num)
            % Get the effective response stop times. This method is the
            % plural of the method .getEffectiveStopTime. 
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums int|array<int>: The channel number.
            % epoch_nums int|array<int>: The epoch numbers. Set to [] when
            %   providing event_code.
            % stimulus_code int|[]: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % exclude_no_response boolean: When true epochs without a
            %   response will have a corresponding value of NaN. The
            %   default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will have a corresponding value of NaN. The default is
            %   false. 
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % stop_times array <double>: Stop times (ms) (@see
            %   getEffectiveStopTime). Dimension is [nchan_nums x nepoch_nums], 
            %   where when input is [], nepoch_nums is determined using the
            %   stimulus code.
            if nargin<4
                stimulus_code=[];
            end
            if nargin<5
                exclude_no_response=false;
            end

            if nargin<6
                exclude_reject=false;
            end

            if nargin < 7
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
            end

            stop_times=zeros(length(chan_nums),length(epoch_nums));
            for m=1:length(chan_nums)
                chan_num=chan_nums(m);
                for n=1:length(epoch_nums)
                    epoch_num=epoch_nums(n);
                    stop_times(m,n)=eprecorder_response.getEffectiveStopTime( ...
                        EPR,chan_num,epoch_num,stimulus_num);

                    % Exclude no response
                    if exclude_no_response
                        has_response=eprecorder_response.has( ...
                                        EPR,chan_num,epoch_num,stimulus_num);
                        if not(has_response)
                            stop_times(m,n)=NaN;
                        end
                    end

                    % Exclude rejects
                    if exclude_reject
                        is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                                        EPR,chan_num,epoch_num);
                        if is_rejected
                            stop_times(m,n)=NaN;
                        end
                    end
                end
            end
        end
        function EPR=copyTimesFromLabel(EPR,chan_nums,epoch_nums,stimulus_nums)
            % Import manual response start & stop times from label i.e EPR.epochs.features.label. 
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array|[]: The channel numbers. The default is
            %   all channels.
            % epoch_nums int|array|[]: The epoch numbers. The default is
            %   all epochs.
            % stimulus_nums int|array|[]: The stimulus numbers. The default 
            %   is the number for all stimuli.
            % [OUTPUT]
            % EPR struct:The input EPR with response start & stop times.
            if nargin <2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <3 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            if nargin<4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

            
                
            for stimulus_num=reshape(stimulus_nums,1,[])

                %
                for chan=reshape(chan_nums,1,[])

                    for epoch=reshape(epoch_nums,1,[])
                        onset_time=eprecorder_label.getTime(eprecorder_label.RESPONSE_START,EPR,chan,epoch,stimulus_num);
                        stop_time=eprecorder_label.getTime(eprecorder_label.RESPONSE_STOP,EPR,chan,epoch,stimulus_num);


                        EPR=eprecorder_response.setManualOnsetTime(EPR,chan,epoch,onset_time,stimulus_num);
                        EPR=eprecorder_response.setManualStopTime(EPR,chan,epoch,stop_time,stimulus_num);

                    end
                end
            end

        end
        function EPR=copyPresenceFromLabel(EPR,chan_nums,epoch_nums,stimulus_nums)
            % Import manual presence status from label i.e EPR.epochs.features.label.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array|[]: The channel numbers. The default is
            %   all channels.
            % epoch_nums int|array|[]: The epoch numbers. The default is
            %   all epochs.
            % stimulus_nums int|array|[]: The stimulus numbers. The default 
            %   is the number for all stimuli.
            % [OUTPUT]
            % EPR struct:The input EPR with updated presence.
            if nargin <2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <3 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            if nargin<4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

            
                
            for stimulus_num=reshape(stimulus_nums,1,[])

                %
                for chan=reshape(chan_nums,1,[])
                    
                    for epoch=reshape(epoch_nums,1,[])
                        presence=eprecorder_label.presence(EPR,chan,epoch,stimulus_num);
                        
                        EPR=eprecorder_response.setManualPresence(EPR,chan,epoch,presence,stimulus_num);

                    end
                end
            end

        end
        function time_widths=getEffectiveTimeWidths(EPR,chan_nums,epoch_nums,stimulus_code,exclude_no_response,exclude_reject,stimulus_num)
            % Get the effective time width of response i.e stop_time-onset_time. 
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums int|array<int>: The channel number.
            % epoch_nums int|array<int>: The epoch numbers. Set to [] when
            %   providing event_code.
            % stimulus_code int|[]: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % exclude_no_response boolean: When true epochs without a
            %   response will have a corresponding value of NaN. The
            %   default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will have a corresponding value of NaN. The default is
            %   false. 
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % time_widths array <double>: Time widths (ms). Stop times (ms) (@see
            %   getEffectiveStopTime). Dimension is [nchan_nums x nepoch_nums], 
            %   where when input is [], nepoch_nums is determined using the
            %   stimulus code.
            

            if nargin<4
                stimulus_code=[];
            end
            if nargin<5
                exclude_no_response=false;
            end
            if nargin<6
                exclude_reject=false;
            end

            if nargin < 7
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
            end

            time_widths=zeros(length(chan_nums),length(epoch_nums));
            for m=1:length(chan_nums)
                chan_num=chan_nums(m);
                for n=1:length(epoch_nums)
                    epoch_num=epoch_nums(n);
                    onset_time=eprecorder_response.getEffectiveOnsetTime( ...
                        EPR,chan_num,epoch_num,stimulus_num);
                    stop_time=eprecorder_response.getEffectiveStopTime( ...
                        EPR,chan_num,epoch_num,stimulus_num);
                    time_widths(m,n)=stop_time-onset_time;

                    % Exclude no response
                    if exclude_no_response
                        has_response=eprecorder_response.has( ...
                                        EPR,chan_num,epoch_num,stimulus_num);
                        if not(has_response)
                            time_widths(m,n)=NaN;
                        end
                    end

                    % Exclude rejects
                    if exclude_reject
                        is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                                        EPR,chan_num,epoch_num);
                        if is_rejected
                            time_widths(m,n)=NaN;
                        end
                    end
                end
            end
        end
        function EPR=setPeak2peak(EPR,chan_num,epoch_num,peak2peak,stimulus_num)
            % Set the response peak2peak.
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % peak2peak: Response peak2peak in channel unit i.e
            %   EPR.channelUnits{chan_nums(n)}. 
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response peak2peak.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            EPR.epochs.features.response.peak2peak{stimulus_num}(chan_num,epoch_num)=peak2peak;
        end
        function peak2peaks=getPeak2peak(EPR,chan_nums,epoch_nums,stimulus_code,exclude_no_response,exclude_reject,stimulus_num)
            % Get the response peak2peak.
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number. Set to []
            %   for all channels
            % epoch_nums int|array|[]<int>: The epoch numbers. Set to [] when
            %   providing stimulus_code. If both this and stimulus_code are
            %   empty, all epochs will be considered.
            % stimulus_code int|[]: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % exclude_no_response boolean: When true epochs without a
            %   response will have a corresponding value of NaN. The
            %   default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will have a corresponding value of NaN. The default is
            %   false.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % peak2peak: Response peakpeak in channel unit. Dimension is
            %   [nchan_nums x nepoch_nums], where when input is [], nepoch_nums
            %   is determined using the stimulus code.
            if nargin<4
                stimulus_code=[];
            end
            if nargin<5
                exclude_no_response=false;
            end

            if nargin<6
                exclude_reject=false;
            end

            if nargin < 7
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
            end

            if isempty(epoch_nums) && isempty(stimulus_code)
                % Condering all epochs.
                epoch_nums=1:EPR.trials;
            end

            peak2peaks=EPR.epochs.features.response.peak2peak{stimulus_num}(chan_nums,epoch_nums);

            % Exclude no response
            if exclude_no_response
                has_responses=eprecorder_response.has(EPR,chan_nums,epoch_nums,stimulus_num);
                peak2peaks(~has_responses)=NaN;
            end

            % Exclude rejects
            if exclude_reject
                is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                    EPR,chan_nums,epoch_nums);
                peak2peaks(is_rejected)=NaN;
            end
        end
        function EPR=setArea(EPR,chan_num,epoch_num,response_area,stimulus_num)
            % Set the response area.
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % response_area: Response area in channel unit x ms.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated response area.
            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            EPR.epochs.features.response.area{stimulus_num}(chan_num,epoch_num)=response_area;
        end

        function areas=getArea(EPR,chan_nums,epoch_nums,stimulus_code,exclude_no_response,exclude_reject,stimulus_num)
            % Get the response area/s.
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums int|array<int>|[]: The channel number. Set to []
            %   for all channels
            % epoch_nums int|array|[]<int>: The epoch numbers. Set to [] when
            %   providing stimulus_code. If both this and stimulus_code are
            %   empty, all epochs will be considered.
            % stimulus_code int: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % exclude_no_response boolean: When true epochs without a
            %   response will have a corresponding value of NaN. The
            %   default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will have a corresponding value of NaN. The default is
            %   false.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % areas array <double>: Areas (channel unit x ms). Dimension is [nchan_nums x nepoch_nums],
            %   where when input is [], nepoch_nums is determined using the
            %   stimulus code.

            if nargin<4
                stimulus_code=[];
            end
            if nargin<5
                exclude_no_response=false;
            end

            if nargin<6
                exclude_reject=false;
            end

            if nargin < 7
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            if isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
            end

            if isempty(epoch_nums) && isempty(stimulus_code)
                % Condering all epochs.
                epoch_nums=1:EPR.trials;
            end

            areas=EPR.epochs.features.response.area{stimulus_num}(chan_nums,epoch_nums);

            % Exclude no response
            if exclude_no_response
                has_responses=eprecorder_response.has( ...
                    EPR,chan_nums,epoch_nums,stimulus_num);
                areas(~has_responses)=NaN;
            end
            
            % Exclude rejects
            if exclude_reject
                is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                    EPR,chan_nums,epoch_nums);
                areas(is_rejected)=NaN;
            end
            
            
        end
        function [ep,t]=average(EPR,chan_nums,epoch_nums,stimulus_code,time_win,exclude_no_response,exclude_reject)
            % Get the responses as evoked potential.
            % [INPUT]
            % EPR struct: The EPR data structure.
            % chan_nums []|int|array<int>: The channel number. Default|[]
            %   is all channels.
            % epoch_nums []|int|array<int>: The epoch numbers. Set to [] when
            %   providing event_code. If this and stimulus_code are empty,
            %   all trials will be used.
            % stimulus_code []|double: The event code of interest. Ignored unless
            %   epoch_nums=[].
            % time_win []|array<double>: The time(ms) range within an epoch.
            % exclude_no_response boolean: When true epochs without a
            %   response will be NaN. The default is false.
            % exclude_reject boolean: When true epochs that are excluded
            %   will be NaN. The default is false.
            % [OUTPUT]
            % ep array<double>: Evoked potential(same unit channel data).
            % Dimension is [nchan_nums x len(time_range)] 
            % t array<double>: Time(ms).
            if nargin<2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<3
                epoch_nums=[];
            end
            if nargin<4
                stimulus_code=[];
            end
            if nargin<5 || isempty(time_win)
                 time_win=[EPR.times(1),EPR.times(end)];
            end
            if nargin<6
                exclude_no_response=false;
            end

            if nargin<7
                exclude_reject=false;
            end

            

            if not(isempty(epoch_nums))
                stimulus_code=[];
            end

            if not(isempty(stimulus_code))
                epoch_nums=eprecorder_epochs_for(EPR,stimulus_code);
                if(isempty(epoch_nums))
                    error('No epoch found for stimulus_code, %g',stimulus_code);
                end
            end

            if isempty(epoch_nums)
                epoch_nums=1:EPR.trials;
            end


            % Get the epochs
            ep=eprecorder_get_epoch_data(EPR,chan_nums,epoch_nums,time_win);
            

            % Exclude no response.
            if exclude_no_response
                has_responses=eprecorder_response.has( ...
                    EPR,chan_nums,epoch_nums);
                

                % Convert has_response to be the same size as the ep data.
                [rs,cs]=size(has_responses);
                has_responses=reshape(has_responses,[rs,1,cs]);
                has_responses=repmat(has_responses,1,size(ep,2),1);

                % Now turn those epochs without a response to NaN
                ep(~has_responses)=NaN;

            end

            % Exclude rejects.
            if exclude_reject
                is_rejected=eprecorder_epoch_qa.isEffectivelyRejected( ...
                    EPR,chan_nums,epoch_nums);
               
                
                % Convert is_rejected to be the same size as the ep data.
                [rs,cs]=size(is_rejected);
                is_rejected=reshape(is_rejected,[rs,1,cs]);
                is_rejected=repmat(is_rejected,1,size(ep,2),1);

                % Now turn the rejected epochs into NaN
                ep(is_rejected)=NaN;
            end

            % Output
            ep=mean(ep,3,'omitnan');

            % Plot
            if nargout<1
                t=time_win(1)+eprecorder_sample2time(EPR,1:size(ep,2))*1000;
                tiledlayout(ceil(length(chan_nums)/2),2);
                for n=1:size(ep,1)
                    nexttile;
                    plot(t,ep(n,:))
                    title(sprintf('Channel %g: %s',chan_nums(n),EPR.channelNames{chan_nums(n)}) );
                    ylabel(EPR.channelUnits{chan_nums(n)});
                    xlabel('ms');
                end
            end
        end

        function [results, summary]=autoDectectionMetrics(EPR,chan_nums,epoch_nums,fixed_time_tolerance,stimulus_nums)
            % Compare presence, start/onset and stop values detected against the
            % labelled values. The result is collapsed accross all data i.e
            % epochs, and stimulus numbers.
            %
            % NOTE: You need to label the data and the run your auto
            % detection method of choice before interpreting the results of
            % this method.
            %
            % [INPUT]
            % EPR: EPR data structure.
            % chan_nums []|int|array<int>: The channel number. Default|[]
            %   is all channels.
            % epoch_nums []|int|array<int>: The epoch numbers. Default|[] 
            %   is all trials. 
            % fixed_time_tolerance []|double: A fixed tolerance for time
            %   detection in milliseconds. Set to [] to use a  predefined 
            %   number stardard deviation derived from labelled data per
            %   channel.  An example is 10.
            % stimulus_nums int: The stimulus numbers. The default is all 
            %   stimuli.
            % [OUTPUT]
            % results struct: with the following fields:_____________
            %   presence_acc double: Accuracy for presence of response
            %   presence_confusion cell<double>: Confusion matrix for
            %       presence. flattened across stimulus numbers. Cell shape:
            %       1xchan_nums. 
            %   onset_acc double: Accuracy for onset/start of response
            %   stop_acc double: Accuracy for stop of response
            %   n_items int: Total number of items i.e waves with and with
            %       valid EP. Shape: 1xchan_nums.
            %   n_label_presense int: Total number of items with valid EP as
            %       per labelling. This the number of items considered for 
            %       onset and stop accuracies/rms, and the items in the
            %       returned table.Shape: 1xchan_nums.
            %   onset_rmse double: RMSE for detecteding the onset. The unit
            %       is the same as the data in the returned table. Shape: 1xchan_nums.
            %   stop_rmse double: RMSE for detecteding the stop. The unit
            %       is the same as the data in the returned table. Shape: 1xchan_nums.
            %   tbl cell<table<double>>: for each response (a row), the corresponding
            %       labelled and detected onset and stop times(ms). The table is
            %       flattened across stimulus numbers. Cell shape: 1xchan_nums.
            %       Table columns:labelled_onset, detected_onset,labelled_stop,
            %       detected_stop. 
            % summary struct: The same structure as results accept that
            %   infomation is collased across channels such that shape is
            %   1. It empty if chan_nums==1.

            if nargin < 2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end

            if nargin < 3 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end

            if nargin < 4 || isempty(fixed_time_tolerance)
                fixed_time_tolerance=[];
            end

            if nargin < 5 || isempty(stimulus_nums)
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

           
            
            
%DELETE THIS BLOCK OF COMMENTS AND CODE____________________________________
%             % TODO: perform the following computations one channel at a time
%             % in order to use labelled time std per channel to determine
%             % time detection tolerance. Having said that as far as the
%             % labbeled times for all channels are not different by a large
%             % amount, an std of all channel labbeled times should still
%             % provide a good estimate for tolerance. We could also just use
%             % a fixed tolerance value for all channels. For now we will
%             % simply use a fixed heuristic value.
%             fixed_time_tolerance=10;% in milliseconds. Set to empty[] to disable fixed tolerance. @see above note regarding per channel std b4 disabling though.
%__________________________________________________________________________

            % The number of std tolerated for time detection. Ignored if
            % std is not used to determine time detection tolerance.
            n_std_time=3;

            %
            results=[];
            summary=[];

            

            % Lets deal with each channel separately. Dealling with each
            % channel separately allows us to deal with start and stop
            % times that are similar accros epochs.
            if length(chan_nums)>1

                for chan_num=reshape(chan_nums,1,[])
                    res=eprecorder_response.autoDectectionMetrics(EPR,chan_num);

                    % Merge results from each channel together
                    if isempty(results)
                        results=res;
                        summary=res;
                    else
                        fns=fieldnames(results);
                        for m=1:length(fns)
                            fn=fns{m};
                            switch(fn)
                                case {'n_items','n_label_presence'}
                                    results.(fn)=[results.(fn),res.(fn)];
                                    summary.(fn)=summary.(fn)+res.(fn);
                                case 'tbl'
                                    results.(fn){end+1}=res.(fn){1};
                                    summary.(fn){1}=[summary.(fn){1} ;res.(fn){1}];
                                case 'presence_confusion'
                                    results.(fn){end+1}=res.(fn){1};
                                    summary.(fn){1}=summary.(fn){1} + res.(fn){1};
                                otherwise
                                    results.(fn)=[results.(fn),res.(fn)];
                                    summary.(fn)=mean(results.(fn),2,"omitnan");
                            end
                        end
                    end
                end
                

                return;
            end


            %Rejected epochs
            is_rejected_epochs=eprecorder_epoch_qa.isEffectivelyRejected(EPR,chan_nums,epoch_nums);
            is_rejected_epochs=repmat(is_rejected_epochs,1,length(stimulus_nums));

            %% Presence
            label_presence=[];
            detected_presence=[];
            for stimulus_num=reshape(stimulus_nums,1,[])
                label_presence_temp=eprecorder_label.presence(EPR,chan_nums,epoch_nums,stimulus_num);
                label_presence=[label_presence, label_presence_temp];

                detected_presence_temp=eprecorder_response.getAutoPresence(EPR,chan_nums,epoch_nums,stimulus_num);
                
                % Ensure that the detected region overlaps with that of the
                % label___________________________
                overlaps=zeros(size(detected_presence));
                min_overlap=0.1; %Percentage min overlap;
                label_starts=eprecorder_label.getTime(eprecorder_label.RESPONSE_START,EPR,chan_nums,epoch_nums,stimulus_num);
                label_stops=eprecorder_label.getTime(eprecorder_label.RESPONSE_STOP,EPR,chan_nums,epoch_nums,stimulus_num);
                detected_starts=eprecorder_response.getAutoOnsetTime(EPR,chan_nums,epoch_nums,stimulus_num);
                detected_stops=eprecorder_response.getAutoStopTime(EPR,chan_nums,epoch_nums,stimulus_num);
                for r=1:size(label_starts,1)
                    for c=1:size(label_starts,2)
                       overlap=eprecorder_response.lineOverlap(label_starts(r,c),label_stops(r,c),detected_starts(r,c),detected_stops(r,c));
                       overlaps(r,c)=overlap>min_overlap;
                    end
                end
                detected_presence_temp(not(logical(overlaps)))=0;
                %_____________________________________

                detected_presence=[detected_presence, detected_presence_temp];
            end

            %Remove rejected epochs(NOTE: this flattenes the array deu to the logical indexing)
            label_presence=label_presence(not(is_rejected_epochs));
            detected_presence=detected_presence(not(is_rejected_epochs));

            %
            n_items=numel(label_presence);
            results.n_items=n_items;
            results.n_label_presence=numel(find(label_presence));

            
            % Create confusion matrix for presence 
            presence_confusion = confusionmat(label_presence,detected_presence,"Order",[1,0]);

            %presence_acc=numel(find(detected_presence==label_presence))/n_items;
            presence_acc=sum(diag(presence_confusion)) / sum(presence_confusion(:));
            results.presence_acc=presence_acc;
            results.presence_confusion={presence_confusion};



            %% Onset
            label_onset=[];
            detected_onset=[];
            for stimulus_num=reshape(stimulus_nums,1,[])
                label_onset=[label_onset, eprecorder_label.getTime(eprecorder_label.RESPONSE_START,EPR,chan_nums,epoch_nums,stimulus_num)];

                detected_onset=[detected_onset, eprecorder_response.getAutoOnsetTime(EPR,chan_nums,epoch_nums,stimulus_num)];
            end

            %Remove rejected epochs(NOTE: this flattenes the array deu to the logical indexing)
            label_onset=label_onset(not(is_rejected_epochs));
            detected_onset=detected_onset(not(is_rejected_epochs));

            % Remove items that has no reponse as per labelling. 
            label_onset=label_onset(logical(label_presence));%Note that the logical indexing also flattens the array.
            detected_onset=detected_onset(logical(label_presence));
            
            %
            if isempty(fixed_time_tolerance)
                if length(chan_nums)>1
                    % We should not see this warning as we are currently
                    % intercepting above when chan_nums >1
                    warning('Using tolerance derived from std of labelled times from multiple channels. If response times labelled are significantly different across channels, then a fixed time tolerance may be more appriopriate.');
                end
                
                tolerance=n_std_time*std(label_onset);% Tolerance is chosen using a set number of std of all labelled values.
            else
                tolerance=fixed_time_tolerance;
            end
            onset_acc= abs(label_onset - detected_onset) <= tolerance;
            onset_acc=numel(find(onset_acc))/numel(label_onset);
            results.onset_acc=onset_acc;


            %% Stop
            label_stop=[];
            detected_stop=[];
            for stimulus_num=reshape(stimulus_nums,1,[])
                label_stop=[label_stop, eprecorder_label.getTime(eprecorder_label.RESPONSE_STOP,EPR,chan_nums,epoch_nums,stimulus_num)];
                detected_stop=[detected_stop, eprecorder_response.getAutoStopTime(EPR,chan_nums,epoch_nums,stimulus_num)];
            end

            %Remove rejected epochs(NOTE: this flattenes the array deu to the logical indexing)
            label_stop=label_stop(not(is_rejected_epochs));
            detected_stop=detected_stop(not(is_rejected_epochs));

            % Remove items that has no reponse as per labelling. 
            label_stop=label_stop(logical(label_presence));%Note that the logical indexing also flattens the array.
            detected_stop=detected_stop(logical(label_presence));
            
            if isempty(fixed_time_tolerance)
                if length(chan_nums)>1
                    % We should not see this warning as we are currently
                    % intercepting above when chan_nums >1
                    warning('Using tolerance derived from std of labelled times from multiple channels. If response times labelled are significantly different across channels, then a fixed time tolerance may be more appriopriate.');
                end
                tolerance=n_std_time*std(label_stop);% Tolerance is chosen using a set number of std of all labelled values.
            else
                tolerance=fixed_time_tolerance;
            end
            stop_acc= abs(label_stop - detected_stop) <= tolerance;
            stop_acc=numel(find(stop_acc))/numel(label_stop);
            results.stop_acc=stop_acc;

            %% RMSE
            results.onset_rmse=eprecorder_util.rmse(detected_onset,label_onset);
            results.stop_rmse=eprecorder_util.rmse(detected_stop,label_stop);

            %% Table
            % The following are row vectors when length(chan_nums)==1, so
            % ensure that we have colums vectors for the table. 
            label_onset=reshape(label_onset,[],1);
            detected_onset=reshape(detected_onset,[],1);
            label_stop=reshape(label_stop,[],1);
            detected_stop=reshape(detected_stop,[],1);

            %
            data=[label_onset,detected_onset,label_stop,detected_stop];
            column_names = {'labelled_onset', 'detected_onset', 'labelled_stop', 'detected_stop'};
            tbl = array2table(data, 'VariableNames', column_names);
            results.tbl={tbl};
            
        end
        
        
        function overlapPercentage = lineOverlap(start1, stop1, start2, stop2)
            % Determine how much two line overlap.
            %
            % [INPUT]
            % start1, stop1 double: Start/stop of line 1
            % start2, stop2 double: Start/stop of line 2
            % [OUTPUT]
            % overlapPercentage double: Proportion of overlap in the range
            %   [0,1]. 
            %

            % Check if there is any overlap
            if stop1 < start2 || stop2 < start1
                overlapPercentage = 0;  % No overlap
                return;
            end
            
            % Find the overlapping segment
            overlapStart = max(start1, start2);
            overlapStop = min(stop1, stop2);
            
            % Calculate lengths of the lines and the overlapping segment
            lengthLine1 = stop1 - start1;
            lengthLine2 = stop2 - start2;
            lengthOverlap = overlapStop - overlapStart;
            
            % Calculate percentage overlap
            overlapPercentage = (lengthOverlap / min(lengthLine1, lengthLine2));
        end

        function EPR1=merge(EPR1,EPR2)
            % Merge the response features of the given two datasets.
            % [INPUT]
            % EPR1: The target dataset, and source 1.
            % EPR2: The dataset source 2.
            % [OUTPUT]
            % EPR1: The First input dataset with updated response feature.
        
            %  Note time_win_start and time_win_end will use what is available in
            %  the target dataset
            response_vars={'auto_presence','manual_presence','auto_onset_time','auto_stop_time','manual_onset_time','manual_stop_time','peak2peak','area'};
            for rv=response_vars
                fd=rv{1};
                for k=1:length(EPR1.epochs.features.response.(fd))
                    EPR1.epochs.features.response.(fd){k}=[EPR1.epochs.features.response.(fd){k} , EPR2.epochs.features.response.(fd){k} ];
                end
            end
        end
    end

    
    
end

