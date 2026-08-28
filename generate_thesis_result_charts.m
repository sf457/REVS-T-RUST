function generate_thesis_result_charts(resultsPath, outDir)
% GENERATE_THESIS_RESULT_CHARTS  MATLAB replacements for the inline
% TikZ/pgfplots RESULT charts in Chapters 4 and 5. Reads the frozen
% baseline_comparison.csv (no invented data) and writes vector PDF + PNG into
% thesis/figures, matching the house style of generate_thesis_chapter_figures.m.
%
% Result charts produced (these REPLACE pgfplots blocks in the chapters):
%   fig_rust_mar_bars               (Ch4 4.5)  MAR at 50% moderate/persistent, 6 models
%                                              -> replaces the fig:rust_mar_50 pgfplots block
%   fig_revst_persistent_ablation   (Ch5 5.2)  SR+MAR ablation bars, moderate/persistent/50
%                                              -> replaces the fig:revst_persistent_ablation pgfplots block
%   fig_revst_phaseshift_adaptation (Ch5 5.4)  P2-selections + RTB, moderate/phase-shift/50
%                                              -> replaces the fig:revst_phaseshift_adaptation pgfplots block
%
% Conceptual diagrams (RUST workflow, evidence-to-opinion, DH routing, the
% draw.io lifecycle/cascade) are NOT touched: TikZ/draw.io is correct for those.
%
% Usage
%   generate_thesis_result_charts
%   generate_thesis_result_charts('results/2026-06-05_23-23','thesis/figures')

    if nargin < 1 || isempty(resultsPath), resultsPath = 'results/2026-06-05_23-23'; end
    if nargin < 2 || isempty(outDir),      outDir      = fullfile('thesis','figures'); end
    if ~exist(outDir,'dir'), mkdir(outDir); end

    BLUE=[0.129 0.400 0.674]; ORANGE=[0.85 0.55 0.13];
    TEAL=[0.10 0.52 0.50];    VIOLET=[0.50 0.30 0.65];

    T = readtable(fullfile(resultsPath,'baseline_comparison.csv'),'TextType','string');
    function v = pick(model,att,pct,col)   % scalar lookup from the frozen table
        row = T(T.Assignment=="moderate" & T.AttackType==att & T.Model==model & T.MaliciousPct==pct,:);
        v = row.(col)(1);
    end

    %% Fig A: fig_rust_mar_bars  (Ch4 4.5) -- 6-model MAR snapshot, moderate/persistent/50
    rawA  = ["Threshold-NoTierSel","Threshold-MaxRep","3VSL-Binary","Beta (BRS)","ScalarRep-CumReward","ScalarRep-EMA"];
    dispA = {"RUST","Th.-MaxRep","3VSL-Binary","Beta","ScalarRep-CumRew","ScalarRep-EMA"};
    marA  = arrayfun(@(m) pick(m,"always",50,"MAR"), rawA);
    fig = figure('Position',[100 100 720 400],'Color','w'); ax=axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    b = bar(ax,marA,0.6,'FaceColor',ORANGE,'EdgeColor',ORANGE*0.8);
    xticks(ax,1:numel(dispA)); xticklabels(ax,dispA); xtickangle(ax,22);
    ylim(ax,[70 100]); ylabel(ax,'malicious avoidance rate (%)');
    text(ax,1:numel(marA),marA+1.2,compose('%.2f',marA),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);
    saveFig(fig,outDir,'fig_rust_mar_bars');

    %% Fig B: fig_revst_persistent_ablation  (Ch5 5.2) -- SR+MAR grouped bars
    rawB  = ["RUST","RUST-Uniform","Threshold","Threshold-NoTierSel","Threshold-MaxRep"];
    dispB = {"Integrated","Uniform","Threshold","Th.-NoTierSel","Th.-MaxRep"};
    srB  = arrayfun(@(m) pick(m,"always",50,"SuccessRate"), rawB);
    marB = arrayfun(@(m) pick(m,"always",50,"MAR"),         rawB);
    fig = figure('Position',[100 100 760 420],'Color','w'); ax=axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    bb = bar(ax,[srB(:) marB(:)],1.0); bb(1).FaceColor=BLUE; bb(2).FaceColor=ORANGE;
    xticks(ax,1:numel(dispB)); xticklabels(ax,dispB); xtickangle(ax,20);
    ylim(ax,[80 100]); ylabel(ax,'rate (%)');
    text(ax,bb(1).XEndPoints,srB(:)'+0.5,compose('%.1f',srB(:)'),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7);
    text(ax,bb(2).XEndPoints,marB(:)'+0.5,compose('%.1f',marB(:)'),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',7);
    legend(ax,{'Success rate (SR)','Malicious avoidance rate (MAR)'},'Location','southoutside','Orientation','horizontal');
    saveFig(fig,outDir,'fig_revst_persistent_ablation');

    %% Fig C: fig_revst_phaseshift_adaptation  (Ch5 5.4) -- P2 selections + RTB
    rawC  = ["RUST","RUST-NoDH","RUST-Uniform","Threshold"];
    dispC = {"Integrated","NoDH","Uniform","Threshold"};
    p2  = arrayfun(@(m) pick(m,"firsthalf",50,"MalSelected_Phase2"), rawC);
    rtb = arrayfun(@(m) pick(m,"firsthalf",50,"RunsToDetect"),       rawC);
    fig = figure('Position',[100 100 820 380],'Color','w');
    t = tiledlayout(fig,1,2,'Padding','compact','TileSpacing','compact');
    ax1 = nexttile(t); hold(ax1,'on'); box(ax1,'on'); grid(ax1,'on');
    bar(ax1,p2,0.6,'FaceColor',TEAL,'EdgeColor',TEAL*0.8);
    xticks(ax1,1:4); xticklabels(ax1,dispC); xtickangle(ax1,20);
    ylabel(ax1,'post-switch malicious selections (P2)'); ylim(ax1,[0 80]);
    text(ax1,1:4,p2+1.5,compose('%.1f',p2),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);
    title(ax1,'(a) post-switch malicious selections (lower is better)','FontWeight','normal','FontSize',9);
    ax2 = nexttile(t); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    bar(ax2,rtb,0.6,'FaceColor',VIOLET,'EdgeColor',VIOLET*0.8);
    xticks(ax2,1:4); xticklabels(ax2,dispC); xtickangle(ax2,20);
    ylabel(ax2,'runs to first blacklist (RTB)'); ylim(ax2,[0 260]);
    text(ax2,1:4,rtb+6,compose('%.1f',rtb),'HorizontalAlignment','center','VerticalAlignment','bottom','FontSize',8);
    title(ax2,'(b) governance response latency (lower is faster)','FontWeight','normal','FontSize',9);
    saveFig(fig,outDir,'fig_revst_phaseshift_adaptation');

    %% Fig D: fig_rust_sr_ratio  (Ch4 Fig 4.x) -- 6-model SR vs malicious ratio,
    %% moderate assignment, persistent attack. Replaces the single-curve PDF so
    %% the figure matches a multi-curve caption. "RUST" = Threshold-NoTierSel
    %% (the operational RUST update configuration of Chapter 4).
    pen   = [0 10 30 50];
    rawD  = ["Threshold-NoTierSel","Threshold-MaxRep","3VSL-Binary","Beta (BRS)","ScalarRep-CumReward","ScalarRep-EMA"];
    dispD = {"RUST (Threshold-NoTierSel)","Th.-MaxRep","3VSL-Binary","Beta (BRS)","ScalarRep-CumRew","ScalarRep-EMA"};
    mk    = {'-o','-s','-^','-d','-v','-p'};
    colsD = {[0.106 0.471 0.216],[0.20 0.40 0.70],[0.85 0.55 0.13],[0.55 0.35 0.65],[0.40 0.40 0.40],[0.70 0.20 0.20]};
    fig = figure('Position',[100 100 740 460],'Color','w'); ax=axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    srvAll = zeros(numel(rawD),numel(pen));
    for m = 1:numel(rawD)
        srv = arrayfun(@(p) pick(rawD(m),"always",p,"SuccessRate"), pen);
        srvAll(m,:) = srv;
        plot(ax,pen,srv,mk{m},'Color',colsD{m},'LineWidth',1.8,'MarkerFaceColor',colsD{m},'MarkerSize',6,'DisplayName',dispD{m});
    end
    % improvement bracket at 50%: RUST (row 1) vs strongest external, 3VSL-Binary (row 3)
    yhi = srvAll(1,end); ylo = srvAll(3,end); xb = 51.5;
    plot(ax,[xb xb],[ylo yhi],'-','Color',[0.2 0.2 0.2],'LineWidth',1.1,'HandleVisibility','off');
    plot(ax,[xb-0.9 xb],[yhi yhi],'-','Color',[0.2 0.2 0.2],'LineWidth',1.1,'HandleVisibility','off');
    plot(ax,[xb-0.9 xb],[ylo ylo],'-','Color',[0.2 0.2 0.2],'LineWidth',1.1,'HandleVisibility','off');
    text(ax,xb+0.8,(yhi+ylo)/2,sprintf('%.1f pts',yhi-ylo),'Rotation',90, ...
         'HorizontalAlignment','center','VerticalAlignment','middle','FontSize',8,'Clipping','off');
    xlabel(ax,'malicious penetration (%)'); ylabel(ax,'success rate (%)');
    xticks(ax,pen); xlim(ax,[-2 56]); ylim(ax,[70 100]);
    legend(ax,'Location','southwest','FontSize',8);
    saveFig(fig,outDir,'fig_rust_sr_ratio');

    %% Fig E: fig_revst_ablation_chain  (Ch5 5.2) -- component ablation chain,
    %% moderate/persistent/50. SR stays ~flat across the four-tier single-
    %% component ablations, then steps down for the single-threshold family,
    %% while MAR tracks. Plots Table 5.2 (tab:revst_ablation), 8 configs in
    %% the ordered ablation-chain sequence.
    rawE  = ["RUST","RUST-NoRec","RUST-NoTier","RUST-NoDH","RUST-Uniform","Threshold","Threshold-NoTierSel","Threshold-MaxRep"];
    dispE = {"Integrated","NoRec","NoTier","NoDH","Uniform","Threshold","Th.-NoTierSel","Th.-MaxRep"};
    srE  = arrayfun(@(m) pick(m,"always",50,"SuccessRate"), rawE);
    marE = arrayfun(@(m) pick(m,"always",50,"MAR"),         rawE);
    fig = figure('Position',[100 100 820 440],'Color','w'); ax=axes(fig); hold(ax,'on'); box(ax,'on'); grid(ax,'on');
    plot(ax,1:numel(rawE),srE,'-o','Color',BLUE,'LineWidth',2.0,'MarkerFaceColor',BLUE,'MarkerSize',6,'DisplayName','Success rate (SR)');
    plot(ax,1:numel(rawE),marE,'--s','Color',ORANGE,'LineWidth',2.0,'MarkerFaceColor',ORANGE,'MarkerSize',6,'DisplayName','Malicious avoidance rate (MAR)');
    % family separator: four-tier governance (1-5) vs single-threshold (6-8)
    plot(ax,[5.5 5.5],[80 100],':','Color',[0.5 0.5 0.5],'LineWidth',1.1,'HandleVisibility','off');
    text(ax,3.0,99.4,'four-tier governance','HorizontalAlignment','center','FontSize',8,'Color',[0.4 0.4 0.4]);
    text(ax,7.0,99.4,'single-threshold','HorizontalAlignment','center','FontSize',8,'Color',[0.4 0.4 0.4]);
    xticks(ax,1:numel(dispE)); xticklabels(ax,dispE); xtickangle(ax,20);
    ylim(ax,[80 100]); xlim(ax,[0.5 numel(rawE)+0.5]); ylabel(ax,'rate (%)');
    legend(ax,'Location','southwest','FontSize',8);
    saveFig(fig,outDir,'fig_revst_ablation_chain');

    fprintf('\nFive MATLAB result charts written to %s (PNG + vector PDF).\n',outDir);
    fprintf('Replace the pgfplots figure blocks with \\includegraphics of these PDFs.\n');
    fprintf('Note: fig_rust_sr_ratio here is the moderate 6-model curve; it supersedes\n');
    fprintf('the Xu single-curve fig_rust_sr_ratio in generate_thesis_chapter_figures.m.\n');
end

function saveFig(fig,outDir,base)
    print(fig,fullfile(outDir,[base '.png']),'-dpng','-r200');
    try, exportgraphics(fig,fullfile(outDir,[base '.pdf']),'ContentType','vector');
    catch, print(fig,fullfile(outDir,[base '.pdf']),'-dpdf','-bestfit'); end
    fprintf('saved: %s\n',base); close(fig);
end
