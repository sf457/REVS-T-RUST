function generate_thesis_phaseshift_traces(resultsPath, outDir)
% GENERATE_THESIS_PHASESHIFT_TRACES  Thesis-styled four-provider reputation-
% trace figure under behavioural phase shift (moderate / firsthalf / 50%),
% two panels: (a) RUST (integrated framework) vs (b) Threshold-MaxRep.
% This is the thesis house-style counterpart of journal Fig 8 and REPLACES the
% former single-betrayer selection figure under the name fig_eval_phaseshift.
%
% No invented data: trajectories, blackout intervals, and blacklist events are
% read directly from the frozen per-scenario trajectory MATs
%   trustEvolution_RUST_V2_moderate_firsthalf_mal50.mat
%   trustEvolution_Threshold_MaxRep_moderate_firsthalf_mal50.mat
% Provider selection mirrors the journal generator so the same four
% representative providers are shown: high-honest and intermediate-honest
% (highest total selection count), high-malicious and low-malicious (highest
% phase-1 selection count, i.e. the betrayers that built trust before the
% switch). The same PIDs are plotted in both panels for direct comparison.
%
% Output: thesis/figures/fig_eval_phaseshift.{pdf,png}
%
% Usage
%   generate_thesis_phaseshift_traces
%   generate_thesis_phaseshift_traces('results/2026-06-05_23-23','thesis/figures')

    if nargin < 1 || isempty(resultsPath), resultsPath = 'results/2026-06-05_23-23'; end
    if nargin < 2 || isempty(outDir),      outDir      = fullfile('thesis','figures'); end
    if ~exist(outDir,'dir'), mkdir(outDir); end

    R_min = 0.41; R_warn = 0.50; R_boost = 0.70; SW = 500;

    % House-style palette, by provider role (matches the journal semantics):
    % high-honest=green, int-honest=blue, high-malicious=red, low-malicious=brown
    GREEN=[0.106 0.471 0.216]; BLUE=[0.129 0.400 0.674];
    RED=[0.70 0.16 0.16];      BROWN=[0.50 0.36 0.18];
    palette = {GREEN, BLUE, RED, BROWN};

    teR = loadTE(resultsPath,'RUST_V2_moderate_firsthalf_mal50');
    teT = loadTE(resultsPath,'Threshold_MaxRep_moderate_firsthalf_mal50');

    repIdxR = pickReps(teR, SW);
    repIdxT = mapPIDs(teR, teT, repIdxR);
    labels  = traceLabels(teR, repIdxR);

    fig = figure('Position',[100 100 1080 460],'Color','w');
    tl = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');

    ax1 = nexttile(tl);
    plotPanel(ax1, teR, repIdxR, palette, labels, SW, R_min, R_warn, R_boost);
    title(ax1,'(a) RUST (integrated framework)','FontWeight','normal','FontSize',10);

    ax2 = nexttile(tl);
    plotPanel(ax2, teT, repIdxT, palette, labels, SW, R_min, R_warn, R_boost);
    title(ax2,'(b) Threshold-MaxRep','FontWeight','normal','FontSize',10);

    lg = legend(ax2, labels, 'Orientation','horizontal','FontSize',8.5);
    lg.Layout.Tile = 'south';
    xlabel(tl,'simulation run','FontSize',11);
    ylabel(tl,'projected reputation R_j(t)','FontSize',11);

    saveFig(fig,outDir,'fig_eval_phaseshift');
    fprintf('\nThesis phase-shift trace figure written to %s (PNG + vector PDF).\n',outDir);
end

% ---- data ---------------------------------------------------------------
function te = loadTE(resultsPath, scenario)
    f = fullfile(resultsPath,'trajectories',sprintf('trustEvolution_%s.mat',scenario));
    S = load(f);
    te = S.trustEvolution;
end

function repIdx = pickReps(te, SW)
    isMal = te.isMalicious(:); ST = te.socialTrustLevel(:);
    nT = size(te.wasSelected,2); p1End = min(SW,nT);
    p1 = sum(te.wasSelected(:,1:p1End),2);
    tot = sum(te.wasSelected,2);
    repIdx = nan(1,4);
    repIdx(1) = pickOne(ST,isMal,tot,'high',        false);
    repIdx(2) = pickOne(ST,isMal,tot,'intermediate',false);
    repIdx(3) = pickOne(ST,isMal,p1, 'high',        true);
    repIdx(4) = pickOne(ST,isMal,p1, 'low',         true);
