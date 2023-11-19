function fn = makeFilename(subjectId,sectionN,timepoint,side,target,condition,subsection,tag)
% Make a full filename for saving data.
% 
% [INPUT]
% subjectId string: The subject ID
% sectionN int: The sction number
% timepoint string: The time point of the experiment
% side string: The selected side of the experiment
% target string: The target anatomy
% condition string: The experimental condition
% subsection string: The subsection number
% tag string: Experimenter added tag
% [OUTPUT]
% fn string: The full filename.
%

if(tag)
    tag=['_' tag];
end

fn= [subjectId '_s' mat2str(sectionN) '_' timepoint '_' side '_' target '_' condition '_s' mat2str(subsection) tag '.mat'];%syntax for filename of saved data;

end

