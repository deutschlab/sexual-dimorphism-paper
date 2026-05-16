% creating a layout for the fru/dsx network, using the 27 clusters made by Arie as nodes



%% create the connectivity table
version = 783;%Two neuropil where aadded to the neuropil list:
subversion = 'V15';

dataFolder = '/Users/ddeutsch/Dropbox/My Documents/MyOwnLab/Experiments/Connectomics/dsx_fru/Shared_dsxfru/data';
filename_dsxfru = fullfile(dataFolder,['Dsxfru_',num2str(version),'_',subversion,'.xlsx']);
filename_clusters = fullfile(dataFolder,['DsxFru_V15_Clusters','.xlsx']);
filename_connectivity = fullfile(dataFolder,'connections_princeton783.csv');

% read dsxfru table
opts = detectImportOptions(filename_dsxfru);
opts = setvartype(opts, 'cellID','string');
T_dsxfru = readtable(filename_dsxfru, opts, 'sheet','V15');

% read cluster table
T_clusters = readtable(filename_clusters);
ClusterNumber = T_clusters.ClusterNumber(1);
for nLine = 2:height(T_clusters)
    if isnan(T_clusters.ClusterNumber(nLine))
        T_clusters.ClusterNumber(nLine) = ClusterNumber;
    else
        ClusterNumber = T_clusters.ClusterNumber(nLine);
    end
end

% connectivity (using the Princeton synapses)
opts = detectImportOptions(filename_connectivity);
opts = setvartype(opts, 'pre_root_id','string');
opts = setvartype(opts, 'post_root_id','string');
T_connectivity = readtable(filename_connectivity, opts);

% add the column subtypes to T_dsxfru
for ii = 1:height(T_dsxfru)
    if ismember([T_dsxfru.synonym{ii},'-',T_dsxfru.cell_type{ii}],T_clusters.Subtypes)
        T_dsxfru.subtype{ii} = [T_dsxfru.synonym{ii},'-',T_dsxfru.cell_type{ii}];
    elseif ismember(T_dsxfru.synonym{ii},T_clusters.Subtypes)
        T_dsxfru.subtype{ii} = T_dsxfru.synonym{ii};
    else
        disp(T_dsxfru.synonym{ii})
    end
end

%% Create and save connectivity table (between clusters). Skip if updated E is already calculated.
% Create a new table. For each pair of clusters, get the number os
% synapses. For each cluster get the number of in and out synapses. Get
% weighted connections (SynapsesA_B)*Fraction_FromA*Fraction_ToB


CLUSTERS = max(T_clusters.ClusterNumber);
vInputSynapses = zeros(1,CLUSTERS);
vOutSynapses = zeros(1,CLUSTERS);
for nCluster = 1:CLUSTERS
    TYPES = T_clusters.Subtypes(T_clusters.ClusterNumber==nCluster);
    CellIDs = T_dsxfru.cellID(ismember(T_dsxfru.subtype,TYPES));
    vInputSynapses(nCluster) = sum(T_connectivity.syn_count(ismember(T_connectivity.post_root_id,CellIDs)));
    vOutSynapses(nCluster) = sum(T_connectivity.syn_count(ismember(T_connectivity.pre_root_id,CellIDs)));
end

