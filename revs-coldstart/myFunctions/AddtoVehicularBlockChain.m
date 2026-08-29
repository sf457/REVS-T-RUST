function Vehicularblockchain = AddtoVehicularBlockChain(vehicles, Vehicularblockchain,blockchainObj)
    % Initialize the blockchain object if not provided
    if isempty(Vehicularblockchain)
        blockchainObj = bc.vBlockchain();
        Vehicularblockchain = blockchainObj.blockchain;
    end
    
    % Add vehicle information to the blockchain
    for i = 1:length(vehicles)
        data = vehicles(i);
        % Generate a random nonce within a reasonable range
        nonce = randi([0, 2^32 - 1], 1, 'uint32');
        Vehicularblockchain = [Vehicularblockchain, blockchainObj.add_block(data, nonce)];
    end

    % % Display the blockchain
    % disp('Vehicular Blockchain:');
    % disp(['Number of blocks in Vehicularblockchain: ', num2str(numel(Vehicularblockchain))]);
    %blockchainObj.print();
end