classdef eprecorder_label
    % Label data
    %   Data label for feature extraction.
    properties(Constant)

        % Label names
        PRE_STIMULUS_START= 'pre_stimulus_start';
        PRE_STIMULUS_STOP= 'pre_stimulus_stop';
        STIMULUS_ARTEFACT_START= 'stimulus_artefact_start';
        STIMULUS_ARTEFACT_STOP= 'stimulus_artefact_stop';
        PRE_RESPONSE_BACKGROUND_START= 'pre_response_background_start';
        PRE_RESPONSE_BACKGROUND_STOP= 'pre_response_background_stop';
        RESPONSE_START= 'response_start';
        RESPONSE_STOP= 'response_stop';
        POST_RESPONSE_BACKGROUND_START= 'post_response_background_start';
        POST_RESPONSE_BACKGROUND_STOP= 'post_response_background_stop';
    

    end
    methods(Access=public)
        function this = eprecorder_label(this)
            % Construct an instance of this class
            
        end
    end
    
    methods(Static)
        function EPR=addFields(EPR,force)
            % Add data label fields to the EPR data structure. An
            % error will occur if the the fields already exists unless
            % input 'force'==true.
            % [INPUT]
            % EPR: Epoched main EPR structure.
            % force boolean: When true the fields will be added even if it 
            %   already exists. The default is false.
            % [OUTPUT]
            % EPR: The input structure with features.label field added.
            %      Each added field of label is a cell of size=1 x 1+len(find(EPR.ISI)). 
            %      The first entry corresponds to the primary trigger and 
            %      the other correspond to non-zero EPR.ISI entries:---------------      
            %       features.label.pre_stimulus_start cell: @see EPR above. Each entry is:  An array where an entry indicates the
            %           onset time(ms) of pre stimulus data.
            %           This time is relative to the time t=0, i.e trigger.
            %       features.label.pre_stimulus_stop cell: The stop
            %           equivalent of the ***start.
            %       features.label.stimulus_artefact_start cell:..as above.            
            %       features.label.stimulus_artefact_stop cell:..as above.
            %       features.label.pre_response_background_start cell:..as above.
            %       features.label.pre_response_background_stop cell:..as above.
            %       features.label.response_start cell:..as above.
            %       features.label.response_stop cell:..as above.
            %       features.label.post_response_background_start cell:..as above.
            %       features.label.post_response_background_stop cell:..as above.
            %    

            if nargin<2
                force=false;
            end
            if ~eprecorder_has_epoch(EPR)
                error('Epoched data is required in order to add response feature');
            end
            
            if(~force && isfield(EPR.epochs,'features'))
                if(isfield(EPR.epochs.features,'label'))
                    error('Label fields already exists');
                end
            end

            %
            n_epochs=size(EPR.data,3);
            n_channels=size(EPR.data,1);

            % Base times in milliseconds
            unit_time=eprecorder_sample2time(EPR,1);
            label.(eprecorder_label.PRE_STIMULUS_START)=-10*ones(n_channels,n_epochs);
            label.(eprecorder_label.PRE_STIMULUS_STOP)=-2*ones(n_channels,n_epochs);

            label.(eprecorder_label.STIMULUS_ARTEFACT_START)=8*ones(n_channels,n_epochs);
            label.(eprecorder_label.STIMULUS_ARTEFACT_STOP)=20*ones(n_channels,n_epochs);

            label.(eprecorder_label.PRE_RESPONSE_BACKGROUND_START)=(7+unit_time)*ones(n_channels,n_epochs);
            label.(eprecorder_label.PRE_RESPONSE_BACKGROUND_STOP)=8*ones(n_channels,n_epochs);

            label.(eprecorder_label.RESPONSE_START)=(8+unit_time)*ones(n_channels,n_epochs);
            label.(eprecorder_label.RESPONSE_STOP)=25*ones(n_channels,n_epochs);

            label.(eprecorder_label.POST_RESPONSE_BACKGROUND_START)=(25+unit_time)*ones(n_channels,n_epochs);
            label.(eprecorder_label.POST_RESPONSE_BACKGROUND_STOP)=30*ones(n_channels,n_epochs);

            
            
            
            
            % Now make the entries for primary and secondary stimuli
            [~,isi]=eprecorder_stimulus_numbers(EPR);
            fields=fieldnames(label);
            for n=1:length(fields)
                for m=1:length(isi)
                    EPR.epochs.features.label.(fields{n}){m}=label.(fields{n}) + isi(m); % Add the isi to offset the time.
                end
            end
            
            
        end
        function [labels,colors]= getFields()
            % Return all fields (aka label) names.
            % [OUTPUT]
            % labels cell<cell<string>>: Field/labels names. Each entry is
            %   a two element cell respectively contaning that name for the
            %   start and stop label.
            % colors cell<array<double>>: Each entry is a 4-ele color array
            %   for the corresponding label.