% Create the empty table
varnames = {'source','target','weight'};
vartypes = {'string', 'string', 'double'};
E = table('Size', [0, 3], 'VariableNames', varnames, 'VariableTypes', vartypes);
%run over all possible pairs of target=sourse pairs (not symmetric..)
nLine = 1;%in the table E
disp('calculating weights...')
for ii = 1:CLUSTERS
    TYPES_source = T_clusters.Subtypes(T_clusters.ClusterNumber==ii);
    CellIDs_source = T_dsxfru.cellID(ismember(T_dsxfru.subtype,TYPES_source));
    for jj = 1:CLUSTERS

        if jj==ii%no self loops
            continue
        end

        disp(['From ',num2str(ii),' to ',num2str(jj)])
        TYPES_target = T_clusters.Subtypes(T_clusters.ClusterNumber==jj);
        CellIDs_target = T_dsxfru.cellID(ismember(T_dsxfru.subtype,TYPES_target));
        SYNAPSES = sum(T_connectivity.syn_count(ismember(T_connectivity.pre_root_id,CellIDs_source) &...
            ismember(T_connectivity.post_root_id,CellIDs_target)));

        %weighted by the relative output and input
        W = (SYNAPSES/vOutSynapses(ii))*(SYNAPSES/vInputSynapses(jj));
        disp(['Weight = ',num2str(W)])

        E.source(nLine) = ii;
        E.target(nLine) = jj;
        E.weight(nLine) = W;
        nLine = nLine +1;
    end
end

%save variables
filename = '/Users/ddeutsch/Library/CloudStorage/Dropbox/My Documents/MyOwnLab/Experiments/Connectomics/dsx_fru/Shared_dsxfru/Nature communication/figures/Fig5 - Network/Network_connectivity.mat';
save(filename,'E','vInputSynapses','vOutSynapses')

%% python environment

% I first created a conda env, cloned
% https://github.com/arie-matsliah/sfas and installed it in the environment

pyenv%if Python has been selected but has not yet been started in this MATLAB session
% should get: Status: NotLoaded
py.importlib.import_module('sfas')

edges_py = py.list({ ...
    py.list({'a','b',3}), ...
    py.list({'b','c',2}), ...
    py.list({'c','a',1})});

order_py = py.sfas.greedy.compute_order(edges_py);
order = string(order_py);
disp(order)

pyenv %After the first Python call, pyenv Status should change from NotLoaded to Loaded

%% Setup Python environment

if pyenv().Status == "NotLoaded"
    pyenv('Version','/Users/ddeutsch/anaconda3/envs/sfas/bin/python');
end


%% main code - modified version that fixes some issues..

% parameters
nLayers = 4;% number of layers in the plot
TopEdges_percentile = 10;%show only the TopEdges_percentile % top weights
UseMultipleSeeds = 0;

%load
filename = '/Users/ddeutsch/Library/CloudStorage/Dropbox/My Documents/MyOwnLab/Experiments/Connectomics/dsx_fru/Shared_dsxfru/Nature communication/figures/Fig5 - Network/Network_connectivity.mat';
load(filename)

E_sfas = E;

% remove rows that SFAS should not see
E_sfas(E_sfas.source == E_sfas.target, :) = [];%self loops
E_sfas(E_sfas.weight <= 0, :) = [];%negative weights

% scale to integers
scaleFactor = 1e6;   % adjust if needed
E_sfas.weight = round(E_sfas.weight * scaleFactor);

% remove edges that became zero after rounding
E_sfas(E_sfas.weight <= 0, :) = [];

if UseMultipleSeeds == 0
    order = run_sfas(E_sfas);
else
    bestOrder = [];
    bestScore = inf;

    for seed = 1:100
        order = run_sfas(E_sfas, seed);   % modify wrapper to pass random_seed
        score = backward_weight(E_sfas, order);  % evaluate total backward weight
        if score < bestScore
            bestScore = score;
            bestOrder = order;
        end
    end
    order = bestOrder;
end

% show top connections
thr = quantile(E.weight, 1-TopEdges_percentile/100);
E_plot = E(E.weight >= thr, :);

% make sure all nodes from the FULL network are represented in the order
allNodes = unique([string(E.source); string(E.target)], 'stable');
order = string(order(:));
missingNodes = setdiff(allNodes, order, 'stable');
order = [order; missingNodes];

[layers, posTbl, G] = plot_sfas_layered(E, E_plot, order, nLayers);


%% helper function: run sfas
function order = run_sfas(E)

edges_py = py.list();

for i = 1:height(E)
    edges_py.append(py.list({string(E.source(i)), ...
        string(E.target(i)), ...
        double(E.weight(i))}));
end

