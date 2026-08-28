function out = sensitivityState(action, key, value)
%SENSITIVITYSTATE  Persistent state for run_sensitivity_audit.
%
%   Workaround for run_baseline_comparison.m's
%       clearvars -except cfg
%   at script line 57, which wipes the caller's local variables after
%   every run() invocation. Function-persistent variables survive
%   because they live in the function's private memory, not the
%   caller's workspace.
%
%   Usage:
%     sensitivityState('set', 'baseDir', '/path/to/dir');
%     d = sensitivityState('get', 'baseDir');
%     sensitivityState('clear');

    persistent state
    if isempty(state); state = struct(); end
    if nargin < 1; out = state; return; end
    switch lower(action)
        case 'set'
            state.(key) = value;
            out = value;
        case 'get'
            if isfield(state, key)
                out = state.(key);
            else
                out = [];
            end
        case 'clear'
            state = struct();
            out = [];
        otherwise
            error('Unknown action: %s', action);
    end
end
