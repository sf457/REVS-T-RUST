function setup_paths()
%SETUP_PATHS  Put all REVS-T with RUST source folders on the MATLAB path.
%
%   Call once per session, from any working directory, before running
%   run_baseline_comparison or the generate_thesis_* figure scripts:
%
%       >> setup_paths
%       >> run_baseline_comparison
%
%   This replaces the former addpath('myFunctions') and additionally adds the
%   third-party secp256k1 utility, which the earlier layout assumed was already
%   on the MATLAB saved path.
    root = fileparts(mfilename('fullpath'));
    addpath(root);                                   % entry scripts + +bc package parent (bc.*)
    addpath(fullfile(root, 'config'));               % Params.m
    addpath(genpath(fullfile(root, 'src')));         % reputation / selection / contracts / simulation / support
    addpath(genpath(fullfile(root, 'thirdparty')));  % secp256k1 key-pair generation
end