order_py = py.sfas.greedy.compute_order(edges_py);

order = string(order_py);
order = cellstr(order);

end


%% helper function: plot

function [layers, posTbl, G] = plot_sfas_layered(E_layout, E_draw, order, nLayers)
% plot_sfas_layered
%
% Create a layered directed graph plot from:
%   E     - table with variables: source, target, weight
%   order - SFAS order of nodes (numeric, string, cellstr, categorical)
%   nLayers - number of layers (optional, default = 5)
%
% The code:
%   1) assigns nodes to layers according to SFAS order
%   2) minimizes crossings using only FORWARD edges
%   3) uses weighted barycenters for ordering within layers
%   4) refines by adjacent swaps
%   5) plots all edges, with backward edges curved/dashed
%
% Outputs:
%   layers - 1 x nLayers cell array, each cell contains node names in order
%   posTbl  - table with columns: node, layer, x, y
%   G       - digraph object for the full graph
%
% Example:
%   [layers, posTbl, G] = plot_sfas_layered(E, order, 5);

if nargin < 4 || isempty(nLayers)
    nLayers = 5;
end

E = E_layout;   % use full graph for layout calculations

%% ----------------------------
%  Basic checks and normalization
% -----------------------------
requiredVars = {'source','target','weight'};
if ~all(ismember(requiredVars, E.Properties.VariableNames))
    error('E must contain variables: source, target, weight');
end

% Convert nodes to string for internal consistency
src = string(E.source);
tgt = string(E.target);
w   = double(E.weight);

if numel(order) ~= numel(unique(string(order)))
    error('order must contain each node exactly once.');
end
order = string(order(:));
nNodes = numel(order);

% Check that all graph nodes appear in order
graphNodes = unique([src; tgt]);
missingNodes = setdiff(graphNodes, order);
if ~isempty(missingNodes)
    error('These nodes appear in E but are missing from order: %s', strjoin(cellstr(missingNodes), ', '));
end

% If order has extra nodes not present in E, that is okay.
rankMap = containers.Map(cellstr(order), num2cell(1:nNodes));

%% ----------------------------
%  Keep only nodes in order, aggregate duplicate edges
% -----------------------------
% remove self loops from crossing-minimization and plotting if desired?
% Here we keep them in the graph table, but they are ignored in crossing count.
T = table(src, tgt, w, 'VariableNames', {'source','target','weight'});
T = groupsummary(T, {'source','target'}, 'sum', 'weight');
T.weight = T.sum_weight;
T.sum_weight = [];

src = T.source;
tgt = T.target;
w   = T.weight;

%% ----------------------------
%  Define forward/backward edges according to SFAS order
% -----------------------------
srcRank = zeros(height(T),1);
tgtRank = zeros(height(T),1);
for i = 1:height(T)
    srcRank(i) = rankMap(char(src(i)));
    tgtRank(i) = rankMap(char(tgt(i)));
end

isForward  = srcRank < tgtRank;
isBackward = srcRank > tgtRank;
% self-loops are neither
isLoop     = srcRank == tgtRank;

Tfwd = T(isForward, :);
Tall = T;

%% ----------------------------
%  Assign nodes to layers by rank
% -----------------------------
% Balanced split using ceil(linspace(...))
edgesLayer = round(linspace(0, nNodes, nLayers+1));
layers = cell(1, nLayers);
for k = 1:nLayers
    idx1 = edgesLayer(k) + 1;
    idx2 = edgesLayer(k+1);
    if idx1 <= idx2
        layers{k} = order(idx1:idx2).';
    else
        layers{k} = strings(1,0);
    end
end

node2layer = containers.Map('KeyType','char','ValueType','double');
for k = 1:nLayers
    for i = 1:numel(layers{k})
        node2layer(char(layers{k}(i))) = k;
    end
end

%% ----------------------------
%  Crossing minimization:
%  only forward edges, weighted barycenter + transpose
% -----------------------------
nSweeps = 12;

fprintf('Starting layout optimization...\n');
tStart = tic;

