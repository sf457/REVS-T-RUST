% Copyright 2018 The MathWorks, Inc
classdef Blockchain < handle
    
    properties
        blockchain
    end
    
    methods
        function obj = Blockchain()
            obj.blockchain = bc.Blockchain.genesis_block(30, 50, 2);
        end
        % 
        % function block = add_block(obj, data, nonce)
        %     assert(isa(nonce, 'uint32'));
        %     index = numel(obj.blockchain) + 1;
        %     prev_hash = obj.blockchain(end).hash;
        %     timestamp = char(datetime);
        %     hash = bc.Blockchain.calculate_hash(index, prev_hash, timestamp, nonce, data);
        %     block = bc.Block(index, prev_hash, timestamp, data, nonce, hash);
        %     obj.blockchain(end+1) = block;          
        % end
        function block = add_block(obj, data)
    index = numel(obj.blockchain) + 1;
    prev_hash = obj.blockchain(end).hash;
    timestamp = char(datetime);
    nonce = uint32(0); % Initial nonce value
    hash = '';
    
    % Find a valid nonce by incrementing until a valid hash is obtained
    while ~startsWith(hash, '0000') % Example condition for a valid hash
        nonce = nonce + 1;
        hash = bc.Blockchain.calculate_hash(index, prev_hash, timestamp, nonce, data);
    end
    
    block = bc.Block(index, prev_hash, timestamp, data, nonce, hash);
    obj.blockchain(end+1) = block;          
end

        function added = add_mined_block(obj, block)
            assert(isa(block, 'bc.Block'));
            
            valid = bc.Blockchain.validate_block(block, obj.blockchain(end));
            if valid
                obj.blockchain(end+1) = block;   
                added = true;
            else
                added = false;
            end       
        end
        
        function rv = replace_blockchain(obj, new_blockchain)            
            valid = bc.Blockchain.validate_chain(new_blockchain);
            if ~valid
                rv = p2p.MessageType.DO_NOTHING;
                return;
            end           
            if numel(new_blockchain) > numel(obj.blockchain)
                obj.blockchain = new_blockchain;
                rv = p2p.MessageType.BROADCAST_LATEST;
            end
        end
        
        function print(obj)
            fprintf('\n=================================\n');
            for idx=1:numel(obj.blockchain)
                fprintf('index: %d\n', obj.blockchain(idx).index); 
                fprintf('timestamp: %s\n', obj.blockchain(idx).timestamp);
                %fprintf('data: %s\n', obj.blockchain(idx).data);
                disp(obj.blockchain(idx).data);
                fprintf('nonce: %d\n', obj.blockchain(idx).nonce);
                
               % fprintf('hash: %s\n', obj.blockchain(idx).hash);
                % Convert the hash value to hexadecimal string
                hashHex = dec2hex(obj.blockchain(idx).hash);
               % Print the hexadecimal string
                 fprintf('hash: %s\n', hashHex);

                % Convert the previous_hash value to hexadecimal string
               prevHashHex = dec2hex(obj.blockchain(idx).previous_hash);
                % Print the hexadecimal string
               fprintf('previous_hash: %s\n', prevHashHex);

            end
            fprintf('=================================\n\n');
        end
        
        function rv = handle_blockchain_response(obj, mess)
            % Convert incoming message of strcut or array of struct
            % to array of blocks
            received_blockchain = bc.Block(mess(1));
            if numel(mess) > 1
                for idx = 2:numel(mess)
                    received_blockchain(end+1) = bc.Block(mess(idx));
                end
            end
            
            latest_block_received = received_blockchain(end);
            latest_block_held = obj.blockchain(end);
            rv = p2p.MessageType.DO_NOTHING;
            
            % If received latest block is not later than the local, do
            % nothing.
            if latest_block_received.index > latest_block_held.index
                if latest_block_held.hash == latest_block_received.previous_hash
                    % We can append the received block to our chain
                    % FIXME validate block
                    valid = bc.Blockchain.validate_block(latest_block_received, latest_block_held);
                    if valid
                        obj.blockchain(end+1) = latest_block_received;
                        rv = p2p.MessageType.BROADCAST_LATEST;    
                    end
                elseif numel(received_blockchain) == 1
                    % We have to query the chain from our peer
                    rv = p2p.MessageType.QUERY_ALL;
                else
                    % Received blockchain is longer than current blockchain
                    rv = obj.replace_blockchain(received_blockchain);
                end
                % Above only works if only one block or entire chain is
                % sent, which should be the case.
            end
        end
    end
    
    methods (Static = true)
        
        function gen = genesis_block()
            % FIXME mine the block for correct hash
            % Create genesis block
            index = 1; % Yes it is MATLAB
            prev_hash = char(0);
            %timestamp = '07-Dec-2017 01:19:33';
            timestamp = char(datetime('now'));
               %data=Vreqipool(1);
      data_structure = createVreqPool(30, 50, 2);    
