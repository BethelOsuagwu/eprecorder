classdef eprecorder_filter
    %EPRECORDER_FILTER designs and perform filtering.
    %   Filters data

    properties(Constant,Access=public)
        TYPE_LOW='low';
        TYPE_HIGH='high';
        TYPE_BANDPASS='bandpass';
        TYPE_STOP='stop';
        TYPE_NOTCH='notch';

        METHOD_BUTTER='butter';
    end
    properties(SetAccess=protected)      
        B=[];% Filter numerator
        A=[];% Filter denominator
        method=eprecorder_filter.METHOD_BUTTER;% filter method
        order=2;% Filter order
        freqCutoff=[20,500];% Frequency cut off in Hz
        Fs=4000;%Sampling rate
        type=eprecorder_filter.TYPE_BANDPASS;% Filter type {'low','high','bandpass','stop',etc}
        
    end
    
    methods(Access=public)
        function this = eprecorder_filter(method,order,freqCutoff,Fs,type)
            %EPRECORDER_FILTER Construct an instance of this class
            %   Create a filter design and operation object.
            % [INPUT]
            % method string: filter method e.g b"utter"
            % order int: Filter order
            % freqCutoff int|2-element-vector: Frequency cut off in Hz e.g:[20,500]
            % filterType string: Filter type {'low','high','bandpass','stop',etc}
            % 
            if nargin>=1
                this.method=method;
            end
            if nargin>=2
                this.order=order;
            end
            if nargin>=3
                this.freqCutoff=freqCutoff;
            end

            if nargin>=4
                this.Fs=Fs;
            end

            if nargin>=5
                this.type=type;
            end
            
        end
        function [is_valid,msg]=validate(this)
            % Check if filter options are valid.
            % [OUTPUT]
            % is_valid boolean: True when filter params are valid
            % msg string: Message.

            is_valid=true;
            msg='';
            
            if(~strcmp(this.method,this.METHOD_BUTTER))
                is_valid=false;
                msg=['Only available method is ' this.METHOD_BUTTER];
                return;
            end

            switch(this.type)
                case {this.TYPE_LOW,this.TYPE_HIGH}
                    if(numel(this.freqCutoff)>1)
                        is_valid=false;
                        msg=('For low/high-pass, the cutoff should have one element');
                        return;
                    end
                case {this.TYPE_BANDPASS,this.TYPE_STOP,this.TYPE_NOTCH}
                    if(numel(this.freqCutoff)~=2)
                        is_valid=false;
                        msg='For bandpass/stop/notch, the cutoff should have two elements';
                        return;
                    end 

                otherwise
                    is_valid=false;
                    msg=('Unknown filter type');
                    return;
            end
            
        end
        function this= design(this)
            % Design a filter
            % 
            %
            [is_valid,msg]=this.validate();
            if(~is_valid)
                error(msg)
            end

            switch(this.method)
                case this.METHOD_BUTTER
                    this=this.butter();
                otherwise
                    error('Unknown method: %s',this.method);
            end
        end        

        function show(this)
            % Display the filter
            fvtool(this.B,this.A,'Fs',this.Fs);
        end

        function Y=filter(this,X,zero_phase)
            % Apply the designed filter
            % [INPUT]
            % X array<float>: input column or row vector.
            % zero_phase boolean: When true filtfilt will be used. Note
            %   that filtfilt results in doubling the original filter
            %   order. The default is true.
            %   
            % [OUTPUT]
            % Y array<float>: Filtered X. Same  dimension as the X.
            if nargin < 3
                zero_phase=false;
            end

            if zero_phase
                Y=filtfilt(this.B,this.A,X);
            else
                Y=filter(this.B,this.A,X);
            end
        end
    end

    methods(Access=protected)
        function this=butter(this)
            % Design a Butterworth filter
            switch(this.type)
                case this.TYPE_NOTCH
                    F0=sum(this.freqCutoff)/2;% center freq in Hertz
                    BW=this.freqCutoff(2)-this.freqCutoff(1);% bandwidth in Hertz
                    Q=F0/BW; %quality factor
                    N=this.order;
                    d=fdesign.notch('N,F0,Q',N,F0,Q,this.Fs);
                    H=d.design('SystemObject',true);
                    [B1,A1]=sos2tf(H.SOSMatrix);

                    this.B=B1;
                    this.A=A1;
                otherwise
                    [B1,A1]=butter(this.order,2*this.freqCutoff/this.Fs,this.type);
                    this.B=B1;
                    this.A=A1;
            end
        end

    end
end