for iter = 1:nSweeps
    tSweep = tic;
    fprintf('Sweep %d / %d (%.1f%%)\n', iter, nSweeps, 100*iter/nSweeps);
    elapsed = toc(tStart);
    estTotal = elapsed / iter * nSweeps;
    estRemaining = estTotal - elapsed;

    fprintf('   Elapsed: %.1fs | Remaining: %.1fs\n', elapsed, estRemaining);

    % Downward sweep: layer 2 -> nLayers
    for k = 2:nLayers
        if iter == nSweeps
            fprintf('   Sweep %d: layer %d/%d (down, sifting)\n', iter, k, nLayers);
        end
        prevLayer = layers{k-1};
        currLayer = layers{k};
        if numel(currLayer) <= 1
            continue;
        end

        scores = nan(size(currLayer));
        oldPos = 1:numel(currLayer);

        for iNode = 1:numel(currLayer)
            u = currLayer(iNode);

            % Incoming FORWARD edges from previous layer only
            mask = Tfwd.target == u & ismember(Tfwd.source, prevLayer);
            neigh = Tfwd.source(mask);
            ww    = Tfwd.weight(mask);

            if ~isempty(neigh)
                pos = zeros(size(neigh));
                for j = 1:numel(neigh)
                    pos(j) = find(prevLayer == neigh(j), 1, 'first');
                end
                scores(iNode) = sum(pos .* ww) / sum(ww);  % weighted barycenter
            else
                scores(iNode) = oldPos(iNode); % fallback preserves relative order
            end
        end

        [~, ordIdx] = sortrows([scores(:), oldPos(:)], [1 2]);
        layers{k} = currLayer(ordIdx).';

        % transpose refinement against previous layer
        if iter == nSweeps
            layers{k} = local_sift(layers{k}, prevLayer, strings(1,0), Tfwd, 'down');
        else
            layers{k} = local_transpose(layers{k}, prevLayer, strings(1,0), Tfwd, 'down');
        end
    end

    % Upward sweep: layer nLayers-1 -> 1
    for k = nLayers-1:-1:1
        if iter == nSweeps
            fprintf('   Sweep %d: layer %d/%d (up, sifting)\n', iter, k, nLayers);
        end
        nextLayer = layers{k+1};
        currLayer = layers{k};
        if numel(currLayer) <= 1
            continue;
        end

        scores = nan(size(currLayer));
        oldPos = 1:numel(currLayer);

        for iNode = 1:numel(currLayer)
            u = currLayer(iNode);

            % Outgoing FORWARD edges to next layer only
            mask = Tfwd.source == u & ismember(Tfwd.target, nextLayer);
            neigh = Tfwd.target(mask);
            ww    = Tfwd.weight(mask);

            if ~isempty(neigh)
                pos = zeros(size(neigh));
                for j = 1:numel(neigh)
                    pos(j) = find(nextLayer == neigh(j), 1, 'first');
                end
                scores(iNode) = sum(pos .* ww) / sum(ww);  % weighted barycenter
            else
                scores(iNode) = oldPos(iNode);
            end
        end

        [~, ordIdx] = sortrows([scores(:), oldPos(:)], [1 2]);
        layers{k} = currLayer(ordIdx).';

        % transpose refinement against next layer
        if iter == nSweeps
            layers{k} = local_sift(layers{k}, strings(1,0), nextLayer, Tfwd, 'up');
        else
            layers{k} = local_transpose(layers{k}, strings(1,0), nextLayer, Tfwd, 'up');
        end
    end
    sweepTime = toc(tSweep);
    elapsed = toc(tStart);
    estRemaining = (nSweeps - iter) * sweepTime;

    fprintf('Finished sweep %d / %d (%.1f%%)\n', iter, nSweeps, 100*iter/nSweeps);
    fprintf('   Last sweep: %.2fs | Elapsed: %.2fs | Remaining: ~%.2fs\n', ...
        sweepTime, elapsed, estRemaining);
