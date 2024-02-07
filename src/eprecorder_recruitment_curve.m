classdef eprecorder_recruitment_curve < handle
    % EPRECORDER_RECRUITMENT_CURVE Computation of recruitment curve relative to
    % stimulus codes which are assumed to be stimulus intensities.
    %

    
    properties
        feature='peak2peak';% The features {peak2peak,area,onset_time,time_width}
        excludeNoResponse=false;% If true only epochs with response will be considered.
        excludeReject=true;% When true rejected epochs are not considered.
        chanNums=[]; % Channel numbers
        stimulusCodes=[];% double|array<double>: The event code/s of interest.
        stimulusNums=1;% int|array<int>: The stimulus numbers to consider. Default is the primary stimulus.
        normalisationType='none'; % @see possible types in eprecorder_response_norm().types
    end
    
    methods
        function this = eprecorder_recruitment_curve(chan_nums,stimulus_codes,feature,exclude_no_presence,exclude_reject)
            %EPRECORDER_RECRUITMENT Construct an instance of this class.
            % chan_nums int|array<int>: Channel numbers.
            % stimulus_codes double|array<double>: The event code/s of
            %   interest.
            % feature string: The features {peak2peak, area,
            %   onset_time,time_width}. The default is peak2peak 
            % exclude_no_presence boolean: If true only epochs with response
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
                this.excludeNoResponse=exclude_no_presence;
            end
            if nargin>=5
                this.excludeReject=exclude_reject;
            end
        end
        function [feature_avgs,feature_sems] = getAll(this,EPR)
            % Compute curve for specified event codes recruitment for all
            % stated stimulus numbers in the object.
            % [INPUT]
            % EPR struct: EPR structure.
            % [OUTPUT]
            % feature_avgs array<double>: Feature means. Dimension is
            %   [len(this.chanNums) x len(stimulus_codes), len(this.stimulusNums].
            % feature_sems array<double>:Standard error of the mean
            %   corresponding to the feature means. With the same size as the
            %   output, feature means.
            feature_avgs=zeros(length(this.chanNums),length(this.stimulusCodes),length(this.stimulusNums));
            feature_sems=feature_avgs;
            for n=1:length(this.stimulusNums)
                [feature_avgs(:,:,n),feature_sems(:,:,n)]=this.get(EPR,this.stimulusNums(n));
            end
        end
        function [feature_avgs,feature_sems] = get(this,EPR,stimulus_num)
            % Compute curve for specified event codes recruitment for a simgle stimulus code.
            % [INPUT]
            % EPR struct: EPR structure.  
            % stimulus_num int: Stimulus number. The default is the first
            %   stimulus_num set in the current object.
            % [OUTPUT]
            % feature_avgs array<double>: Feature means. Dimension is
            %   [len(this.chanNums) x len(stimulus_codes)].
            % feature_sems array<double>:Standard error of the mean
            %   corresponding to the feature means. With the same size as the
            %   output, feature means. 
            if nargin<3
                stimulus_num=this.stimulusNums(1);
            end
            this.setDefaultIfMissing(EPR);

            feature_avgs=zeros(length(this.chanNums),length(this.stimulusCodes));
            feature_sems=feature_avgs;
            for n=1:length(this.chanNums)
                [avgs,sems]=this.forOneChannel(EPR,this.chanNums(n),this.stimulusCodes,stimulus_num);  
                feature_avgs(n,:)=avgs;
                feature_sems(n,:)=sems;
            end
        end
        function plot(this,EPR)
            % Plot recruitment curve.
            % [INPUT]
            % EPR: EPR structure. 
            
            this.setDefaultIfMissing(EPR);

            [avgs,sems]=this.getAll(EPR);
            tiledlayout(ceil(length(this.chanNums)/2),2);
            for n=1:size(avgs,1)
                ax=nexttile;
                for m=1:size(avgs,3)% Corresponds to the this.stimulusNums
                    errorbar(this.stimulusCodes,avgs(n,:,m),sems(n,:,m),'displayName',sprintf('Stimulus #%g',this.stimulusNums(m)));
                    hold(ax,"on");
                end
                hold(ax,"off");
                title(sprintf('Channel %g: %s',this.chanNums(n),EPR.channelNames{this.chanNums(n)}) );
                ylabel([this.feature, ' (', this.getFeatureUnit(EPR,this.chanNums(n)),')']);
                xlabel('Stimulus code');

                ylim(ax,[0,inf]);% make each axis have its own y-limit
                % ylim(ax,[0,max(avgs(:))]);% Uncomment to make all axis have the same y-limit
                xlim(ax,[min(this.stimulusCodes),max(this.stimulusCodes)]);% Make all axis have the same x-limit
                box off
            end
            
            legend();
        end
    end

    methods(Access=private)
        function setDefaultIfMissing(this,EPR)
            % Set the default property values if they are not set.
            % [INPUT]
            % EPR struct: The main EPR struct.
            if isempty(this.stimulusCodes)
                %this.stimulusCodes= unique(eprecorder_get_epoch_stimulus_code(EPR),'sorted');
                this.stimulusCodes=eprecorder_get_epoch_stimulus_code(EPR,[],true);
            end
            if isempty(this.chanNums)
                this.chanNums=1:length(EPR.channelNames);
            end
        end
        function [avg,sem]=forOneChannel(this,EPR,chan_num,stimulus_codes,stimulus_num)
            % Compute the recruitment curve for a single channel.
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int: Channel number
            % stimulus_codes array<double>: Event codes.
            % stimulus_num int: Stimulus number.
            % [OUTPUT]
            % avg array<double>: Mean feature means. With the same size as
            % input stimulus_codes
            % sem array<double>: Standard error of the mean corresponding
            % to the feature values. With the same size as the output avg.
            avg=zeros(1,length(stimulus_codes));
            sem=avg;

            

            for n=1:length(stimulus_codes)
                f=this.getFeatureValues(EPR,chan_num,stimulus_codes(n),stimulus_num);
                f=rmmissing(f);
                nf=length(f());
                avg(n)=mean(f);
                sem(n)=std(f)/sqrt(nf);
            end


            if this.shouldNormalise()
                norms=eprecorder_response_norm.get(EPR,this.normalisationType);

                % If all norms are nan, we assume that normalisation has
                % never been processes check if it is one we can do
                % automatically:
                if all(isnan(norms)) && strcmp(this.normalisationType,eprecorder_response_norm.TYPE_RMT_PEAK2PEAK)
                    warning('Performing automatic normalisation using default values for eprecorder_response_motor_threshold()');
                    mt=eprecorder_response_motor_threshold();
                    EPR_temp=mt.detectRMT(EPR);
                    normaliser=eprecorder_response_norm(this.normalisationType,EPR_temp);
                    norms=normaliser.process();
                end

                % Now try to normalise
                norm_val=norms(chan_num);

                if isnan(norm_val)
                    warning('Normalisation value for channel %d is unset for type=%s',chan_num,this.normalisationType);
                end

                avg=eprecorder_response_norm.normalise(this.normalisationType,avg,norm_val);
                sem=eprecorder_response_norm.normalise(this.normalisationType,sem,norm_val);
            end
        end
        function feature_values=getFeatureValues(this,EPR,chan_num,stimulus_code,stimulus_num)
            % Retrieve the feature values based on the instance feature
            % property. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int: Channel number
            % stimulus_codes array<double>: Event codes.
            % stimulus_num int: Stimulus number.
            % [OUTPUT]
            % feature_values array<double>: Feature values. A row vector
            % where each entry is derived from an epoch.

            switch(this.feature)
                case 'peak2peak'
                    feature_values=eprecorder_response.getPeak2peak(EPR, ...
                        chan_num,[],stimulus_code, ...
                        this.excludeNoResponse,this.excludeReject,stimulus_num);
                case 'area'
                    feature_values=eprecorder_response.getArea(EPR, ...
                        chan_num,[],stimulus_code, ...
                        this.excludeNoResponse,this.excludeReject,stimulus_num);
                case 'onset_time'
                    feature_values=eprecorder_response.getEffectiveOnsetTimes(EPR, ...
                        chan_num,[],stimulus_code, ...
                        this.excludeNoResponse,this.excludeReject,stimulus_num);
                case 'time_width'
                    feature_values=eprecorder_response.getEffectiveTimeWidths(EPR, ...
                        chan_num,[],stimulus_code, ...
                        this.excludeNoResponse,this.excludeReject,stimulus_num);
                otherwise
                    error(['Unknown feature, ',this.feature]);
            end
        end
        function feature_unit=getFeatureUnit(this,EPR,chan_num)
            % The unit of a current feature
            % property. 
            % [INPUT]
            % EPR struct: EPR data structure.
            % chan_num int: Channel number
            % [OUTPUT]
            % feature_unit string: Feature data unit.

            switch(this.feature)
                case 'peak2peak'
                    feature_unit=EPR.channelUnits{chan_num};
                case 'area'
                    feature_unit=[EPR.channelUnits{chan_num},' x ms'];
                case 'onset_time'
                    feature_unit='ms';
                case 'time_width'
                    feature_unit='ms';
                otherwise
                    error(['Unknown feature, ',this.feature]);
            end
        end
        
        function re= shouldNormalise(this)
            % Check if normalisation is required
            re=true;
            if strcmp(this.normalisationType,'none')
                re=false;
            end
        end
    end
end

