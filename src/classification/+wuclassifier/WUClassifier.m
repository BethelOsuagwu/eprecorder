classdef WUClassifier < mepclassifier.ClassifierContract
    %Implements a classifier
    
    properties(Access=protected)

        driver;
        inputShape=[40,3];
    end
    

    methods
        function this = WUClassifier(driver)
            %Construct an instance of this class
            % [INPUTS]
            % driver string: Unique identifier of the classifier
            
            % load the model
            c=load('wuclassifier/wuclassifier.mat');
            this.layers=c.layers;
            this.sampleFreq=c.sample_freq;
            this.sanityTestInputs=c.sanity_test_inputs;
            this.sanityTestOutputs=c.sanity_test_outputs;

            this.inputShape=c.input_shape(2:3);%Ensure we have the correct input shape.

            this.name='Wavelet U MEP classifier';

            this.driver=driver;
        end
        
        function output = predict(this,dataset,sampleFreq)   
            % dataset: Dataset of shape= [batch x time x features]
            % [OUTPUTS}
            % output: The prediction.
            
            if this.sampleFreq ~=sampleFreq
                error(' The correct sampling frequency is %g, but %g was provided %g',this.sampleFreq,sampleFreq);
            end
            
            output=this.predictionLoop(dataset);
        end
    end

    methods(Access=protected)
        function dataset=preprocessInput(this,dataset)
            %run MDT

            compIdx=[3,4];% The components of MDT to add to the dataset.

            comps=eprecorder_util.mdt(dataset);
            dataset=[dataset,comps(:,compIdx)];
        end
    end
    
end

