function parsave_fp(file, fpLog) %#ok<INUSD>
%PARSAVE_FP  parfor-safe save of a fingerprint log (passed by value).
    save(file, 'fpLog', '-v7');
end
