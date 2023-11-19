function eprecorder_gmeasure(source,event,data_scales,data_units)
%gmeasure Take measurement between two points on the current figure.
% The function prompt you to select two points for signal calculation on 
% the current figure
% source: When this functionis used in a graphics callback, this will be
%           the graphics object source of the event trigering the call.
% event: When this functionis used in a graphics callback, this will be
% the event object that occured.
% data_scales: A two element vector corresponding scales for x and y data 
% data_units:A two element cell corresponding units for x and y data

if nargin<3
    data_scales=[1,1];
end

if nargin<4
    data_units={'ms','Aplitude(raw)'};
end

xy=-ginput(1)+ginput(1);


x=xy(1)*data_scales(1);
x_str=[mat2str(round(x,3)),' ',data_units{1}];

y=xy(2)*data_scales(2);
y_str=[mat2str(round(y,3)),' ',data_units{2}];

msgbox(sprintf('%s\n%s',['x: ',x_str],['y: ',y_str]),'Measure');

end

