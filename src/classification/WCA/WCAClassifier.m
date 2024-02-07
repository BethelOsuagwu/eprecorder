classdef WCAClassifier < mepclassifier.ClassifierContract
    %Implements a classifier
    
    properties(Access=protected)
        weights % Model weight
        means = [0, 0, 0];% Model mean
        variance % Model variance
        stds = [0,0,0];
        onnxModel;% ONNX model

        driver;
        inputShape=[50,3];
    end
    

    methods
        function this = WCAClassifier(driver)
            %DEFAULTCLASSIFIER Construct an instance of this class
            % [INPUTS]
            % driver string: Unique identifier of the classifier.
            
            % load the model
            onnxModel = importONNXNetwork('MEPmodel.onnx', 'OutputLayerType', 'classification',InputDataFormats='BTC',TargetNetwork='dlnetwork');
            
            this.onnxModel=onnxModel.initialize();

            % Import the normalisation params
            c=load('MEPmodel.mat');
            this.means=c.means;
            this.stds=c.stds;

            
            
            this.name='WCA classifier';

            this.driver=driver;

            this.useCausalSquence=true;
        end
        
        function output = predict(this,dataset,sampleFreq)   
            % dataset: Dataset of shape= [batch x 50 x 1]
            % [OUTPUTS}
            % output: The prediction.
            
            
            
            [batches,segLen,features]=size(dataset);
            output=zeros(batches,this.outputCols);
            for batch= 1:batches
                input=dataset(batch,:,:);
                input =reshape(input,segLen,features);
                %input=squeeze(input);
                input=(input-this.means)./this.stds;
                input = dlarray(input,'TCB');
                y=this.onnxModel.predict(input);
                output(batch,:)=y.extractdata();
            end
            
        end

    end

    methods(Access=protected)
        function dataset=preprocessInput(this,dataset)
            %run MDT

            compIdx=[3,4];% The components of MDT to add to the dataset.

            comps=this.MDT(dataset);
            dataset=[dataset,comps(:,compIdx)];
        end
    end

    methods(Static)
        function signal_com =MDT(signal)
            % 
            % Decompose Signal into 8 components using the MODWT
            %[INPUT]
            % signal array: 1D column vector.
            % [OUTPUT]
            % signal_com array: Signal components. Sahpe=[len(signal),8].


            signal_com=eprecorder_util.mdt(signal);
            
            return

            % DELETE BELOW TO USE THE eprecorder_util.mdt

            % Padd with zeros
            pad_len=1000;% arbtrary amount for now
            signal=[signal;repmat(signal(end),pad_len,1)];

            %please import your csv data as numeric matrix first
            %for example if the imported data name is EPRtrain, then
            
            %signal = EPRtrain(:,1); %original data, take col 1 without label
            
            % 8 level of components, all of them independant, Reconstructed by the
            % single components which is true,this is the indication array for
            % reconstrction later
            levelForReconstruction1 = [true, false, false, false, false, false, false, false];
            levelForReconstruction2 = [false, true, false, false, false, false, false, false];
            levelForReconstruction3 = [false, false, true, false, false, false, false, false];
            levelForReconstruction4 = [false, false, false, true, false, false, false, false];
            levelForReconstruction5 = [false, false, false, false, true, false, false, false];
            levelForReconstruction6 = [false, false, false, false, false, true, false, false];
            levelForReconstruction7 = [false, false, false, false, false, false, true, false];
            levelForReconstruction8 = [false, false, false, false, false, false, false, true];
            
            % Perform the decomposition using modwt
            wt = modwt(signal, 'sym4', 8); % 8 means how many components
            
            % Construct MRA matrix using modwtmra
            mra = modwtmra(wt, 'sym4');
            
            % Sum along selected multiresolution signals
            % reconstruct the components as a channel of signal
            signal1 = sum(mra(levelForReconstruction1,:),1)';
            signal2 = sum(mra(levelForReconstruction2,:),1)';
            signal3 = sum(mra(levelForReconstruction3,:),1)';
            signal4 = sum(mra(levelForReconstruction4,:),1)';
            signal5 = sum(mra(levelForReconstruction5,:),1)';
            signal6 = sum(mra(levelForReconstruction6,:),1)';
            signal7 = sum(mra(levelForReconstruction7,:),1)';
            signal8 = sum(mra(levelForReconstruction8,:),1)';
            
            %combine all the components together
            signal_com = [signal1,signal2,signal3,signal4,signal5,...
                          signal6,signal7,signal8];

            % remove pad
            signal_com=signal_com(1:end-pad_len,:);

        end
    end
end

