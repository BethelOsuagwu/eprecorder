classdef eprecorder_response_change_point < handle
    % Find the point where response change/appears within multiple dataset.
    %   Essentially determines the change points of recruitment curves.
    %   from multiple datasets. Crusially, it assumes that recruitment
    %   curve is increasing wrt to the stimulus code close to the first
    %   change point which is of interest.



    properties
        % The method to be use to detect changes. The options are:
        %   findchangepts: use Matlab's findchangepts function.
        changeDetectionMethod='findchangepts';
        
        % The parameters for change detection mehtod as key value pairs.
        changeDetectionMethodKeyValuePairParams={"Statistic","mean","MaxNumChanges",1000};
        
        %
        feature='peak2peak';% The features {peak2peak,area,onset_time,time_width}
        excludeNoResponse=false;% If true only epochs with response will be considered.
        excludeReject=true;% When true rejected epochs are not considered.
        chanNums=[]; % Channel numbers
        stimulusCodes=[];% double|array<double>: The event code/s of interest.
        stimulusNum=1; % The epoch stimulus number to cosider. Default is the primary stimulus.
        stimulusCodeLabels=num2cell(0.2:0.1:1.6);% Labels for corresponding stimulus code. Same number of elements as the stimulusCodes.
        datasetLabels={1:5};% Each entry is a label for a dataset
        plotYLabel='Datasets';  
        stimulusRestingMotorThreshod=1;% The resting motor stimulus threshold. Should be left as 1 unless you want to print absolute stimulation intensities but the stimulusCodes are fractional percentages of RMT and stimulusCodeLabels are not given.
        plotXLabel='Stimulus code';
        plotTitle='Response changes';
        colorBarLimits=[]; % The limits for the color bar. Default is the combined [min,max] of plotted data.
        
    end
    
    methods
        function this = eprecorder_response_change_point(chan_nums,stimulus_codes,feature,exclude_no_response,exclude_reject)
            %Constructs an instance of this class.
            % chan_nums int|array<int>: Channel numbers.
            % stimulus_codes double|array<double>: The event code/s of
            %   interest.
            % feature string: The features {peak2peak, area,
            %   onset_time,time_width}. The default is peak2peak 
            % exclude_no_response boolean: If true only epochs with response
            %   will be considered. The default is false.
            % exclude_reject boolean: If true only epochs not rejected
            %   will be considered. 
            
            
            if nargin>=1
                this.chanNums=chan_nums;
            end
            if nargin>=2
                this.stimulusCodes=stimulus_codes;
            end
            if nargin>=3
                this.feature=feature;
            end
            if nargin>=4
                this.excludeNoResponse=exclude_no_response;
            end
            if nargin>=5
                this.excludeReject=exclude_reject;
            end
        end
        function [change_point,change_point_dataset_idx,feature_values]=get(this,ALLEPR)
            % Return the change points for the given set of datasets. The
            % channels are combined into one.
            %
            % [INPUT]
            % AllEPR cell: 1D cell array of EPR structure.  
            % [OUTPUT]
            % change_point int|NaN: The index of the stimulus code
            %   corresponding the first change in response feature value.
            %   NaN indicates that no change point was found.
            % change_point_dataset_idx int|NaN: The index of ALLEPR. NaN
            %   indicates that no change point was found.
            %   corresponding to the dataset with the detected change.
            % feature_values array<double>: A 2D array of values of the
            %   specified feature. The values of all channels are combined.
            %   Dimension is [len(ALLEPR) x len(this.stimulusCodes)]

            % Get the features
            allEPR_feature_values=this.getFeatureValues(ALLEPR);
            
            % Re-arrange the feature values to a 3D array such that each
            % frame is [len(ALLEPR) x len(this.stimulusCodes)]. So the
            % overal dim is [len(ALLEPR) x len(this.stimulusCodes) x len(this.chanNums)]
            chan_feature_values=zeros( ...
                length(allEPR_feature_values), ...
                length(this.stimulusCodes), ...
                length(this.chanNums) ...
                );
            for n=1:length(this.chanNums)
                for m=1:length(allEPR_feature_values)
                    chan_feature_values(m,:,n)=allEPR_feature_values{m}(n,:);
                end
            end
            
            % Remove nans
            chan_feature_values(isnan(chan_feature_values))=0;
            

            % Finally find change points of the max channels for each
            % EPR dataset. i.e We combine the channels such that for each
            % response feature time point, we use the value from the
            % channel that has the highest response for that time point. 
            feature_values=max(chan_feature_values,[],3);

            change_points=zeros(1,size(feature_values,1));
            %max_feature_values=max_feature_values+rand(size(max_feature_values))*2;
            for n=1:size(feature_values,1)

                % Detect the change
                temp_change_points=this.detectChanges(feature_values(n,:));

                % Choose only the first change point
                min_cp=min([temp_change_points , nan]);
                change_points(n)=min_cp;
            end
            [change_point,change_point_dataset_idx]=min(change_points);
            change_point_dataset_idx(isnan(change_point))=nan;
        end
        function [change_points,change_point_dataset_idxs,chan_feature_values]=getSeparate(this,ALLEPR)
            % Return the per channel change points for the given set of
            % datasets. 
            %
            % [INPUT]switch
            % AllEPR cell: 1D cell array of EPR structure.  
            % [OUTPUT]
            % change_points array<int|NaN>: The indexes of the stimulus code
            %   corresponding the first change in response feature value.
            %   Each entry corresponds to a channel the channels in given
            %   datasets in order. NaN indicates that no change point was
            %   found.
            % change_point_dataset_idxs array<int|NaN>: The indexes of ALLEPR
            %   corresponding to the dataset with the detected change for
            %   each channel. NaN indicates that no change point was
            %   found.
            % chan_feature_values array<double>: A 3D array of values of the
            %   specified feature. Each frame is all the data from all
            %   datasets for one channel.
            %   Dimension is [len(ALLEPR) x len(this.stimulusCodes) x len(this.chanNums)]

            % Get the features
            allEPR_feature_values=this.getFeatureValues(ALLEPR);
            
            % Re-arrange the feature values to a 3D array such that each
            % frame is [len(ALLEPR) x len(this.stimulusCodes)]. So the
            % overal dim is [len(ALLEPR) x len(this.stimulusCodes) x len(this.chanNums)]
            chan_feature_values=zeros( ...
                length(allEPR_feature_values), ...
                length(this.stimulusCodes), ...
                length(this.chanNums) ...
                );
            for n=1:length(this.chanNums)
                for m=1:length(allEPR_feature_values)
                    chan_feature_values(m,:,n)=allEPR_feature_values{m}(n,:);
                end
            end
            
            % Remove nans
            chan_feature_values(isnan(chan_feature_values))=0;
         
            chan_change_points=[];
            %% Now for each channels, find change points.
            for m=1:size(chan_feature_values,3)% i.e for each channel
                chan_num=this.chanNums(m);                 
                for n=1:size(chan_feature_values(:,:,m),1)% i.e for each dataset

                    % Detect the change point for the mth channel and nth
                    % dataset of ALLEPR.
                    temp_change_points=this.detectChanges(chan_feature_values(n,:,m));
    
                    % Choose only the first change point for each dataset
                    min_cp=min([temp_change_points , nan]);
                    chan_change_points(m,n)=min_cp;
                end
            end
            [change_points,change_point_dataset_idxs]=min(chan_change_points,[],2);
            change_point_dataset_idxs(isnan(change_points))=nan;
            
        end
        function plot(this,ALLEPR)
            % Plot the response change points for the given set of datasets
            % with all the channels combined into one. 
            %
            % [INPUT]
            % AllEPR cell: 1D cell array of EPR structure.  
            % 

            [cpnt,dataset_idx,max_feature_values]=this.get(ALLEPR);
            f=figure;
            ax=axes(f);

            imagesc(ax,max_feature_values)

            if isempty(this.colorBarLimits) || numel(this.colorBarLimits)~=2
                ctop=min(max_feature_values(:));
                cbottom=max(max_feature_values(:));
                if(cbottom<=ctop)
                    cbottom=1;
                end
            else
                ctop=this.colorBarLimits(1);
                cbottom=this.colorBarLimits(2);
            end
            caxis(ax,"manual");
            caxis(ax,[ctop,cbottom]);

            cb=colorbar(ax);
            cb.Label.String=['Motor Evoked Response (',this.feature,')'];


            if ~isempty(this.datasetLabels)
                set(ax,'YTick',1:size(max_feature_values,1))
                set(ax,'YTickLabel',this.datasetLabels)
            end

            xl=this.stimulusCodeLabels;
            if isempty(xl)
                set(ax,'XTick',1:length(this.stimulusCodes))

                xl=this.stimulusCodes*this.stimulusRestingMotorThreshod;                
            end
            set(ax,'XTickLabel',xl)

            hold(ax,"on")
            % Plot stimulus code
            x=[cpnt,cpnt];            
            y=[0,length(ALLEPR)+1];% Add 1 as we are starting from zero instead of 1.
            plot(ax,x,y,':w',"LineWidth",3,"DisplayName",['Threshold ',this.plotXLabel]);
            ylabel(ax,this.plotYLabel)
            xlabel(ax,this.plotXLabel)
            title(ax,this.plotTitle)

            % Plot dataset
            x=[0,size(max_feature_values,2)+1];  % Add 1 as we are starting from zero instead of 1.          
            y=[dataset_idx,dataset_idx];
            plot(ax,x,y,'--w',"LineWidth",3,"DisplayName",['Threshold ',this.plotYLabel]);
            hold (ax,'off')
            
            legend(ax);
        end

        function plotSeparate(this,ALLEPR)
            % Plot the response change points for the given set of datasets
            % separately for each channel. 
            %
            % [INPUT]
            % AllEPR cell: 1D cell array of EPR structure.  
            % 

            [cpnt,dataset_idx,feature_values]=this.getSeparate(ALLEPR);
            
            f=figure;
            rows=ceil(length(this.chanNums)/2);
            tile=tiledlayout(rows,2,"Parent",f);

            if isempty(this.colorBarLimits) || numel(this.colorBarLimits)~=2
                ctop=min(feature_values(:));
                cbottom=max(feature_values(:));
                if(cbottom<=ctop)
                    cbottom=1;
                end
            else
                ctop=this.colorBarLimits(1);
                cbottom=this.colorBarLimits(2);
            end

            for m=1:size(feature_values,3)
                chan_num=this.chanNums(m);
                ax=nexttile(tile);
                imagesc(ax,feature_values(:,:,m))

                caxis(ax,"manual");
                caxis(ax,[ctop,cbottom]);
                
    
                if ~isempty(this.datasetLabels)
                    set(ax,'YTick',1:size(feature_values(:,:,m),1))
                    set(ax,'YTickLabel',this.datasetLabels)
                end
    
                xl=this.stimulusCodeLabels;
                if isempty(xl)
                    set(ax,'XTick',1:length(this.stimulusCodes))
    
                    xl=this.stimulusCodes*this.stimulusRestingMotorThreshod;                      
                end
                set(ax,'XTickLabel',xl)
    
                hold(ax,"on")
                % Plot stimulus code
                x=[cpnt(m),cpnt(m)];            
                y=[0,length(ALLEPR)+1];% Add 1 as we are starting from zero instead of 1.
                plot(ax,x,y,':w',"LineWidth",3,"DisplayName",['Threshold ',this.plotXLabel]);
                ylabel(ax,this.plotYLabel)
                xlabel(ax,this.plotXLabel)
                chan_name=ALLEPR{1}.channelNames{chan_num};
                title(ax,['Channel ',mat2str(chan_num),' - ',chan_name,': ',this.plotTitle])
    
                % Plot dataset
                x=[0,size(feature_values(:,:,m),2)+1];  % Add 1 as we are starting from zero instead of 1.          
                y=[dataset_idx(m),dataset_idx(m)];
                plot(ax,x,y,'--w',"LineWidth",3,"DisplayName",['Threshold ',this.plotYLabel]);
                hold (ax,'off')
                
                legend(ax);
            end

            % Attach colour bar to the last axis/tile
            cb=colorbar(ax);
            cb.Layout.Tile = 'east';
            cb.Label.String=['Motor Evoked Response (',this.feature,')'];
        end
    end

    methods(Access=private)
        function setDefaultIfMissing(this,ALLEPR)
            % Set the default property values if they are not set.
            % [INPUT]
            % AllEPR cell: 1D cell array of EPR structure.
            if isempty(this.stimulusCodes)
                this.stimulusCodes= unique(eprecorder_get_epoch_stimulus_code(ALLEPR{1}),'sorted');
            end
            if isempty(this.chanNums)
                this.chanNums=1:length(ALLEPR{1}.channelNames);
            end

            %[OPEN to remove values that mismatch]
            % Remove mismatching values
