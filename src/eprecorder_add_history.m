function EPR = eprecorder_add_history(EPR,action,description,time_of_action)
% Add an activity to histor
% [INPUT]
% EPR: The main EPR structure
% action string: The matlab executable/pseudo script to reproduce the action
% description string: The description
% time_of_action string: The time the event took place
% [OUTPUT]
% EPR: The input structure with updated timeline:
%       The added structure 1D cell where each input is a 1x3 cell
%       containing action, description and time_of_action respectively

if nargin<3
    description='';
end
if nargin<4
    time_of_action=now;
end

if(~isfield(EPR,'history'))
    EPR.history={{'disp(''Big Bang'')','Big Bang',now}};% Timeline of activities on the dataset
end

EPR.history{end+1}={action,description,time_of_action};
end

