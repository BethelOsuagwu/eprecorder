function eprecorder_online_on_triggered(simulation_time)
% Called when trigger is recieved online
% [INPUT]
% simulation_time: the simulation time at which triggere is recieved.

global EPR;

EPR.online.triggerTimes(end+1)=simulation_time;
end

