function setup_paths_revs()
%SETUP_PATHS_REVS  Put the REVS cold-start component on the MATLAB path.
%   Adds this folder, its myFunctions/ and +bc/ package, and the repo-root
%   thirdparty/ (for the secp256k1 key-gen used by createVreq/generateVproj2).
%   Run once per session before opening MainAlgorithm.mlx.

here = fileparts(mfilename('fullpath'));
repoRoot = fileparts(here);

addpath(here);
addpath(fullfile(here, 'myFunctions'));
% +bc is a package folder — its PARENT must be on the path (do not add +bc itself)
addpath(here);
% third-party secp256k1 lives at the repo root (shared with the RUST code)
tp = dir(fullfile(repoRoot, 'thirdparty', 'secp256k1-*'));
if ~isempty(tp)
    addpath(fullfile(repoRoot, 'thirdparty', tp(1).name));
else
    warning(['secp256k1 not found under %s/thirdparty. createVreq/generateVproj2 ' ...
             'need it for key generation.'], repoRoot);
end
fprintf('REVS cold-start paths added. Open MainAlgorithm.mlx to run.\n');
end
