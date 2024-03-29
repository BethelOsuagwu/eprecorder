classdef (Abstract) ClassifierContract < handle
    %CLASSIFIERCONTRACT is the interface for classifier
    
    properties(Access=protected,Abstract)
        driver; % string: The driver name.
        inputShape; % 1D vector of input dimension without the batch size.
         
    end

    properties(Access=protected)
        outputCols=3; % Scalar, number of columns in the output where each represents a class.
        epOutputColIdx=3; % The index of output colunms representing properbilities for output column.
        
        % The data sequence used for training the model.
        % The sequence is causal if the last sample/step of a sequence
        % provides the label. It is non-causal if the first sample provides
        % the label. Using the wrong value this property can lead to a
        % shift in the predicted result.
        useCausalSquence=false;

        name='untitled'; % string: Set the name of the classifier
        layers % cell: Model layers information. Each entry is a structure with keys (weights:cell,config:struct,type:string). @see predictionLoop() for example usage.
        
        sampleFreq % double: Sample frequency(Hz) of model. This is the sample frequency of the training data. 
        sanityTestInputs % Model sanity test input
        sanityTestOutputs % Model sanity inputs output
    end
    
    
    methods(Abstract)
        preds=predict(this,dataset,sampleFreq)
            % Make predictions for the given dataset.
            % [INPUTS]
            % dataset array: Dataset of shape= [batches x steps x features]
            % sampleFreq double: Sampling frequency in Hz, of the given
            %   inference data. 
            % [OUTPUTS]
            % preds array: Predictions. Shape=[batches,output_dim]
    end
    
    methods(Access=protected)
        function dataset=preprocessInput(this,dataset)
            % Perform preprocessing of the raw input data.
            % [INPUT]
            % dataset array: input vector.
            % [OUTPUT]
            % dataset array: preprocessed data.
        end
        function dataset = predictionLoop(this,dataset)  
            % A helper to perform prediction.
            %
            % dataset: Dataset of shape compactible to the first layer.
            % [OUTPUTS}
            % The prediction.
            
            
            
            %%
            for layer_cell=this.layers
                layer=layer_cell{1};
                switch(layer.type)
                    case 'Normalization'
                        
                        %dataset=(dataset-layer.config.mean)./sqrt(layer.config.variance);
                        for batch=1:size(dataset,1)
                            for feature=1:size(dataset,3)
                                dataset(batch,:,feature)= (dataset(batch,:,feature)-layer.config.mean(feature))/sqrt(layer.config.variance(feature));
                            end
                        end
                    case 'Conv1D'
                        padding=layer.config.padding;
                        strides=layer.config.strides;
                        activation=layer.config.activation;
                        dataset=mepclassifier.Conv1D(padding,strides,activation).setWeights(layer.weights{1},layer.weights{2}).call(dataset);
                    case 'Conv1DTranspose'
                        padding=layer.config.padding;
                        strides=layer.config.strides;
                        activation=layer.config.activation;
                        dataset=mepclassifier.Conv1DTranspose(padding,strides,activation).setWeights(layer.weights{1},layer.weights{2}).call(dataset);
                    case 'LSTM'
                        dataset=mepclassifier.LSTM().setWeights(layer.weights{1},layer.weights{2},layer.weights{3}).call(dataset);
                    case 'Dense'
                        dataset=mepclassifier.Dense().setWeights(layer.weights{1},layer.weights{2}).call(dataset);
                    case 'MaxPooling1D'
                        pool_size=layer.config.pool_size;
                        padding=layer.config.padding;
                        strides=layer.config.strides;
                        dataset=mepclassifier.MaxPooling1D(pool_size,padding,strides).call(dataset);
                    case 'UpSampling1D'
                        dataset=mepclassifier.Upsampling1D(layer.config.size).call(dataset);
                    otherwise
                        error('Unknown layer:%s',layer.type);
                end
            end
            

        end
    end
    
    methods
        function set.name(this,name)
            this.name=name;
        end
    end
    
    
    methods
        function this = ClassifierContract()
            %CLASSIFIERINTERFACE Construct an instance of this class  
        end

        function driver=getDriver(this)
            % Get driver name
            % [OUTPUT]
            % driver string: Driver name.
            driver=this.driver;
        end

        function result= sanityTest(this)
            % Run a sanity test for the classifier.
            % [OUTPUTS]
            % result logical: True if the test passes
            tol=10^-2; % Error tolerance
            
            result=false;
            expected =this.sanityTestOutputs;
            actual=this.predict(this.sanityTestInputs,this.sampleFreq);
            length_match=(length(size(actual))==length(size(expected)));
            size_match=all(size(actual)==size(expected));
            value_match=all(abs(actual(:)-expected(:))<tol);
            if length_match && size_match && value_match
                result=true;
            end
            
            if nargout <1
                if result
                    fprintf('_/: %s passed sanity test \n',this.name);
                else
                    error('x: %s failed sanity test: \n expected output=%s, \n but got= %s',this.name,mat2str(expected),mat2str(actual));
                end
                clear result
                return;
            end
            
        end
        
        
        function [start,stop,preds]=classify(this,data,dataSampleFreq,min_width,threshold,discontinuity)
            % Classify every point in the data.
            % [INPUTS]
            % data array<double>: Samples of shape=[num_samples,features]
            % dataSampleFreq double: The sample frequency in Hz, of the
            %   given data, i.e. inference data. 
            % min_width []|double: Min width of a response in ms.
            % threshold []|double: Classifier threshold. The default is 0.5.
            % discontinuity double: maximum width in ms of a break when 
            %   tracing a response.
            % [OUTPUTS]
            % start int|NaN: Start sample of MEP in data. NaN=>not found.
            % stop int|NaN: Stop sample of MEP in data. NaN=>not found.
            % preds array<double>: The probability of each sample in data
            %   being MEP.
            if nargin < 4 || isempty(min_width)
                min_width=5;
            end
            
            if nargin < 5 || isempty(threshold)
                threshold=0.5;
            end
            
            if nargin < 6 
                discontinuity=5;
            end
            
            min_width_samples=min([round(dataSampleFreq*min_width/1000), 1]);
            tolerance=round(dataSampleFreq*discontinuity/1000);
            
            data=this.preprocessInput(data);

            dataset=this.sequence(data);
            preds=this.predict(dataset,dataSampleFreq);
            [start,stop]=this.trace(preds,threshold,min_width_samples,tolerance);
        end
        
    end
    
    methods(Access=protected)
        function dataset=sequence(this,data)
            % Generate sequences for the given data
            % [INPUTS]
            % data array<double>: Samples of shape=[num_samples,features]
            % [OUTPUTS]
            % dataset array<double>: Input sequence for classifier.
            %   Shape=[batch_size=num_samples,sequence_length,features]

            feature_dim=this.inputShape(2); % Feature dimension

            % Throw error if feature dimension of data is not equal to the
            % feature dimension of the model
            if size(data,2)~=feature_dim
                error('x: Feature dimension of data is not equal to the feature dimension of the model');
            end
            
            num_samples=size(data,1); % Number of samples

            L=this.inputShape(1); % Sequence length
            
            % Pad data with the last sample to make it divisible by L
            data_padded=[data;repmat(data(end,:),L-mod(num_samples,L),1)];

            % Again pad the data but with L-1 samples. This is done to make
            % sure that the last L+1 samples can be segmented into full L
            % samples. Whether a left or right padding should be used
            % depends whether the model sequence is causal.
            if this.useCausalSquence
                % Left-pad the data with the first sample in accordance
                % with causal sequence during training where the last
                % sample/step of a sequence provides the label. 
                data_padded=[repmat(data_padded(1,:),L-1,1);data_padded];
            else
                % Right-pad data with the last sample to increase it by L-1.
                % For non-causal sequence, the first sample/step of a
                % sequence supplies the sequence's label during training.
                data_padded=[data_padded;repmat(data_padded(end,:),L-1,1)];
            end
            
            

            % Initialize dataset
            dataset=zeros(num_samples,L,feature_dim);

            % Generate sequences
            for i=1:num_samples
                dataset(i,:,:)=data_padded(i:i+L-1,:);
            end

            % Assert that the dataset is of the correct shape
            if feature_dim==1
                % MATLAB does not allow trailing singleton dimensions
                assert(all(size(dataset)==[num_samples,L]),'x: Dataset is not of the correct shape');
            else
                assert(all(size(dataset)==[num_samples,L,feature_dim]),'x: Dataset is not of the correct shape');
            end

        end
        
        function [start,stop]=trace(this,preds,threshold,min_width,tolerance)
            % Trace traces prediction probabilities to determin MEP onset
            % and offset.
            % [INPUTS]
            % preds array<double>: The probability of MEP being MEP.
            %   It uis assumed that preds has shape=[num_samples,units=3]
            %   where units=3 is the number of output units of the model.
            %   The first unit is the probability of the sample being
            %   background, the second unit is the probability of the 
            %   sample being stimulation artifact and the third unit is the 
            %   probability of the sample being MEP. This method should be
            %   overriden by the concrete class if these do not apply.
            % threshold double: classifier threshold i.e the thresold for
            %   values of preds. The default is 0.5.
            % min_width double: The minimun width of a trace in samples.
            % tolerance int: maximum number of points(i.e samples) within a 
            %       discontinuity in streaks allowed. The default is 5.
            
            %   The default is 20.
            % [OUTPUTS]
            % start double|NaN: Start sample of MEP in preds.
            % stop double|NaN: Stop sample of MEP in preds.

            if nargin <3
                threshold=0.5;
            end

            if nargin < 4
                min_width=20;
            end

            if nargin < 5
                tolerance=5;
            end


            epIdx=this.epOutputColIdx;
            
                     
            start=NaN;
            stop=NaN;

            % Find row predicted to be MEP
            mep_preds=preds(:,epIdx)>threshold;
            
            % Early return if nothing is above threshold.
            if ~any(mep_preds)
                return
            end

            % Find the streaks of consecutive MEP predictions.
            streaks=this.findStreaks(mep_preds,tolerance);

            % Remove streaks with small width
            if ~isempty(streaks)
                W=streaks(:,2)-streaks(:,1);
                streaks(W<min_width,:)=[];
            end

            % Return if no streak was found
            if isempty(streaks)
                return
            end
            

            % Get the mean strength of the streaks
            S=zeros(size(streaks,1),1);
            for n=1:size(streaks,1)
                a=streaks(n,1);
                b=streaks(n,2);
                S(n)=mean(preds(a:b,epIdx));
            end

            % Get the length of the streaks
            W=streaks(:,2)-streaks(:,1);

            % Get the most powerful streak
            [~,idx]=max(W.*S);

            % Find the longest streak
            %[~,idx]=max(streaks(:,2)-streaks(:,1));
            
            

            % Get the start and stop indices of the longest streak
            start=streaks(idx,1);
            stop=streaks(idx,2);

            % If the start and stop indices are the same, then there is no
            % MEP
            if start==stop
                start=NaN;
                stop=NaN;
            end

            
            
        end
    end
    
    methods(Access=protected,Static)
        function streaks = findStreaks(vec, tolerance)
            % find indices of all streaks of consecutive 1s with a
            % tolerance for broken streaks 
            % [INPUTS]
            % vec array<logical|double>: column vector containing 0 or 1
            % tolerance int: maximum number of points(i.e samples) within a 
            %   discontinuity in streaks allowed.
            %[OUTPUTS]
            % streaks array<double>: Shape=[len(vec),2], each row represents a
            %   streak and the two columns contain the start and end
            %   indices of the streak, respectively.  
            if nargin < 2
                tolerance=20;
            end

            % initialize variables
            streaks = zeros(0, 2);
            i = 1;
            n = length(vec);



            % search for streaks
            while i <= n
                % find start of streak
                if vec(i) == 1
                    start = i;
                    % find end of streak
                    while i < n && hasMore1s(vec, i, tolerance)
                        i = i + 1;
                    end
                    streaks(end+1, :) = [start i];
                end
                i = i + 1;
            end

            function more = hasMore1s(vec, idx, tolerance)
                % check if there are more 1s in vec after index idx.
                % [INPUTS]
                % vec array: 1D array within which to search for re 1s.
                % idx int: The index of vec above which more 1s is
                %   searched.
                % tolerance int: How much more indexs above idx is
                %   searched. 
                % [OUTPUTS]
                % more logical: True if a one is found.
                more = false;
                for j = 1:tolerance
                    k = idx + j;
                    if k <= length(vec) && vec(k) == 1
                        more = true;
                        break;
                    end
                end
            end
        end

    end
        
    

    
end

