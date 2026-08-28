function generate_thesis_cumulative_malsel(resultsPath, outDir)
% GENERATE_THESIS_CUMULATIVE_MALSEL  Thesis-styled cumulative malicious-
% selection curve under moderate / behavioural phase-shift / 50% malicious.
% This is the thesis house-style counterpart of the journal Fig 9
% (journal_figures_v10/fig9_cumulative_malsel) and visualises the post-switch
% suppression argument that Section 5.8 reports numerically.
%
% No invented data: cumulative malicious selections at run t are read directly
% from the per-round trajectory matrices of the frozen run,
%   te.wasSelected  (providers x runs)  AND  te.isMalicious (providers x 1),
% via  cumMalSel(t) = sum_{s<=t} sum_p ( wasSelected(p,s) & isMalicious(p) ).
% All four models are self-contained in the same frozen run's trajectories/.
%
% Output: thesis/figures/fig_revst_cumulative.{pdf,png}
%
% Usage
%   generate_thesis_cumulative_malsel
%   generate_thesis_cumulative_malsel('results/2026-06-05_23-23','thesis/figures')

    if nargin < 1 || isempty(resultsPath), resultsPath = 'results/2026-06-05_23-23'; end
    if nargin < 2 || isempty(outDir),      outDir      = fullfile('thesis','figures'); end
    if ~exist(outDir,'dir'), mkdir(outDir); end

    BLUE=[0.129 0.400 0.674]; ORANGE=[0.85 0.55 0.13];
    GREY=[0.40 0.40 0.40];    RED=[0.70 0.20 0.20];

    % {display label, mat basename, colour, line style, width}
    % Display labels follow the Chapter 5 convention (RUST_V2 = integrated framework).
    spec = { ...
        'Integrated framework', 'RUST_V2',      BLUE,   '-',  2.2; ...
        'Threshold',            'Threshold',    ORANGE, '--', 1.8; ...
        'Beta (BRS)',           'BetaUniform',  GREY,   ':',  1.8; ...
        '3VSL-Binary',          'x3VSL_Binary', RED,    '-.', 1.8 };

    switchRun = 500;
    nT = 1001;                  % runs 0..1000
    t  = 0:(nT-1);
    nModels = size(spec,1);
    curves = nan(nT,nModels);

    for k = 1:nModels
        matFile = fullfile(resultsPath,'trajectories', ...
            sprintf('trustEvolution_%s_moderate_firsthalf_mal50.mat', spec{k,2}));
        if ~exist(matFile,'file')
            warning('Missing trajectory for %s: %s', spec{k,1}, matFile); continue;
        end
        curves(:,k) = readCumMalSel(matFile, nT);
        fprintf('  %-22s final cumulative malicious selections = %d\n', ...
                spec{k,1}, round(curves(end,k)));
    end

    fig = figure('Position',[100 100 760 460],'Color','w');
    ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    for k = 1:nModels
        if all(isnan(curves(:,k))), continue; end
        plot(ax,t,curves(:,k),spec{k,4},'Color',spec{k,3}, ...
             'LineWidth',spec{k,5},'DisplayName',spec{k,1});
    end
    yl = ylim(ax);
    plot(ax,[switchRun switchRun],yl,'--','Color',[0.5 0.5 0.5], ...
         'LineWidth',1.1,'HandleVisibility','off');
    text(ax,switchRun+8,yl(2)*0.06,'phase-2 switch (run 501)', ...
         'FontSize',8,'Color',[0.4 0.4 0.4],'HorizontalAlignment','left');
    xlabel(ax,'simulation run'); ylabel(ax,'cumulative malicious selections');
    xlim(ax,[0 nT-1]); ylim(ax,yl);
    legend(ax,'Location','northwest','FontSize',9);
    saveFig(fig,outDir,'fig_revst_cumulative');

    fprintf('\nThesis cumulative-selection chart written to %s (PNG + vector PDF).\n',outDir);
end

function cum = readCumMalSel(matFile, nT)
    cum = nan(nT,1);
    S = load(matFile);
    if ~isfield(S,'trustEvolution'), warning('no trustEvolution in %s',matFile); return; end
    te = S.trustEvolution;
    isMal = te.isMalicious(:);
    wasSelMal = te.wasSelected .* repmat(isMal,1,size(te.wasSelected,2));
    cm = cumsum(sum(wasSelMal,1));
    if numel(cm) == nT
        cum = cm(:);
    else                                   % resample onto 0..nT-1 if needed
        cum = interp1(te.timeSteps(:)', cm, 0:(nT-1), 'linear','extrap')';
    end
end

function saveFig(fig,outDir,base)
    print(fig,fullfile(outDir,[base '.png']),'-dpng','-r200');
    try, exportgraphics(fig,fullfile(outDir,[base '.pdf']),'ContentType','vector');
    catch, print(fig,fullfile(outDir,[base '.pdf']),'-dpdf','-bestfit'); end
    fprintf('saved: %s\n',base); close(fig);
end