end

%% ----------------------------
%  Compute node coordinates
% -----------------------------
xGap = 1.0;
yGap = 1.0;

nodeList = strings(nNodes,1);
x = zeros(nNodes,1);
y = zeros(nNodes,1);
layerIdx = zeros(nNodes,1);

c = 0;
for k = 1:nLayers
    thisLayer = layers{k};
    m = numel(thisLayer);

    if m == 0
        continue;
    end

    % Center each layer horizontally around 0
    if m == 1
        xx = 0;
    else
        xx = (-(m-1)/2 : (m-1)/2) * xGap;
    end
    yy = -(k-1) * yGap * ones(1,m);

    for j = 1:m
        c = c + 1;
        nodeList(c) = thisLayer(j);
        x(c) = xx(j);
        y(c) = yy(j);
        layerIdx(c) = k;
    end
end

nodeList = nodeList(1:c);
x = x(1:c);
y = y(1:c);
layerIdx = layerIdx(1:c);

posTbl = table(nodeList, layerIdx, x, y, ...
    'VariableNames', {'node','layer','x','y'});

node2x = containers.Map(cellstr(posTbl.node), num2cell(posTbl.x));
node2y = containers.Map(cellstr(posTbl.node), num2cell(posTbl.y));

%% ----------------------------
%  Build digraph for full graph
% -----------------------------
G = digraph(string(E_draw.source), string(E_draw.target), E_draw.weight, string(posTbl.node));

%% ----------------------------
%  Plot
% -----------------------------
figure;
set(gcf, 'Units', 'normalized', 'OuterPosition', [0 0 1 1]);
hold on; axis equal; axis off;



% remove margins completely
set(gca, 'LooseInset', get(gca,'TightInset'))

% plot invisible graph to get node labels easy
p = plot(G, 'XData', zeros(numnodes(G),1), 'YData', zeros(numnodes(G),1), ...
    'NodeLabel', {}, 'MarkerSize', 1, 'NodeColor', 'none', 'EdgeColor', 'none');

% digraph node names are strings/cellstr
gNodes = string(G.Nodes.Name);
XData = zeros(size(gNodes));
YData = zeros(size(gNodes));
for i = 1:numel(gNodes)
    XData(i) = node2x(char(gNodes(i)));
    YData(i) = node2y(char(gNodes(i)));
end
p.XData = XData;
p.YData = YData;

% zoom-out in y-axis to give space for arcs (add margin relative to data range)
rangeY = max(YData) - min(YData);
ylim([min(YData)- 0.05 * rangeY, max(YData)+ 0.35 * rangeY])

% Node styling
scatter(XData, YData, 700, 'w', 'filled', ...
    'MarkerEdgeColor', [0 0 0], 'LineWidth', 1.2);

for i = 1:numel(gNodes)
    text(XData(i), YData(i), char(gNodes(i)), ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'FontSize', 9, 'Interpreter', 'none');
end

% Draw light layer guides
yl = ylim;
for k = 1:nLayers
    xx = (k-1) * xGap;
    plot([xx xx], yl, ':', 'Color', [0.85 0.85 0.85]);
end

% Normalize linewidths by edge weight (DRAW ONLY E_draw)
Tdraw = table(string(E_draw.source), string(E_draw.target), double(E_draw.weight), ...
    'VariableNames', {'source','target','weight'});

% Aggregate duplicate drawn edges
Tdraw = groupsummary(Tdraw, {'source','target'}, 'sum', 'weight');
Tdraw.weight = Tdraw.sum_weight;
Tdraw.sum_weight = [];

allW = Tdraw.weight;
if isempty(allW) || max(allW) == min(allW)
    lineW = 1.5 * ones(height(Tdraw),1);
else
    lineW = 0.75 + 3.25 * (allW - min(allW)) ./ (max(allW)-min(allW));
end