%             labels={{'pre_stimulus_start', 'pre_stimulus_stop'}                        
%                         {'stimulus_artefact_start', 'stimulus_artefact_stop'}                        
%                         {'pre_response_background_start', 'pre_response_background_stop'}                        
%                         {'response_start', 'response_stop'}                        
%                         {'post_response_background_start', 'post_response_background_stop'}                        
%                      };
            labels={{eprecorder_label.PRE_STIMULUS_START, eprecorder_label.PRE_STIMULUS_STOP}
                {eprecorder_label.STIMULUS_ARTEFACT_START, eprecorder_label.STIMULUS_ARTEFACT_STOP}
                {eprecorder_label.PRE_RESPONSE_BACKGROUND_START, eprecorder_label.PRE_RESPONSE_BACKGROUND_STOP}
                {eprecorder_label.RESPONSE_START, eprecorder_label.RESPONSE_STOP}
                {eprecorder_label.POST_RESPONSE_BACKGROUND_START, eprecorder_label.POST_RESPONSE_BACKGROUND_STOP}
            };
            colors={[1,0,1,0.3],[1,0,0,0.7],[0,0,1,0.6],[0,1,0,0.5],[1,1,0,0.4]};
        end
        function EPR=setTime(field_name,EPR,chan_num,epoch_num,t,stimulus_num)
            % Set the 'field_name' time
            % [INPUT]
            % field_name string: Name of the field to set. See
            %   eprecorder_label.addFields() for valid label field names.
            % EPR: The EPR data structure.
            % chan_num int: The channel number.
            % epoch_num int: The epoch number.
            % t double:The time (ms) relative to the time
            %   locking event at t=0.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % EPR: The input EPR with the updated label time.
            if nargin < 6
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            % Check fields are set
            % TODO: Remove this when fields are set in during epoching, like response fields
            if ~isfield(EPR.epochs.features,'label')
                EPR=eprecorder_label.addFields(EPR);
            end

            % Validation
            fields=fieldnames(EPR.epochs.features.label);
            if ~any(strcmp(fields,field_name))
                error('Unknown fieldname %s',field_name)
            end

            %
            EPR.epochs.features.label.(field_name){stimulus_num}(chan_num,epoch_num)=t;
            %EPR.epochs.features.label.(field_name){stimulus_num}(1,9:25)=t;
            
        end
        function t=getTime(field_name,EPR,chan_nums,epoch_nums,stimulus_num)
            % Get the 'field_name' time
            % [INPUT]
            % field_name string: Name of the field to read. See
            %   eprecorder_label.addFields() for valid label field names.
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % t double|array<double>: The time (ms) relative to the time
            %   locking event at t=0. It is a row vector for all epochs if
            %   epoch_num is not given.
            
            if nargin<3 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin<4
                epoch_nums=[];
            end

            if nargin < 5
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end

            % Check fields are set
            % TODO: Remove this when fields are set during epoching, like response fields
            if ~isfield(EPR.epochs.features,'label')
                EPR=eprecorder_label.addFields(EPR);
            end

            % Validation
            fields=fieldnames(EPR.epochs.features.label);
            if ~any(strcmp(fields,field_name))
                error('Unknown fieldname %s',field_name)
            end

            %
            t=EPR.epochs.features.label.(field_name){stimulus_num}(chan_nums,:);
            if not(isempty(epoch_nums))
                t=t(:,epoch_nums);
            end
        end
        function EPR=guessTimes(EPR,chan_nums,epoch_nums,stimulus_nums)
            % Guess label times.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array|[]: The channel numbers. The default is
            %   all channels.
            % epoch_nums int|array|[]: The epoch numbers. The default is
            %   all epochs.
            % stimulus_nums int|array|[]: The stimulus numbers. The default 
            %   is the number for all stimuli.
            % [OUTPUT]
            % EPR struct:The input EPR with the label times.
            if nargin <2 || isempty(chan_nums)
                chan_nums=1:length(EPR.channelNames);
            end
            if nargin <3 || isempty(epoch_nums)
                epoch_nums=1:size(EPR.data,3);
            end
            if nargin<4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
            end

            EPR=eprecorder_label.copyTimesFromResponse(EPR,chan_nums,epoch_nums,stimulus_nums);

            