end

function idx = pickOne(STcells,isMal,selCount,stTarget,malTarget)
    mask = strcmpi(STcells,stTarget) & (isMal==malTarget);
    if ~any(mask), idx = NaN; return; end
    cand = find(mask); [~,b] = max(selCount(cand)); idx = cand(b);
end

function repIdxT = mapPIDs(teR, teT, repIdxR)
    repIdxT = nan(size(repIdxR));
    for i = 1:numel(repIdxR)
        if isnan(repIdxR(i)), continue; end
        j = find(strcmp(teT.providerPIDs, teR.providerPIDs{repIdxR(i)}),1);
        if ~isempty(j), repIdxT(i) = j; end
    end
end

function labels = traceLabels(te, repIdx)
    role = {'high, honest','intermediate, honest','high, malicious','low, malicious'};
    labels = cell(1,numel(repIdx));
    for i = 1:numel(repIdx)
        if isnan(repIdx(i)), labels{i} = role{i}; continue; end
        labels{i} = sprintf('%s (%s)', te.providerPIDs{repIdx(i)}, role{i});
    end
end

% ---- plotting -----------------------------------------------------------
function plotPanel(ax, te, repIdx, palette, labels, SW, R_min, R_warn, R_boost)
    hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    t = te.timeSteps(:)';
    plot(ax,[SW SW],[0 1],'--','Color',[0.5 0.5 0.5],'LineWidth',1.1,'HandleVisibility','off');
    text(ax,SW+8,0.05,'phase switch','FontSize',8,'Color',[0.4 0.4 0.4]);
    drawRef(ax,t,R_min, [0.85 0.20 0.20],'R_{min}=0.41');
    drawRef(ax,t,R_warn,[0.90 0.50 0.20],'R_{warn}=0.50');
    drawRef(ax,t,R_boost,[0.30 0.65 0.30],'R_{boost}=0.70');
    for i = 1:numel(repIdx)
        if isnan(repIdx(i)), continue; end
        p = repIdx(i); R = te.reputation(p,:);
        notActive = te.isActive(p,:)==0;
        if any(notActive), shadeRuns(ax,t,notActive,palette{i},0.15); end
        plot(ax,t,R,'-','Color',palette{i},'LineWidth',1.7,'DisplayName',labels{i});
        bl = find(diff([0, te.totalBlacklists(p,:)>0])==1);
        if ~isempty(bl)
            plot(ax,t(bl),R(bl),'x','Color',palette{i},'MarkerSize',10, ...
                 'LineWidth',2,'HandleVisibility','off');
        end
    end
    ylim(ax,[0 1]); xlim(ax,[t(1) t(end)]);
end

function drawRef(ax,t,y,col,txt)
    plot(ax,[t(1) t(end)],[y y],':','Color',col,'LineWidth',1.0,'HandleVisibility','off');
    text(ax,t(end)*0.985,y+0.018,txt,'Color',col,'FontSize',7.5, ...
         'HorizontalAlignment','right','VerticalAlignment','bottom','Clipping','off');
end

function shadeRuns(ax,t,mask,col,alpha)
    mask = logical(mask(:)'); edges = diff([false mask false]);
    s = find(edges==1); e = find(edges==-1)-1; yl = [0 1];
    for k = 1:numel(s)
        patch(ax,[t(s(k)) t(e(k)) t(e(k)) t(s(k))],[yl(1) yl(1) yl(2) yl(2)], ...
              col,'FaceAlpha',alpha,'EdgeColor','none','HandleVisibility','off');
    end
end

function saveFig(fig,outDir,base)
    print(fig,fullfile(outDir,[base '.png']),'-dpng','-r200');
    try, exportgraphics(fig,fullfile(outDir,[base '.pdf']),'ContentType','vector');
    catch, print(fig,fullfile(outDir,[base '.pdf']),'-dpdf','-bestfit'); end
    fprintf('saved: %s\n',base); close(fig);
end