% Draw only selected edges manually
for i = 1:height(Tdraw)
    u = Tdraw.source(i);
    v = Tdraw.target(i);

    x1 = node2x(char(u));
    y1 = node2y(char(u));
    x2 = node2x(char(v));
    y2 = node2y(char(v));

    if strcmp(char(u), char(v))
        % self-loop
        draw_selfloop(x1, y1, lineW(i));
        continue;
    end

    ru = rankMap(char(u));
    rv = rankMap(char(v));

    layer_u = node2layer(char(u));
    layer_v = node2layer(char(v));

    if layer_u == layer_v
        % SAME LAYER → draw curved arc
        dx = abs(x2 - x1);

        % curvature depends on distance
        rad = 0.08 + 0.05 * dx;
        rad = min(rad, 0.25);

        % alternate direction to reduce overlap
        if ru < rv
            rad = +rad;
        else
            rad = -rad;
        end

        draw_arrow(x1, y1, x2, y2, lineW(i), '-', [0.3 0.3 0.3], rad);

    elseif ru < rv %streight line as default; curved to avoid cutting through nodes on the way
        % forward edge: straight unless it crosses near another node
        KeepAwayRadius = 0.6;
        hitNode = edge_hits_other_node(x1, y1, x2, y2, u, v, posTbl, KeepAwayRadius);%the

        if hitNode
            rad = 0.12 + 0.03 * abs(x2 - x1);
            rad = min(rad, 0.22);
            draw_arrow(x1, y1, x2, y2, lineW(i), '-', [0.2 0.2 0.2], rad);
        else
            draw_arrow(x1, y1, x2, y2, lineW(i), '-', [0.2 0.2 0.2], 0);
        end

    else
        % backward edge: curved dashed
        hitNode = edge_hits_other_node(x1, y1, x2, y2, u, v, posTbl, 0.28);

        if hitNode
            rad = 0.28 + 0.06 * abs(rv - ru);
        else
            rad = 0.18 + 0.05 * abs(rv - ru);
        end

        rad = min(rad, 0.55);

        draw_arrow(x1, y1, x2, y2, lineW(i), '--', [0.65 0.2 0.2], rad);
    end
end
hold off;