%             labels={
%                 % start,                stop,              
%                 {'pre_stimulus_start', 'pre_stimulus_stop'}                        
%                 {'stimulus_artefact_start', 'stimulus_artefact_stop'}                        
%                 {'pre_response_background_start', 'pre_response_background_stop'}                        
%                 {'response_start', 'response_stop'}                        
%                 {'post_response_background_start', 'post_response_background_stop'}                        
%              };
            
            [labels,~]=eprecorder_label.getFields();
            
            for stimulus_num=reshape(stimulus_nums,1,[])

                %
                for chan=reshape(chan_nums,1,[])
                    for epoch=reshape(epoch_nums,1,[])
                        
                        for label_n=1:length(labels)
                            if any(strcmp(labels{label_n}{1},{eprecorder_label.RESPONSE_START,}))
                                continue;
                            end

                            present=eprecorder_response.has(EPR,chan,epoch,stimulus_num);
                            t2=eprecorder_label.getTime(labels{label_n}{2},EPR,chan,epoch,stimulus_num);
                            if present && strcmp(labels{label_n}{1},eprecorder_label.POST_RESPONSE_BACKGROUND_START)
                                
                                response_stop_time = eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
                                t1 = response_stop_time + eprecorder_sample2time(EPR,2)*1000;
                                if ~isnan(t1) && (isnan(t2) || t2<t1)
                                    t2=t1+ eprecorder_sample2time(EPR,2)*1000;
                                    
                                    
                                    % Try to match the width of response and background
                                    % OPEN if needed
                                    %response_start_time = eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
                                    %if ~isnan(response_start_time)
                                    %    response_width = response_stop_time - response_start_time;
                                    %    t2 = t1 + response_width;
                                    %end
                                end

                                % Ensure the width is not too small
                                min_width=5; % min with in ms.
                                if (t2-t1) < min_width
                                    t2=t1+min_width;
                                end
                                
                                % Ensure the window is within data
                                if t2 > EPR.times(end)
                                    t2=EPR.times(end);
                                end

                            else
                                t1=eprecorder_label.getTime(labels{label_n}{1},EPR,chan,epoch,stimulus_num);
                                if ~isnan(t1)
                                    % Make the label times small but not with a
                                    % tiny separation between start ans top.
                                    t2 = t1 + eprecorder_sample2time(EPR,2)*1000;% Note that this is equivalent to adding 1/Fs *1000.
                                end
                            end
                            EPR=eprecorder_label.setTime(labels{label_n}{1},EPR,chan,epoch,t1,stimulus_num);
                            EPR=eprecorder_label.setTime(labels{label_n}{2},EPR,chan,epoch,t2,stimulus_num);
                        end
                    end
                end
            end
            
        end
        