%             if length(this.stimulusCodes) ~=length(this.stimulusCodeLabels)
%                 this.stimulusCodeLabels={};
%             end
% 
%             if length(this.datasetLabels) ~=length(ALLEPR)
%                 this.datasetLabels={};
%             end
        end
        function [feature_avgs] = getFeatureValues(this,ALLEPR)
            % Compute curve for specified event codes recruitment.
            % [INPUT]
            % AllEPR cell: 1D cell array of EPR structure.  
            % [OUTPUT]
            % feature_avgs cell<array<double>>: Feature means. Dimension of
            %   the cell is 1 x len(ALLEPR) and each cell contains an array
            %   of dimension = [len(this.chanNums) x len(stimulus_codes)].

            

            this.setDefaultIfMissing(ALLEPR);

            rec=eprecorder_recruitment_curve(this.chanNums, ...
                this.stimulusCodes, ...
                this.feature, ...
                this.excludeNoResponse, ...
                this.excludeReject);
            rec.stimulusNums=this.stimulusNum;
            
            feature_avgs=cell(1,length(ALLEPR));
            for n=1:length(ALLEPR)
                feature_avgs{n}=rec.get(ALLEPR{n});
            end
            
        end

        function pts=detectChanges(this,feature_values)
            % Find the point of changes in data.
            % [INPUT]
            % feature_values array<double>: A 1D or 2D array of data.
            % [OUTPUT]
            % pts: array<double>: The column indices of the input data
            % where changes were found.  


            switch(this.changeDetectionMethod)
                case 'findchangepts'
                    pts=findchangepts(feature_values, ...
                    this.changeDetectionMethodKeyValuePairParams{:});
                otherwise
                    error(['Unknown change detection method, ',this.changeDetectionMethod]);
            end
        end
        
    end
end

