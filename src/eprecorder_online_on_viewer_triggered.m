function eprecorder_online_on_viewer_triggered(simulation_time)
% Called when trigger is recieved and aknowleged/processed by the online viewer.
% [INPUT]
% simulation_time: the simulation time at which the acknowleged/processed
% triggere was recieved. 

global EPR;

EPR.online.viewerTriggerTimes(end+1)=simulation_time;
end

