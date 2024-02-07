classdef eprecorder_util
    %EPRECORDER_UTIL Utility functions
    
    properties
        
    end
    
    methods(Static)
        
        function newTable=exportWithMdt(inputFilename,compIdx)
            % A helper to export a csv signal to a new csv with MDT
            % components. @see mdtComp()
            % inputFilename string: Fullfilename of csv.
            % compIdx :@see mdtComp()
            % [OUTPUT]
            % newTable table: the table written to csv file.
            %

            

            if nargin < 1 || isempty(inputFilename)
                [file,path]=uigetfile('csv','Select a file to mdt components');
                inputFilename=fullfile(path,file);
            end

            if nargin<2
                compIdx=[];
            end

            % Load CSV file as a table
            dataTable = readtable(inputFilename,'VariableNamingRule','preserve');
        
            % Extract signal from the first column
            signal = dataTable{:, 1};
        
            % Call the mdtComp() function
            [result,compIdx_used] = eprecorder_util.mdtComp(signal,compIdx);

            
            signalName=dataTable.Properties.VariableNames{1};
        
            columnNames={signalName};
            for i = 2:size(result, 2)
                columnNames{i} = ['component', num2str(compIdx_used(i-1))];
                
            end

            newTable=array2table(result,'VariableNames',columnNames);

            % remove signale from datatable and merge with new table
            dataTable=removevars(dataTable,signalName);
            newTable=[newTable,dataTable];
        
            % Create the new filename with a 'mdt' suffix
            [folder, name, ext] = fileparts(inputFilename);
            outputFilename = fullfile(folder,[name, '_mdt', ext]);
        
            % Check if the output filename already exists
            if exist(outputFilename, 'file') == 2
                
                answer=questdlg([outputFilename,' already exists; overwrite it?'],'Export labels with MDT','Yes','No','No');
                switch(answer)
                    case 'Yes'
                        % do nothing
                    otherwise
                        error('%s already exists. Delete to re save.',outputFilename);
                end
                
                
            end
        
            % Save the updated data, including headers, to the new CSV file
            writetable(newTable, outputFilename);
        end


        function [dataset,compIdx]=mdtComp(signal,compIdx)
            % Include MDT components as additional signal in the giving signal.
            % The signal will be decomposed into 8 components.
            % [INPUT]
            % signal array: Column vector
            % compIdx array: {1:8} The index of the components to be included in
            %   the signal. The default is [3,4]
            % [OUTPUT]
            % dataset array: The signal with additional columns. Each
            %   additional column is the component of the decomposition
            %   indicated in compIdx. Dim=size(signal,1) x 1+len(compIdx).
            % compIdx array: compIdx used.
            
            if nargin <2 || isempty(compIdx)
                compIdx=[3,4];% The components of MDT to add to the dataset.
            end

            comps=eprecorder_util.mdt(signal);
            dataset=[signal,comps(:,compIdx)];

        end

        function signal_com =mdt(signal)
            % Decompose Signal into 8 components using the MODWT.
            % Requires Wavelet Toolbox
            %[INPUT]
            % signal array: 1D column vector.
            % [OUTPUT]
            % signal_com array: Signal components. Sahpe=[len(signal),8].


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

        function rmse_result = rmse(array1, array2)
            % Calculate RMSE ommitting rows with nan.

            % Find indices of NaN values in either array
            nanIndices = isnan(array1) | isnan(array2);
        
            % Omit NaN values from both arrays
            array1 = array1(~nanIndices);
            array2 = array2(~nanIndices);
        
            % Calculate RMSE
            rmse_result = sqrt(mean((array1 - array2).^2));
        end

    end
end

