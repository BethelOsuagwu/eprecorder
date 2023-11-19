classdef eprecorder_tescs
    % TESCS related response processing.

    properties
        % The response feature to be used for identification of stimulation
        % parameters. Any of: {peak2peak,area}. Default: peak2peak.
        responseFeature='peak2peak';

        % Enable/Disable Posterior root-muscle(PRM) reflex  check. If true
        % non-PRM responses will not be considered. 
        PRMCheck=false;

        % FIrst stimulus number for PRM reflex check.
        PRMFirstStimulusNumber=1;

        % Second stimulus number for PRM reflex check. This parameters is
        % irrelevant when the property PRMCheck==false. 
        PRMSecondStimulusNumber=2;

        % When true Posterior root-muscle reflex check will still be
        % performed even if response for the first stimulus is missing.
        % This parameters is irrelevant when the property PRMCheck==false.
        PRMCheckOnMissingFirstResponse=true;

        chanNums=[]; % Channel numbers
        stimulusCodes=[];% double|array<double>: The event code/s of interest.
        datasetLabels={'C3-C4','C4-C5','C5-C6','C6-C7','C7-T1'};
        plotYLabel='Spinous process';
        stimulusCodeLabels=num2cell(0.2:0.1:1.6),
        stimulusRestingMotorThreshod=1;
        plotXLabel='Stimulus intensity (mA)';
        plotTitle='Spinal cord stimulation threshold parameters';
        
        
    end

    properties(Access=protected)
        excludeNoResponse=true;% If true only epochs with response will be considered.
        excludeReject=true;% When true rejected epochs are not considered.
    end
    
    methods
        function this = eprecorder_tescs()
            % Contruct a new instance of the class.
            %

        end
        function datasets=autoPreprocess(this,datasets)
            % Automatically preprocess unprocessed unepoched datasets.
            % [INPUT]
            % datasets cell<struct>: 1-D cell array of unepoched EPR data
            %   structs. 
            % [OUTPUT]
            % datasets cell<struct>: The input data but processed.

            % Preprocessing of the data
            for n=1:length(datasets)
                fprintf('Preprocessing dataset %d/%d (%s)............\n',n,length(datasets),datasets{n}.name);
                datasets{n}=this.preprocess(datasets{n});
            end
        end
        function [result,datasets]=autoPreprocessAndIdentify(this, datasets)
            % Automatically preprocess datasets and then identify
            % stimulation parameters using the preprocessed datasets.
            %
            % [INPUT]
            % datasets cell<struct>: 1-D cell array of unepoched EPR data
            %   structs. 
            %   
            % [OUTPUT]
            % result cell: Stimulation params
            % datasets cell<struct>: The input data but auto processed.

            datasets=this.autoPreprocess(datasets);
            result=this.identify(datasets);
            
        end
        
        function result=identify(this, datasets)
            % Identify stimulation parameters
            %
            % [INPUT]
            % datasets cell<struct>: 1-D cell array of epoched and
            %   preprocessed EPR data structs. 
            %   
            % [OUTPUT]
            % result cell: Stimulation params

            % Dataset labels
            datasetLabels=this.datasetLabels;
            if isempty(this.datasetLabels)
                for n=1:length(datasets)
                    datasetLabels{n}=['Dataset ',mat2str(n)];
                    if isfield(datasets{n},'name')
                        datasetLabels{n}=datasets{n}.name;
                    end
                end
            end

            %% Reject non-PRM reflex.
            if this.PRMCheck
                for n=1:length(datasets)
                    datasets{n}=this.rejectNonPMRResponse(datasets{n});
                end
            end
            

            % Identification of the stimulation parameters
            cp=eprecorder_response_change_point();
            cp.feature=this.responseFeature;
            cp.excludeNoResponse=this.excludeNoResponse;
            cp.excludeReject=this.excludeReject;

            cp.chanNums=this.chanNums;
            cp.stimulusCodes=this.stimulusCodes;
            cp.stimulusNum=this.PRMFirstStimulusNumber;
            cp.datasetLabels=datasetLabels;
            cp.stimulusCodeLabels=this.stimulusCodeLabels;
            cp.stimulusRestingMotorThreshod=this.stimulusRestingMotorThreshod;
            cp.plotYLabel=this.plotYLabel;
            cp.plotXLabel=this.plotXLabel;
            cp.plotTitle=this.plotTitle;

            
            result=cp.getSeparate(datasets);
            cp.plotSeparate(datasets);
            
        end
        
               
    end

    methods(Access=protected)
        function EPR=preprocess(this,EPR)
            % Preprocess the EPR data and return it.
            % [INPUT]
            % EPR struct: EPR data structure.
            % [OUTPUT]
            % EPR struct: The preprocessed input EPR.

            %% Filter
            method='butter';
            forder=2;
            fbandwidth=[20,500];
            fprintf('Filtering: method=%s order=%d, freq=[%d,%d] Hz\n',method,forder,fbandwidth);
            f=eprecorder_filter(method,forder,fbandwidth,EPR.Fs,'bandpass');
            if ~f.validate()
                error('Invalid filter parameters');
            end
            f=f.design();
            for n=1:length(EPR.channelNames)
                % Here we add 1 because channels start from row 2 as the
                % first is time. 
                chan=n+1;
                EPR.data(chan,:)=f.filter(EPR.data(chan,:));
            end

            %% Epoch
            epoch_win=[-100,100];
            disp(['Creating epochs: window=',mat2str(epoch_win),'ms']);
            EPR=eprecorder_epoch(EPR,epoch_win);

            %% Reject bad epochs
            disp('Rejecting bad epochs');
            qa=eprecorder_epoch_qa('mean_amplitude',0.05);
            [EPR,nrejected]=qa.autoReject(EPR);
            fprintf('-- %d epochs rejected\n',nrejected);

            

            %% Set channel response time
            stimulus_nums=[this.PRMFirstStimulusNumber,this.PRMSecondStimulusNumber];
            if this.PRMCheck==false
               stimulus_nums=[this.PRMFirstStimulusNumber];
            end
            for stimulus_num=stimulus_nums
                [time_win_start,time_win_end]=eprecorder_response.defaultTimeWin(EPR,stimulus_num);
                response_win=[time_win_start(1),time_win_end(1)];
                disp(['Stimulus #' mat2str(stimulus_num) ': Automatically define response time window in ms as ',mat2str(response_win) ' for all channels']);
                EPR=eprecorder_response.setTimeWin(EPR,[],response_win,stimulus_num);
            end

            %% Detect the start and the stop times
            disp('Automatic detection of response features')
            response=eprecorder_response('findchangepts');
            EPR=response.autoDetectOnsetTimes(EPR);
            EPR=response.autoDetectStopTimes(EPR);

            % Detect other response features
            EPR=response.detectPresence(EPR,15);
            EPR=response.detectPeak2peaks(EPR);
            EPR=response.detectArea(EPR);


            
        end
        function EPR=rejectNonPMRResponse(this,EPR)
            % Reject non-Posterior root-muscle reflex.
            % [INPUT]
            % EPR struct: EPR data structure.
            % [OUTPUT]
            % EPR struct: The processed input EPR.

            %% 
            
            disp('Reject non-PRM reflex');
            [EPR,nrejected]=eprecorder_tescs.autoRejectNonPRMResponse(EPR, ...
                this.chanNums,this.stimulusCodes,...
                this.responseFeature,this.PRMFirstStimulusNumber, ...
                this.PRMSecondStimulusNumber, ...
                this.PRMCheckOnMissingFirstResponse);
            
            msg='detected as non-PRM reflex but will be included ';
            if this.excludeReject
                msg='detected as non-PRM reflex and will be excluded ';
            end
            fprintf('-- %d epochs %s \n',nrejected,msg);
            
        end
        
    end

    % Static methods
    methods(Access=public,Static)
        function [EPR,nrejected]=autoRejectNonPRMResponse(EPR,chan_nums,stimulus_codes,feature,first_stimulus_num,second_stimulus_num,PRM_check_on_missing_first_response)
            % Reject epochs, for all channels automatically, that is not of
            % reflex nature(Posterior root-muscle, PRM reflex). 
            % 
            % Procedure:
            % For each stimulus code, the average of all the corresponding
            % epoch are computed. Each of the corresponding epochs are
            % rejected if the stimulus if the average for the for the first
            % stimulus(i.e first_stimulus_num) is not greater than that of
            % the second stimulus (i.e second_stimulus_num)
            %   
            %
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums array<int>: Channel indices.
            % stimulus_codes array<int>: Stimulus codes.
            % feature string: The response feature to consider.
            % first_stimulus_num int: The stimulus number of the first
            %   stimulus. The default is the number for the primary
            %   stimulus.
            % second_stimulus_num int: The number for the second stimulus.
            %   The default is the second stimulus.
            % PRM_check_on_missing_first_response bool: When false PRM
            %   check is not performed when the response for the first
            %   stimulus is absent. The default is true.
            % [OUTPUT]
            % EPR struct: The input EPR with updated epoch rejection. 
            % nrejected int: The number of epochs rejected during this run.
            if nargin <4
                feature='peak2peak';
            end
            if nargin<5
                first_stimulus_num=1;
            end
            if nargin <6
                second_stimulus_num=2;
            end

            if nargin < 7
                PRM_check_on_missing_first_response=true;
            end

            nrejected=0;       

            valid_features={'peak2peak','area'};
            tf=strcmp(feature,valid_features);
            if not(any(tf))
                error('Unsupported feature, %s. Supported features are: %s ',feature,valid_features{:});
            end

            stimulus_nums=eprecorder_stimulus_numbers(EPR);
            if length(stimulus_nums)<second_stimulus_num
                error('Second stimulus, %g, cannot be found .',sec);
            end

            % 
            feature(1)=upper(feature(1));
            feature_method=['get',feature];

            input_stimulus_numbers=[first_stimulus_num,second_stimulus_num];


            for chan=reshape(chan_nums,1,[])  
                for stimulus_code=reshape(stimulus_codes,1,[])
                    feature_values=[0,0];
                    for num=1:length(input_stimulus_numbers)
                        feature_values_temp=eprecorder_response.(feature_method)(EPR, ...
                                chan,[],stimulus_code, ...
                                false,false,input_stimulus_numbers(num));
                        feature_values(num)=mean(feature_values_temp,"omitnan");
                    end
                    
                    isPRM=false;
                    if (feature_values(1)>feature_values(2))
                        isPRM=true;
                    end

                    isNotPRM=~isPRM;

                   

                    epochs=eprecorder_epochs_for(EPR,stimulus_code);
                    if PRM_check_on_missing_first_response==false% ie. if the first response is missing, then no PRM check
                        % Explanation:
                        % The result only matters if there is response 'presence'
                        % for the primary stimulus(i.e stimulus number 1). Although
                        % near motor threshold, response can be missing for the
                        % one stimulus while present for the other stimuli but
                        % the effect of this should be negligible over trials.
                        
                        has_primary_presence=[];
                        for m=1:length(epochs)
                            has_primary_presence(m)=eprecorder_response.has(EPR,chan,epochs(m),first_stimulus_num);
                        end
                        isNotPRM=isNotPRM && any(has_primary_presence);
                    end
                    
                    % Save rejection
                    if isNotPRM 
                        % Note that this is a one way process, where
                        % epochs can be rejected but cannot be unrejected. 
                        for m=1:length(epochs)
                            EPR=eprecorder_epoch_qa.setAutoReject(EPR,chan,epochs(m),true);
                            nrejected=nrejected+1;
                        end
                        
                    end
                end
            end 
        end
        function high_freq_current=singlePulseToHighFreqCurrent(single_pulse_current, high_freq_pulse_width, high_freq)
            % Convert a single pulse current to a high frequency current such that their 
            % quantity of electricity is matched.
            %
            %
            % [INPUT]
            % single_pulse_current double: Current in mA.
            % high_freq_pulse_width double: Pulse width of high frequency in micro seconds.
            % high_freq double: Pulse frequency of the high frequency in Hz.
            % [OUTPUT]
            % high_freq_current double: High frequency current in mA.


            % Convert pulse width to seconds
            pw=high_freq_pulse_width/1e6;

            % Calculate period
            period=1/high_freq;

            % Pulswidth cannot be longer than period
            if pw>period
                error('Pulse width cannot be longer than period. Incompatible pulse width and frequency.');
            end 

           
            use_duty_cylce=true;

            if use_duty_cylce
                % Calculate duty cycle
                dc=pw/period;

                % Convert to high frequency current
                high_freq_current=eprecorder_tescs.singlePulseToHighFreqCurrentWithDC(single_pulse_current, dc*100);
            else
                warning('The method singlePulseToHighFreqCurrentWithDC returns a theoretical value. The true value may be significantly different.');
                
                % Convert to high frequency current
                high_freq_current=(period/pw) *single_pulse_current;
            end
            
        end

        function high_freq_current=singlePulseToHighFreqCurrentWithDC(single_pulse_current, high_freq_duty_cycle)
            % Using duty cycle, convert a single pulse current to a high frequency current such that their 
            % quantity of electricity is matched.
            % 
            %
            % [INPUT]
            % single_pulse_current double: Current in mA.
            % high_freq_duty_cycle double: Duty cycle of high frequency in percent (0 < % <= 100).
            % [OUTPUT]
            % high_freq_current double: High frequency current in mA.

            warning('The method singlePulseToHighFreqCurrentWithDC returns a theoretical value. The true value may be significantly different.');

            % Validate duty cycle
            if high_freq_duty_cycle<0 || high_freq_duty_cycle>100
                error('Duty cycle must be between 0 and 100 percent.');
            end

            % Convert duty cycle
            dc=high_freq_duty_cycle/100;

            % Convert to high frequency current
            high_freq_current=(1/dc) *single_pulse_current;
        end

        % function current_b=convertCurrent(current_a, pulse_width_a,freq_a, pulse_width_b,freq_b)
        %     % TODO: DELETE THIS FUNCTION, It Does not work
        %     %
        %     % Convert current from one pulse width and frequency to another. The function
        %     % will convert pulse 'a' to pulse 'b' and return the current for pulse 'b'.
        %     % [INPUT]
        %     % current_a double: Current of pulse 'a' in mA.
        %     % pulse_width_a double: Pulse width of pulse 'a' in micro seconds.
        %     % freq_a double: Pulse frequency of pulse 'a' in Hz.
        %     % pulse_width_b double: Pulse width of pulse 'b' in micro seconds.
        %     % freq_b double: Pulse frequency of pulse 'b' in Hz.
        %     % [OUTPUT]
        %     % current_b double: Current of pulse 'b' in mA.

        %     error('This function does not work. Do not use it.');

        %     % Convert pulse width to seconds
        %     pw_a=pulse_width_a/1e6;
        %     pw_b=pulse_width_b/1e6;

        %     % Calculate period
        %     period_a=1/freq_a;
        %     period_b=1/freq_b;

        %     % Pulswidth cannot be longer than period
        %     if pw_a>period_a
        %         error('Pulse width cannot be longer than period. Incompatible pulse width and frequency for pulse a.');
        %     end 

        %     if pw_b>period_b
        %         error('Pulse width cannot be longer than period. Incompatible pulse width and frequency for pulse b.');
        %     end 

        %     % Convert to high frequency current
        %     current_b=(period_a/pw_a) * (period_b/pw_b) * current_a
        %     current_b=((pw_a*period_b)/(pw_b*period_a)) * current_a;
        % end



    end

    
end

