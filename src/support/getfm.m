function v = getfm(s, f)
%GETFM  Safe scalar get from a metrics struct; NaN if absent/non-scalar.
    v = NaN;
    if isstruct(s) && isfield(s, f)
        x = s.(f);
        if (isnumeric(x) || islogical(x)) && isscalar(x)
            v = double(x);
        end
    end
end
