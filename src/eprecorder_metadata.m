classdef eprecorder_metadata



   
   methods(Access=public, Static)
       

       function EPR=setMissing(EPR)
           % Add missing default metadata.
           %
           % [INPUT]
           % EPR struct:
           % [OUTPUT]
           % EPR struct: The input EPR with the following field added if missing:
           %    stim_code_to_intensity_factor array: Each entry is for
           %        corresponding channel's stimulus code to intensity
           %        conversion factor. E.g. RMT of the target muscle.
           %        Dimension is [nchannels x 1].

           if ~eprecorder_metadata.hasBaseField(EPR)
               EPR.metadata=struct();
           end

           
           if isempty(eprecorder_metadata.get(EPR,'stim_code_to_intensity_factor'))
               meta.name='stim_code_to_intensity_factor';
               meta.description='Each entry is for corresponding channel''s stimulus code to intensity conversion factor. E.g. RMT of the target muscle';
               meta.value=ones(length(EPR.channelNames),1);

               if isempty(EPR.metadata) || isempty(fieldnames(EPR.metadata))
                    EPR.metadata=meta;
               else
                   EPR.metadata(end+1)=meta;
               end
           end
       end

       function EPR=set(EPR,name,value,description)
           % Set the value of the given metadata.
           % [INPUT]
           % EPR struct:
           % name string:
           % value array<double>|double: For 'stim_code_to_intensity_factor' metadata, if numel(value)==1 then it will be
           %    replicated by the number of channels.
           % description string:
           % [OUTPUT]
           % EPR struct: The input with the meta added.

           if ~eprecorder_metadata.hasBaseField(EPR)
               EPR=eprecorder_metadata.setMissing(EPR);
           end

           

           % Lets validate in case we know the meta
           value=eprecorder_metadata.validate(EPR,name,value);


           %
           meta.name=name;
           meta.description=description;
           meta.value=value;
           EPR.matadata(end+1)=meta;

       end

       function EPR=update(EPR,name,value,description)
           % Update the value of the given metadata.
           % [INPUT]
           % EPR struct:
           % name string:
           % value array<double>|double: For 'stim_code_to_intensity_factor' metadata, if numel(value)==1 then it will be
           %    replicated by the number of channels.
           % description string: Ignored if it is set to [] or empty. The
           %    deafult is [].
           % [OUTPUT]
           % EPR struct: The input with the meta updated.

           if nargin <4
               description=[];
           end

           if ~eprecorder_metadata.hasBaseField(EPR)
               EPR=eprecorder_metadata.setMissing(EPR);
           end

           % Lets validate if we know the meta
           value=eprecorder_metadata.validate(EPR,name,value);


           %
           meta=eprecorder_metadata.get(EPR,name);
           if isempty(meta)
               % If it does not exists we will add it. It may be better to
               % through an error through?
               EPR=eprecorder_metadata(EPR,name,value,description);
               return;
           end

           meta.value=value;
           if ~isempty(description)
               meta.description=description;
           end
           
           for k=1:length(EPR.metadata)
               if strcmp(EPR.metadata(k).name,name)
                    EPR.metadata(k)=meta;
                    break;
               end
           end

       end

       function meta=get(EPR,name)
           % Get the given metadata. Returns empty value if
           % not found.

           meta=[];
           if ~eprecorder_metadata.hasBaseField(EPR) || isempty(fieldnames(EPR.metadata))
               return;
           end

           for k=1:length(EPR.metadata)
               if strcmp(EPR.metadata(k).name,name)
                    meta=EPR.metadata(k);
                    break;
               end
           end

       end

       function has=hasBaseField(EPR)
           % Check if the root field for metadata exists
           has=false;
            if isfield(EPR,'metadata')
                has=true;
            end
       end

       
   end

   methods(Access=private,Static)
       function value=validate(EPR,name,value)
           % Validate the default meta values

           % Lets validate if we know the meta
           switch(name)
               case 'stim_code_to_intensity_factor'
                   if numel(value)==1
                       value=repmat(value,length(EPR.channelNames),1);
                   end
                   value=reshape(value,[],1);
                   if length(EPR.channelNames)~=size(value,1)
                       error('Incorrect value for meta: stim_code_to_intensity_factor: There should be one value per data channel');
                   end
               otherwise
                   %Do nothing
           end
       end
   end
       
end