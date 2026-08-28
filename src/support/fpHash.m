function h = fpHash(v)
%FPHASH  Deterministic hex fingerprint (MD5) of a numeric or char value.
%   Order-sensitive on the input you give it. NaNs are mapped to a fixed
%   sentinel so they hash consistently. Used by the serial-vs-parallel
%   divergence forensic harness.
    if ischar(v) || isstring(v)
        bytes = uint8(char(v));
    else
        v = double(v(:)).';
        v(isnan(v)) = -realmax;          % consistent, hashable sentinel for NaN
        if isempty(v)
            bytes = uint8(0);
        else
            bytes = typecast(v, 'uint8');
        end
    end
    md  = java.security.MessageDigest.getInstance('MD5');
    dig = md.digest(bytes);              % Java byte[] -> int8 in MATLAB
    h   = lower(sprintf('%02x', typecast(int8(dig), 'uint8')));
end