%% ========================
%  Nested helper functions
% =========================

    function layerOut = local_sift(currLayer, prevLayer, nextLayer, Tfwd_local, mode)
        layerOut = currLayer(:).';   % force row vector

        if numel(layerOut) <= 2
            return;
        end

        window = 3;

        for ii = 1:numel(layerOut)
            fprintf('      sifting node %d/%d\n', ii, numel(layerOut));
            node = layerOut(ii);
            tmp = layerOut;
            tmp(ii) = [];
            tmp = tmp(:).';

            bestLayer = layerOut;
            bestScore = inf;

            p1 = max(1, ii - window);
            p2 = min(numel(tmp) + 1, ii + window);

            for pos = p1:p2
                candidate = [tmp(1:pos-1), node, tmp(pos:end)];
                candidate = candidate(:).';

                switch mode
                    case 'down'
                        score = count_crossings_between(prevLayer, candidate, Tfwd_local, 'down');
                    case 'up'
                        score = count_crossings_between(candidate, nextLayer, Tfwd_local, 'up');
                    otherwise
                        error('Unknown mode.');
                end

                if score < bestScore
                    bestScore = score;
                    bestLayer = candidate;
                end
            end

            layerOut = bestLayer;
        end
    end

    function layerOut = local_transpose(currLayer, prevLayer, nextLayer, Tfwd_local, mode)
        % Adjacent swap refinement.
        % mode = 'down' -> evaluate crossings with prevLayer -> currLayer
        % mode = 'up'   -> evaluate crossings with currLayer -> nextLayer

        layerOut = currLayer;

        improved = true;

        while improved
            improved = false;

            for ii = 1:(numel(layerOut)-1)

                before = layerOut;
                after = layerOut;

                % swap adjacent nodes
                after([ii ii+1]) = after([ii+1 ii]);

                switch mode
                    case 'down'
                        cBefore = count_crossings_between(prevLayer, before, Tfwd_local, 'down');
                        cAfter  = count_crossings_between(prevLayer, after,  Tfwd_local, 'down');

                    case 'up'
                        cBefore = count_crossings_between(before, nextLayer, Tfwd_local, 'up');
                        cAfter  = count_crossings_between(after,  nextLayer, Tfwd_local, 'up');

                    otherwise
                        error('Unknown mode.');
                end

                if cAfter < cBefore
                    layerOut = after;
                    improved = true;
                end
            end
        end
    end

    function nCross = count_crossings_between(layerA, layerB, Tfwd_local, mode)
        % Count crossings between two adjacent layers using only forward edges.
        % Faster version using inversion counting: O(e log e) instead of O(e^2).

        layerA = string(layerA(:).');
        layerB = string(layerB(:).');

        if isempty(layerA) || isempty(layerB)
            nCross = 0;
            return;
        end

        switch mode
            case {'down','up'}
                mask = ismember(Tfwd_local.source, layerA) & ismember(Tfwd_local.target, layerB);
            otherwise
                error('Unknown mode.');
        end

        TT = Tfwd_local(mask,:);
        m = height(TT);

        if m <= 1
            nCross = 0;
            return;
        end

        % Map node names to positions in the two layers
        posA = containers.Map(cellstr(layerA), num2cell(1:numel(layerA)));
        posB = containers.Map(cellstr(layerB), num2cell(1:numel(layerB)));

        a = zeros(m,1);
        b = zeros(m,1);

        for jj = 1:m
            a(jj) = posA(char(TT.source(jj)));
            b(jj) = posB(char(TT.target(jj)));
        end

        % Sort by source-layer position, then by target-layer position
        AB = sortrows([a b], [1 2]);

        % Count inversions in the target positions
        bSorted = AB(:,2);
        nCross = merge_count_inversions(bSorted);
    end

    function invCount = merge_count_inversions(x)
        % Count inversions in vector x using merge sort.
        x = x(:);
        [~, invCount] = sort_count(x);
    end

    function [y, invCount] = sort_count(x)
        n = numel(x);
        if n <= 1
            y = x;
            invCount = 0;
            return;
        end

        mid = floor(n/2);
        [left, invL]  = sort_count(x(1:mid));
        [right, invR] = sort_count(x(mid+1:end));
        [y, invM]     = merge_count(left, right);

        invCount = invL + invR + invM;
    end

    function [y, invCount] = merge_count(left, right)
        i = 1;
        j = 1;
        k = 1;
        invCount = 0;
        y = zeros(numel(left) + numel(right), 1);

        while i <= numel(left) && j <= numel(right)
            if left(i) <= right(j)
                y(k) = left(i);
                i = i + 1;
            else
                y(k) = right(j);
                j = j + 1;
                invCount = invCount + (numel(left) - i + 1);
            end
            k = k + 1;
        end

        while i <= numel(left)
            y(k) = left(i);
            i = i + 1;
            k = k + 1;
        end

        while j <= numel(right)
            y(k) = right(j);
            j = j + 1;
            k = k + 1;
        end
    end

    function draw_arrow(x1, y1, x2, y2, lw, ls, col, rad)
        % Draw an arrow, optionally curved.

        nodeR = 0.12; % approximate node radius in axis units

        if abs(rad) < eps
            % straight line
            dx = x2 - x1;
            dy = y2 - y1;
            L = hypot(dx, dy);
            if L == 0, return; end

            ux = dx / L;
            uy = dy / L;

            xs = x1 + nodeR * ux;
            ys = y1 + nodeR * uy;
            xe = x2 - nodeR * ux;
            ye = y2 - nodeR * uy;

            quiver(xs, ys, xe-xs, ye-ys, 0, ...
                'Color', col, 'LineWidth', lw, 'LineStyle', ls, ...
                'MaxHeadSize', 0.35, 'AutoScale', 'off');
        else
            % quadratic Bezier curve
            mx = (x1 + x2)/2;
            my = (y1 + y2)/2;

            dx = x2 - x1;
            dy = y2 - y1;
            L = hypot(dx, dy);
            if L == 0, return; end

            % perpendicular
            px = -dy / L;
            py =  dx / L;

            cx = mx + rad * L * px;
            cy = my + rad * L * py;

            t = linspace(0,1,100);
            bx = (1-t).^2 * x1 + 2*(1-t).*t * cx + t.^2 * x2;
            by = (1-t).^2 * y1 + 2*(1-t).*t * cy + t.^2 * y2;

            % trim near endpoints
            % start
            dStart = hypot(bx-x1, by-y1);
            iStart = find(dStart > nodeR, 1, 'first');
            if isempty(iStart), iStart = 1; end

            % end
            dEnd = hypot(bx-x2, by-y2);
            iEnd = find(dEnd > nodeR, 1, 'last');
            if isempty(iEnd), iEnd = numel(t); end

            bx = bx(iStart:iEnd);
            by = by(iStart:iEnd);

            plot(bx, by, 'Color', col, 'LineWidth', lw, 'LineStyle', ls);

            % arrow head from last segment
            % arrow head from last segment (manual, more reliable than quiver)
            if numel(bx) >= 2
                xa = bx(end-1);
                ya = by(end-1);
                xb = bx(end);
                yb = by(end);

                dx = xb - xa;
                dy = yb - ya;
                L = hypot(dx, dy);

                if L > 0
                    ux = dx / L;
                    uy = dy / L;

                    % arrowhead size
                    ah = 0.10 + 0.02 * lw;   % length of arrowhead
                    aw = 0.06 + 0.01 * lw;   % half-width of arrowhead

                    % two arrowhead arms
                    xh1 = xb - ah*ux + aw*(-uy);
                    yh1 = yb - ah*uy + aw*( ux);

                    xh2 = xb - ah*ux - aw*(-uy);
                    yh2 = yb - ah*uy - aw*( ux);

                    plot([xb xh1], [yb yh1], 'Color', col, 'LineWidth', lw);
                    plot([xb xh2], [yb yh2], 'Color', col, 'LineWidth', lw);
                end
            end
        end
    end

    function draw_selfloop(x0, y0, lw)
        th = linspace(pi/6, 11*pi/6, 80);
        r = 0.18;
        xc = x0 + 0.02;
        yc = y0 + 0.22;
        xx = xc + r*cos(th);
        yy = yc + r*sin(th);
        plot(xx, yy, 'Color', [0.4 0.4 0.4], 'LineWidth', lw, 'LineStyle', '-');
        quiver(xx(end-1), yy(end-1), xx(end)-xx(end-1), yy(end)-yy(end-1), 0, ...
            'Color', [0.4 0.4 0.4], 'LineWidth', lw, 'LineStyle', 'none', ...
            'MaxHeadSize', 0.8, 'AutoScale', 'off');
    end

% helper function: preventing an edge from passing through other nodes in the middle of its path
    function tf = edge_hits_other_node(x1, y1, x2, y2, u, v, posTbl, nodeRadius)
        % Returns true if the segment from (x1,y1) to (x2,y2) passes too close
        % to any node other than u or v.

        tf = false;

        for kk = 1:height(posTbl)
            w = posTbl.node(kk);

            if strcmp(char(w), char(u)) || strcmp(char(w), char(v))
                continue;
            end

            xc = posTbl.x(kk);
            yc = posTbl.y(kk);

            % distance from point to segment
            dx = x2 - x1;
            dy = y2 - y1;

            if dx == 0 && dy == 0
                continue;
            end

            t = ((xc - x1)*dx + (yc - y1)*dy) / (dx*dx + dy*dy);
            t = max(0, min(1, t));

            xp = x1 + t*dx;
            yp = y1 + t*dy;

            d = hypot(xc - xp, yc - yp);

            if d < nodeRadius
                tf = true;
                return;
            end
        end
    end

end

