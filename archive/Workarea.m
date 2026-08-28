blockchainObj2 = Blockchain();
struct_data= Vreq;
data = struct_data;
data_json = jsonencode(data);
 
nonce = uint32(123); % Some nonce value
block1 = blockchainObj2.add_block(data_json, nonce);

%data = strsplit(vehicles, ',');
 nonce = uint32(111); % Some nonce value
% newBlock2 = blockchainObj2.add_block(dataString, nonce);


print(blockchainObj2);

% % Accessing block properties
% disp(block1.index);
% disp(block1.timestamp);
 disp(block1.data);
 disp(data_json)
 disp(struct_data)
 whos data
 whos data_json
 whos struct_data
 whos tokens
% disp(block1.nonce);
% disp(block1.hash);
% disp(block1.previous_hash);
% function str = structToString(vehicles)
%     % Convert each field of the struct to a string
%     fields = fieldnames(vehicles);
%     values = struct2cell(vehicles);
%     str = '';
%     for i = 1:numel(fields)
%         field_str = sprintf('%s:%s;', fields{i}, string(values{i}));
%         str = [str, field_str];
%        disp(str)
%     end
% end