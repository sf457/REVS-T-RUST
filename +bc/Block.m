% Copyright 2018 The MathWorks, Inc
classdef Block < handle
    
    properties
        index
        timestamp
        data
        nonce
        hash
        previous_hash
    end
    
    methods
        function obj = Block(varargin)
            % index, prev_hash, timestamp, data, nonce, hash
            if nargin == 1
                obj.index = varargin{1}.index;
                obj.timestamp = varargin{1}.timestamp;
                obj.data = varargin{1}.data;
                %obj.data = varargin{1}.data;
                obj.nonce = uint32(varargin{1}.nonce);
                assert(isa(obj.nonce, 'uint32'));
                obj.hash = varargin{1}.hash;
                obj.previous_hash = varargin{1}.previous_hash;                
            elseif nargin == 6
                obj.index = varargin{1};
                obj.timestamp = varargin{3};
                obj.data = varargin{4};
                obj.hash = varargin{6};
                obj.nonce = varargin{5};
                assert(isa(obj.nonce, 'uint32'));
                obj.previous_hash = varargin{2};
            else
                error('Block creation requires either struct input or six input arguments.');
            end
        end
       
    end
end