%         function matchBackgroundToResponseTimeWidth()
%             % Match the time width of baseline data to that response data.
%             % 
%             response_start_time = eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
%             response_stop_time = eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
%             response_width = response_stop_time - response_start_time;
% 
%             t2=eprecorder_label.getTime(labels{label_n}{2},EPR,chan,epoch,stimulus_num);
%             % Try to match the width of response and background
%             if ~isnan(response_start_time)
%                 response_width = response_stop_time - response_start_time;
%                 t2 = t1 + response_width;
%             end
%         end

        function EPR=copyTimesFromResponse(EPR,chan_nums,epoch_nums,stimulus_nums)
            % Import label times from EPR.epochs.features.response. Only
            % response start and stop labels are affected.
            % [INPUT]
            % EPR: The EPR data structure.
            % chan_nums int|array|[]: The channel numbers. The default is
            %   all channels.
            % epoch_nums int|array|[]: The epoch numbers. The default is
            %   all epochs.
            % stimulus_nums int|array|[]: The stimulus numbers. The default 
            %   is the number for all stimuli.
            % [OUTPUT]
            % EPR struct:The input EPR with the label times.
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
                        present=eprecorder_response.has(EPR,chan,epoch,stimulus_num);
                        onset_time=eprecorder_response.getEffectiveOnsetTime(EPR,chan,epoch,stimulus_num);
                        if present
                            stop_time=eprecorder_response.getEffectiveStopTime(EPR,chan,epoch,stimulus_num);
                        else
                            stop_time=onset_time + eprecorder_sample2time(EPR,2)*1000;
                        end
                        
                        EPR=eprecorder_label.setTime(eprecorder_label.RESPONSE_START,EPR,chan,epoch,onset_time,stimulus_num);
                        EPR=eprecorder_label.setTime(eprecorder_label.RESPONSE_STOP,EPR,chan,epoch,stop_time,stimulus_num);
                    end
                end
            end

        end
        function has_response=presence(EPR,chan_nums,epoch_nums,stimulus_num)
            % Check for the presence of response according to the
            % labelling.
            %
            % EPR: The EPR data structure.
            % chan_nums []|array<int>|int: The channel number.
            % epoch_nums []|array<int>|int: The epoch number.
            % stimulus_num int: The stimulus number. The default is the 
            %   number for primary stimulus.
            % [OUTPUT]
            % has_responses boolean|array<boolean>: True where an epoch/s
            %   has EP response. Dimension is [nchan_nums x nepoch_nums]. 

            if nargin<2 
                chan_nums=[];
            end
            if nargin<3
                epoch_nums=[];
            end

            if nargin < 4
                stimulus_nums=eprecorder_stimulus_numbers(EPR);
                stimulus_num=stimulus_nums(1);
            end
            
            label_response_start=eprecorder_label.getTime(eprecorder_label.RESPONSE_START,EPR,chan_nums,epoch_nums,stimulus_num);
            label_response_stop=eprecorder_label.getTime(eprecorder_label.RESPONSE_STOP,EPR,chan_nums,epoch_nums,stimulus_num);
            
            % if the response windows is collapsed then there is no
            % response
            tolerance_ms=eprecorder_label.collapsedWindowMaxWidth(EPR)*1000;%window tolerance in ms. A response window smaller than this is considered to have been collapsed, which implies absence of EP as per labelling.
            has_response=(label_response_stop-label_response_start) > tolerance_ms;
        end
        function [data,targets]=export(EPR,filename,exclude_labels,minSegmentSampleLen)
            % Export the labelled data.
            % [INPUT]
            % EPR struct: EPR data structure.
            % filename string: The csv filename (excluding '.csv') to save the data as.
            %   If a file with the name name already exists a warning is given. Default
            %   none. 
            % exclude_labels cell<string>: The list of labels to exclude
            %   alltogether from the export. See
            %   eprecorder_label.addfields() for valid labels. To exclude a
            %   label, enter either the start or the stop label name. E.g
            %   to exclude pre_stimulus label, enter either
            %   {'pre_stimulus_start'} or {'pre_stimulus_stop'}.
            % minSegmentSampleLen int: The minimum number of samples within
            %   any segment of a lable for the corresponding data to be 
            %   added to the exported data.
            % [OUTPUTS]
            % data array<double>: Concatenated data of all
            %   channels, epochs and stimulus numbers. Rejected epochs and epoch
            %   Dim is column.
            % targets: One hot encoding for data. First column is for background noise;
            %   second column is stimulus artefact and the third column is
            %   for an entire EP wave. Dim is len(data) x num_classes.  
            if nargin<2
                filename=[];
            end

            if nargin<3
                exclude_labels={};
            end

            if nargin<4
                minSegmentSampleLen=eprecorder_time2sample(EPR,eprecorder_label.collapsedWindowMaxWidth(EPR));
            end

