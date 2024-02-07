classdef BinaryUClassifier < mepclassifier.ClassifierContract
    %Implements a classifier
    
    properties(Access=protected)
        
        driver;
        inputShape=[50,1];
    end
    

    methods
        function this = BinaryUClassifier(driver)
            %Construct an instance of this class
            % [INPUTS]
            % driver string: Unique identifier of the classifier
            
            % load the model
            c=load('binaryuclassifier/binaryuclassifier.mat');
            this.layers=c.layers;
            this.sampleFreq=c.sample_freq;
            this.sanityTestInputs=c.sanity_test_inputs;
            this.sanityTestOutputs=c.sanity_test_outputs;
            this.name='Binary U MEP classifier';

            this.driver=driver;

            this.outputCols=1;
            this.epOutputColIdx=1;
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
    
end

