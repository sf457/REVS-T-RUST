function generate_thesis_chapter_figures(resultsPath, outDir)
% GENERATE_THESIS_CHAPTER_FIGURES  All SIX thesis-chapter figures, in one
% folder (default thesis/figures), generated from the frozen v10 run.
% MATLAB-canonical twin of generate_thesis_chapter_figures.py. Distinct from
% generate_thesis_figures.m (the batch per-scenario tool) and from the JOURNAL
% figures (fig4..fig9) in results/<run>/journal_figures_v10.
%
% Produces PNG + vector PDF:
%   fig_rust_sr_ratio_xu (Ch4)      Xu-aligned RUST SR vs malicious ratio        [baseline_comparison.csv]
%   fig_rust_trajectory  (Ch4)      Xu-aligned reputation trajectories            [trustEvolution_RUST_V2_xu_aligned_always_mal50]
%   fig_eval_streak      (Ch5 5.3)  moderate on-off warning-streak                [..._moderate_onoff_mal50]
%   fig_eval_perst       (Ch5 5.7)  per-ST honest reputation convergence          [..._moderate_always_mal50]
%
% NOTE: fig_eval_phaseshift (Ch5 5.4) is now the four-provider two-panel
% reputation-trace figure produced by generate_thesis_phaseshift_traces.m
% (RUST vs Threshold-MaxRep). The former single-betrayer selection variant that
% used to live here was retired so the two scripts do not clobber the same PDF.
%
% Usage
%   generate_thesis_chapter_figures
%   generate_thesis_chapter_figures('results/2026-06-05_23-23')
%   generate_thesis_chapter_figures('results/2026-06-05_23-23','thesis/figures')

    if nargin < 1 || isempty(resultsPath), resultsPath = 'results/2026-06-05_23-23'; end
    if nargin < 2 || isempty(outDir),      outDir      = fullfile('thesis','figures'); end
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    R_min = 0.41; R_warn = 0.50; R_boost = 0.70;
    GREEN = [0.106 0.471 0.216]; RED = [0.698 0.094 0.169];
    BLUE  = [0.129 0.400 0.674]; GOLD = [0.722 0.525 0.043];

    %% Fig 1: fig_rust_sr_ratio
    T = readtable(fullfile(resultsPath,'baseline_comparison.csv'),'TextType','string');
    pen = [0 10 30 50]; sr = zeros(size(pen));
    for i = 1:numel(pen)
        r = T(T.Assignment=="xu_aligned" & T.AttackType=="always" & T.Model=="RUST" & T.MaliciousPct==pen(i),:);
        sr(i) = r.SuccessRate(1);
    end
    fig = figure('Position',[100 100 620 400],'Color','w'); ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    plot(ax,pen,sr,'-o','Color',GREEN,'LineWidth',2.2,'MarkerFaceColor',GREEN,'MarkerSize',7,'DisplayName','RUST');
    for i = 1:numel(pen), text(ax,pen(i),sr(i)+0.35,sprintf('%.2f',sr(i)),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',9); end
    xlabel(ax,'malicious penetration (%)'); ylabel(ax,'success rate (%)');
    xticks(ax,pen); xlim(ax,[-2 52]); ylim(ax,[92 98]); legend(ax,'Location','southwest','FontSize',9);
    saveFig(fig,outDir,'fig_rust_sr_ratio_xu'); fprintf('SR(xu): %.2f %.2f %.2f %.2f\n',sr);

    %% Fig 2: fig_rust_trajectory
    te = loadTE(resultsPath,'RUST_V2_xu_aligned_always_mal50');
    st = lower(string(te.socialTrustLevel(:))); mal = te.isMalicious(:)==1;
    rep = te.reputation; sel = te.wasSelected; Tn = size(rep,2); x = 0:(Tn-1);
    hh = find(st=="high" & ~mal); [~,j] = max(rep(hh,end)); hidx = hh(j);
    ml = find(st=="low" & mal & sum(sel,2)>0); [~,j] = min(min(rep(ml,:),[],2)); midx = ml(j);
    tfail = find(sel(midx,:)>0,1);
    fig = figure('Position',[100 100 720 440],'Color','w'); ax = axes(fig); hold(ax,'on'); box(ax,'on');
    drawBands(ax,Tn,R_min,R_warn,R_boost);
    h1 = plot(ax,x,rep(hidx,:),'Color',GREEN,'LineWidth',2.2);
    h2 = plot(ax,x,rep(midx,:),'Color',RED,'LineWidth',2.2);
    plot(ax,tfail-1,rep(midx,tfail),'v','Color',RED,'MarkerFaceColor',RED,'MarkerSize',9);
    text(ax,tfail-1+14,rep(midx,tfail)-0.012,'excluded on first failure','FontSize',9,'Color',RED);
    legend(ax,[h1 h2],{'honest High-ST provider','malicious Low-ST provider'},'Location','east','FontSize',9);
    xlabel(ax,'offloading request index'); ylabel(ax,'projected reputation R_j');
    ylim(ax,[0.30 0.85]); xlim(ax,[0 Tn-1]); saveFig(fig,outDir,'fig_rust_trajectory');

    %% Fig 3: fig_eval_streak
    te = loadTE(resultsPath,'RUST_V2_moderate_onoff_mal50');
    mal = te.isMalicious(:)==1; ws = te.warningStreak; Tn = size(ws,2); x = 0:(Tn-1);
    mi = find(mal); [peak,j] = max(max(ws(mi,:),[],2)); pidx = mi(j); streak = ws(pidx,:);
    bl = find(streak(1:end-1)>=2 & streak(2:end)<=1.0);
    fig = figure('Position',[100 100 720 400],'Color','w'); ax = axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    plot(ax,[0 Tn-1],[2 2],'--','Color',RED,'LineWidth',1.0);
    text(ax,(Tn-1)*0.995,2.04,'Warning  L_{esc}=2','HorizontalAlignment','right','FontSize',8,'Color',RED);
    if peak>=2.5
        plot(ax,[0 Tn-1],[3 3],'--','Color',GOLD,'LineWidth',1.0);
        text(ax,(Tn-1)*0.995,3.04,'Stable  L_{esc}=3','HorizontalAlignment','right','FontSize',8,'Color',GOLD);
    end
    h1 = plot(ax,x,streak,'Color',BLUE,'LineWidth',1.6);
    h2 = plot(ax,bl,2*ones(size(bl)),'o','Color',RED,'MarkerFaceColor',RED,'MarkerSize',6);
    legend(ax,[h1 h2],{'on-off provider warning streak','escalation \rightarrow blackout'},'Location','southoutside','Orientation','horizontal','FontSize',9);
    xlabel(ax,'offloading request index'); ylabel(ax,'warning streak \rho_j');
    xlim(ax,[0 Tn-1]); ylim(ax,[0 max(3.2,peak+0.4)]); saveFig(fig,outDir,'fig_eval_streak');

    %% Fig 4: fig_eval_phaseshift is now produced by
    %% generate_thesis_phaseshift_traces.m (four-provider two-panel reputation
    %% traces, RUST vs Threshold-MaxRep). Run that script separately.

    %% Fig 5: fig_eval_perst
    te = loadTE(resultsPath,'RUST_V2_moderate_always_mal50');
    st = lower(string(te.socialTrustLevel(:))); mal = te.isMalicious(:)==1; rep = te.reputation; Tn = size(rep,2); x = 0:(Tn-1);
    classes = {'high','intermediate','low'}; cols = {GREEN,GOLD,RED};
    labs = struct('high','High','intermediate','Intermediate','low','Low');
    fig = figure('Position',[100 100 720 440],'Color','w'); ax = axes(fig); hold(ax,'on'); box(ax,'on');
    drawBands(ax,Tn,R_min,R_warn,R_boost);
    h = gobjects(1,3); lg = strings(1,3);
    for c = 1:3
        idx = find(st==classes{c} & ~mal); if isempty(idx), continue; end
        mr = mean(rep(idx,:),1);
        q25 = prctileCols(rep(idx,:),25); q75 = prctileCols(rep(idx,:),75);
        fill(ax,[x fliplr(x)],[q25 fliplr(q75)],cols{c},'FaceAlpha',0.12,'EdgeColor','none');
        h(c) = plot(ax,x,mr,'Color',cols{c},'LineWidth',2.0);
        lg(c) = sprintf('%s-ST honest (n=%d, R_0=%.3f)',labs.(classes{c}),numel(idx),mr(1));
    end
    legend(ax,h,cellstr(lg),'Location','east','FontSize',8);
    xlabel(ax,'offloading request index'); ylabel(ax,'mean projected reputation R_j');
    ylim(ax,[0.30 0.85]); xlim(ax,[0 Tn-1]); saveFig(fig,outDir,'fig_eval_perst');

    fprintf('\nFour thesis figures written to %s (PNG + vector PDF).\n',outDir);
end

% --------------------------------------------------------------------------
function te = loadTE(resultsPath, scenario)
    f = fullfile(resultsPath,'trajectories',sprintf('trustEvolution_%s.mat',scenario));
    if ~exist(f,'file'), error('Trajectory MAT not found: %s', f); end
    S = load(f); te = S.trustEvolution;
end
function drawBands(ax,T,R_min,R_warn,R_boost)
    fill(ax,[0 T-1 T-1 0],[0.30 0.30 R_min R_min],[0.992 0.878 0.878],'EdgeColor','none');
    fill(ax,[0 T-1 T-1 0],[R_min R_min R_warn R_warn],[1.0 0.957 0.839],'EdgeColor','none');
    fill(ax,[0 T-1 T-1 0],[R_warn R_warn R_boost R_boost],[0.890 0.949 0.882],'EdgeColor','none');
    fill(ax,[0 T-1 T-1 0],[R_boost R_boost 0.85 0.85],[0.804 0.925 0.788],'EdgeColor','none');
    nm = {'min','warn','boost'}; vv = [R_min R_warn R_boost];
    for k = 1:3
        yv = vv(k); plot(ax,[0 T-1],[yv yv],'--','Color',[0.4 0.4 0.4],'LineWidth',0.8);
        text(ax,(T-1)*0.985, yv-0.016, sprintf('R_{%s} = %.2f',nm{k},yv), ...
             'HorizontalAlignment','right','VerticalAlignment','top','FontSize',8, ...
             'Color',[0.3 0.3 0.3],'Clipping','off');
    end
end
function q = prctileCols(M,p)
    if size(M,1)==1, q = M; return; end
    S = sort(M,1); n = size(S,1); pos = min(max((p/100)*n+0.5,1),n);
    lo = floor(pos); hi = ceil(pos); fr = pos-lo; q = S(lo,:).*(1-fr)+S(hi,:).*fr;
end
function gbox(ax,x,y,w,h,txt,fc)
    rectangle(ax,'Position',[x-w/2 y-h/2 w h],'Curvature',0.25,'FaceColor',fc,'EdgeColor',[0.3 0.3 0.3],'LineWidth',1.2);
    text(ax,x,y,txt,'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',9);
end
function garrow(ax,x1,y1,x2,y2,lab)
    quiver(ax,x1,y1,x2-x1,y2-y1,0,'Color',[0.3 0.3 0.3],'LineWidth',1.3,'MaxHeadSize',0.6,'AutoScale','off');
    if ~isempty(lab), text(ax,(x1+x2)/2+0.12,(y1+y2)/2+0.18,lab,'FontSize',8.5,'Color',[0.25 0.25 0.25]); end
end
function saveFig(fig,outDir,base)
    print(fig,fullfile(outDir,[base '.png']),'-dpng','-r200');
    try, exportgraphics(fig,fullfile(outDir,[base '.pdf']),'ContentType','vector');
    catch, print(fig,fullfile(outDir,[base '.pdf']),'-dpdf','-bestfit'); end
    fprintf('saved: %s\n',base); close(fig);
end