%             labels={
%                 % start,                stop,              class
%                 {'pre_stimulus_start', 'pre_stimulus_stop',[1,0,0]}                        
%                 {'stimulus_artefact_start', 'stimulus_artefact_stop',[0,1,0]}                        
%                 {'pre_response_background_start', 'pre_response_background_stop',[1,0,0]}                        
%                 {'response_start', 'response_stop',[0,0,1]}                        
%                 {'post_response_background_start', 'post_response_background_stop',[1,0,0]}                        
%              };

            labels = {
                % start,                          stop,                            class
                {eprecorder_label.PRE_STIMULUS_START, eprecorder_label.PRE_STIMULUS_STOP, [1, 0, 0]}
                {eprecorder_label.STIMULUS_ARTEFACT_START, eprecorder_label.STIMULUS_ARTEFACT_STOP, [0, 1, 0]}
                {eprecorder_label.PRE_RESPONSE_BACKGROUND_START, eprecorder_label.PRE_RESPONSE_BACKGROUND_STOP, [1, 0, 0]}
                {eprecorder_label.RESPONSE_START, eprecorder_label.RESPONSE_STOP, [0, 0, 1]}
                {eprecorder_label.POST_RESPONSE_BACKGROUND_START, eprecorder_label.POST_RESPONSE_BACKGROUND_STOP, [1, 0, 0]}
            };



            num_classes=3;
            data=[];
            targets=[];
            units={};
            epoch_nums=eprecorder_epochs_for(EPR);
            stimulus_nums=eprecorder_stimulus_numbers(EPR);
            for chan_num=1:length(EPR.channelNames)
                for epoch_num=epoch_nums
                    for stimulus_num=stimulus_nums
                        if ~eprecorder_epoch_qa.isEffectivelyRejected(EPR,chan_num,epoch_num)
                            
                            for label_n=1:length(labels)

                                if any(strcmp(exclude_labels,labels{label_n}{1})) || any(strcmp(exclude_labels,labels{label_n}{2}))
                                    continue;
                                end

                                data_time_win=[0,0];
                                data_time_win(1)=eprecorder_label.getTime(labels{label_n}{1},EPR,chan_num,epoch_num,stimulus_num);
                                data_time_win(2)=eprecorder_label.getTime(labels{label_n}{2},EPR,chan_num,epoch_num,stimulus_num); 
                                data_time_win=floor(data_time_win);
                                if(~eprecorder_is_valid_data_time_window(EPR,data_time_win))
                                    warning('Skipping invalid data time window ([%g,%g],[%s,%s]) for chan:%i, epoch:%i, stimulus num:%i\n',data_time_win(1),data_time_win(2),labels{label_n}{1},labels{label_n}{2},chan_num,epoch_num,stimulus_num);
                                    continue
                                end

                                data_temp=eprecorder_get_epoch_data(EPR,chan_num,epoch_num,data_time_win);
                                data_temp=data_temp';

                                if size(data_temp,1) < minSegmentSampleLen
                                    continue;
                                end

                                targets_temp=repmat(labels{label_n}{3},size(data_temp,1),1);
                            
                         
                                % Merge data
                                data=[data;data_temp];
                                targets=[targets;targets_temp];
            
                                units{end+1}=EPR.channelUnits{chan_num};
                                units=unique(units);
                            end
            
                        end
                    end
                  
                end
            end
            
            % Save sata
            if ~isempty(filename)
                filename=[filename,'.csv'];
                if ~exist(filename,"file")
                    answer=questdlg('File already exists; overwrit it?','Export labels','Yes','No');
                    switch(answer)
                        case 'Yes'
                            % do nothing
                        otherwise
                            error([filename ' already exists']);
                    end
                end


                writematrix([data,targets],filename);
                T = array2table([data,targets]);
                T.Properties.VariableNames(1:1+num_classes) = {['potential(', strjoin(units,'/'),')'],'background label','stimulation noise label','evoked potential label'};
                writetable(T,filename);

            end

            % visualise the data: plot(data),hold,plot(targets(:,1:3))
        end

        function tw=collapsedWindowMaxWidth(EPR)
            % return the maximum width of a window considered to be
            % collased. Any labele window greater than this width is not
            % collased.
            % [INPUT]
            % EPR: EPR data structure.
            % [OUTPUT]
            % tw double: Max collapsed window time in seconds.
            tw=2/1000;
            
            %return %TODO remove this return to consider other samplerates.

            % If the above time is less than about 2 samples(i.e when Fs is too small) we should return a
            % time that is a least 2 samples.
            if tw*EPR.Fs <2 
               tw= (2/EPR.Fs);
            end

            % If the above time leads to many samples, i.e when  Fs is too
            % high we will return time equivalent of 8(arbitrary choice)
            % samples.
            if tw*EPR.Fs > 8 
               tw= (8/EPR.Fs);
            end

        end
    end
    
end

