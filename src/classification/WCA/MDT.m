% Decompose Signal using the MODWT

%please import your csv data as numeric matrix first
%for example if the imported data name is EPRtrain, then

signal = EPRtrain(:,1); %original data, take col 1 without label

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

%combine all the components together with the original signal as well as
%the labels
signal_com = [signal,signal1,signal2,signal3,signal4,signal5,...
              signal6,signal7,signal8,EPRtrain(:,2:end)];

%csvwrite('EPR_MODWT8p_train.csv',signal_com);


