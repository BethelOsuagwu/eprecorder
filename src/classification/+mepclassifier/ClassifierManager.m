classdef ClassifierManager
    % Classifier manager
    
    methods
        function this = ClassifierManager()
            % Construct an instance of this class
        end
        
        function c=classifier(this,driver)
            % Resolves a classifier
            % [INPUTS]
            % driver string: Driver name. The default is 'default'.
            % [OUTPUTS]
            % c mepclassfier.ClassifierContract|[]: Classifier contract instance or
            %   [] if the classifier is not an mepclassifier.ClassifierContract. An
            %   error is thrown for unknown driver
            % 
            if nargin< 2
                driver='default';
            end
            
            c=this.find(driver);
            %if c.path
            %    addpath(c.path);
            %end

            % Add to path all folders in the classification package root so
            % that folders of classifiers that are not packages are added
            % so that their main classes are discoverable.
            root_path=fileparts(fileparts(mfilename('fullpath')));
            addpath(genpath(root_path));

            c=feval(c.classname,driver);
            if ~isa(c,'mepclassifier.ClassifierContract')
                c=[];
            end
        end
    end
    methods(Access=public,Static)
        function c=find(driver)
            % [INPUTS]
            % driver string: Id of a classifier
            cs=mepclassifier.ClassifierManager.all();
            for n=1:length(cs)
                if strcmp(cs(n).driver,driver)
                    c=cs(n);
                    return
                end
            end
            error('Unkown driver, %s',driver);
                    
        end
        function cs= all()
            % Get all classifiers
            file_path=fileparts(fileparts(mfilename('fullpath')));
            file_name = fullfile(file_path,'classifiers.json');
            fid = fopen(file_name); 
            raw = fread(fid,inf);
            str = char(raw'); 
            fclose(fid);
            cs = jsondecode(str);
        end
    end
end