%                        data.PID = 'Vreq1';
% data.resourcStatus = 0 ;% always 0
% data.reputation = rand; %randi([0, 1]);
% data.privateKey = randi([1, 1000]); % Replace with a secure private key
% data.publicKey = 123; % Replace with a corresponding public key
% data.timestamp= datetime('now');
% data.speed = randi([30, 120]);  % Random speed between 30 and 120 km/h
% data.direction = 'North';
% data.x=50;
% data.y=70;
% data.radius = randi([0, 100]); 
% data.RSU_ID = 1;
% data.RSU_location = [20, 20];
% data.RSU_range = 50;
           nonce = uint32(0);
            hash = char(uint8([159 253 165 212 162 203 121 5 144 7 7 212 3 29 209 119 128 39 5 152 71 69 214 107 142 245 155 146 123 159 164 236]));
            gen = bc.Block(index, prev_hash, timestamp, data_structure, nonce, hash); 
        end
        
        function valid = check_if_genesis(block)
            assert(isa(block, 'bc.Block'));          
            gen_str = ['1', char(0), '07-Dec-2017 01:19:33The origin0', char(uint8([159 253 165 212 162 203 121 5 144 7 7 212 3 29 209 119 128 39 5 152 71 69 214 107 142 245 155 146 123 159 164 236]))];
            blk_str = [num2str(block.index), block.previous_hash, block.timestamp, block.data, num2str(block.nonce) , block.hash];            
            if strcmp(gen_str, blk_str)
                valid = true;
                return;
            end
            valid = false;
        end
        
        function [sha256, uint8_sha256] = calculate_hash(index, prev_hash, timestamp, nonce, data)
            string = [num2str(index), prev_hash, timestamp, num2str(nonce), jsonencode(data)];
            sha256hasher = System.Security.Cryptography.SHA256Managed;
            uint8_sha256 = uint8(sha256hasher.ComputeHash(uint8(string)));
            sha256 = char(uint8_sha256); %consider the string as 8-bit characters
        end
        
        function valid = validate_chain(blockchain)
            valid_genesis = bc.Blockchain.check_if_genesis(blockchain(1));
            if ~valid_genesis
               valid = false;
               return;
            end
            
            temp_blockchain = blockchain(1);
            
            for idx=2:numel(blockchain)
                valid_blk = bc.Blockchain.validate_block(blockchain(idx), temp_blockchain(idx-1));
                if valid_blk
                    temp_blockchain(end+1) = blockchain(idx);
                else
                    valid = false;
                    return;
                end
            end
            valid = true; 
        end
        
        function valid = validate_block(new_block, prev_block)
            assert(isa(new_block, 'bc.Block'));
            assert(isa(prev_block, 'bc.Block'));
            
            % FIXME check for correct hash (with 0s)
            if ~(new_block.hash(1:2) == char(zeros(1,2)))
                valid = false;
                return;
            end
            
            if (prev_block.index+1) ~= new_block.index
                valid = false;
                return;
            end
            
            if ~strcmp(prev_block.hash, new_block.previous_hash)
                valid = false;
                return;
            end
            
            new_block_hash = bc.Blockchain.calculate_hash(new_block.index, ...
                new_block.previous_hash, new_block.timestamp, new_block.nonce, new_block.data);
            if ~strcmp(new_block.hash, new_block_hash)
                valid = false;
                return;
            end
            valid = true;
        end    
    end
end