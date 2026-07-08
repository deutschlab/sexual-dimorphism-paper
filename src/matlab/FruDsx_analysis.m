%this script collects and plots general stats about dsxfru for the sexualk dimorphism paper


%% setup: paths are relative to the repository, so this runs on any machine.
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'setup: paths are relative to the repository, so this runs on any machine.');
% See src/matlab/README.md for how to obtain the external/large files below.
repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(repoRoot,'src','matlab','helpers'))

%%parameters
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'parameters');
version = 783;%Two neuropil where aadded to the neuropil list:
subversion = 'V15';
nRepeats = 100;%sets of flywire cells with super-class distribution at the dsxfru
nt_Threshold = 0.6;%what is the minimal fraction of cells in a given type that should have the same nt
% for this type to be considered as having nt (otherwise nt will be 'Unknown')


%LA (_L,_R) - Lamina, OCG - ocellar ganglion

%files
dataFolder = fullfile(repoRoot,'data');
rawDataFolder = fullfile(dataFolder,'raw');%large/external files, not tracked in git - see src/matlab/README.md
intermediateFolder = fullfile(dataFolder,'intermediate');%regenerated each run, not tracked in git

%datasets
% Supplemental_file1_neuron_annotations: published by Berg et al. (PMID 41279223),
% https://github.com/flyconnectome/flywire_annotations/tree/main/supplemental_files
% (pinned to commit f02717b). See src/matlab/README.md for download steps.
filename_flywire = fullfile(rawDataFolder,'Supplemental_file1_neuron_annotations.tsv');
filename_dsxfru = fullfile(repoRoot,'Supplemental_table1_neuron_annotations.csv');
filename_dsxfru_updated =  fullfile(intermediateFolder,['Dsxfru_',num2str(version),'_',subversion,'_updated.csv']);%added fields/columns; regenerated each run
filename_classRanking = fullfile(dataFolder, ['ranks_',num2str(version)],['allClasses_',num2str(version),'.csv']);
filename_classRanking_Notnormalized = fullfile(dataFolder,...
    ['ranks_',num2str(version)],['allClasses_',num2str(version),'_notNormalized.csv']);
filename_auditory = fullfile(dataFolder,['Auditory_cells_',num2str(version),'_new.xlsx']);


%CODEX download - info (large files, not tracked in git - see src/matlab/README.md for exact version + download steps)
filename_connectivity = fullfile(rawDataFolder,'connections_princeton783.csv');
filename_cellstats = fullfile(rawDataFolder,'cell_stats783.csv');
filename_neurons = fullfile(rawDataFolder,'neurons783.csv');
%filename_labels =
%fullfile(dataFolder,['processed_labels',num2str(version),'.csv']); currently not in use

%'matched networks' - used as controls for fru/dsx
filename_matchednetworks = fullfile(dataFolder,['matched_networks_dsxfru_',num2str(version),'_',subversion,'.csv']);


%colors (consistent with other FlyWire 'package' papers)
filename_colors_seatable = fullfile(dataFolder,'colors_seatable.csv');


figuresFolder = fullfile(repoRoot,'figures');
figureSubfolders = {'Fig1 - Methods and Stats','Fig3 - Connectivity','Fig6 - Dsx-centric network',...
    'Fig7 - Sensory','Fig8 - Sensory','Fig9 - DNs','Fig9 - experimental validation'};
if ~exist(intermediateFolder,'dir'), mkdir(intermediateFolder); end
for nFolder = 1:length(figureSubfolders)
    thisFolder = fullfile(figuresFolder,figureSubfolders{nFolder});
    if ~exist(thisFolder,'dir'), mkdir(thisFolder); end
end

%% read files + create tables
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'read files + create tables');

%read flywire table (including updated cell types, neurotransmitter predictions and more)
opts = detectImportOptions(filename_flywire,'FileType','delimitedtext','Delimiter','\t');
opts = setvartype(opts, 'root_id','string');  %or 'char' if you prefer
T_flywire = readtable(filename_flywire, opts);
T_flywire.Properties.VariableNames("root_id") = "cellID";

%read dsxfru table
opts = detectImportOptions(filename_dsxfru);
opts = setvartype(opts, 'cellID','string');
T_dsxfru = readtable(filename_dsxfru, opts);

%read the auditory table
T_auditory = readtable(filename_auditory);
T_auditory.nt_type = T_auditory.top_nt;%this version of the auditory table has top_nt/known_nt instead of nt_type

%read file - classification (not used since Dec 2025 - all the info is in Supplemental_file1_neuron_annotations
% opts = detectImportOptions(filename_classification);
% opts = setvartype(opts, 'root_id','string');  %or 'char' if you prefer
% T_classification = readtable(filename_classification,opts);
% T_classification.Properties.VariableNames("root_id") = "cellID";

%cell stats (length, area, size for each cell)
opts = detectImportOptions(filename_cellstats);
opts = setvartype(opts, 'root_id','string');  %or 'char' if you prefer
T_cellstats = readtable(filename_cellstats,opts);
T_cellstats.Properties.VariableNames("root_id") = "cellID";

%connectivity (using the Princeton synapses)
opts = detectImportOptions(filename_connectivity);
opts = setvartype(opts, 'pre_root_id','string');
opts = setvartype(opts, 'post_root_id','string');
T_connectivity = readtable(filename_connectivity, opts);

%neurotransmitter prediction
opts = detectImportOptions(filename_neurons);
opts = setvartype(opts, 'root_id','string');
T_neurons = readtable(filename_neurons, opts);
T_neurons.Properties.VariableNames("root_id") = "cellID";

%read color table - used to define some colors in some figures according to
%the convention in the flywire papers..
T_colors = readtable(filename_colors_seatable);



%read classRank (normalized)
opts = detectImportOptions(filename_classRanking);
opts = setvartype(opts, 'CellID','string');  %or 'char' if you prefer
T_classRanking = readtable(filename_classRanking,opts);
T_classRanking.Properties.VariableNames("CellID") = "cellID";

%read classRank (not normalized)
opts = detectImportOptions(filename_classRanking_Notnormalized);
opts = setvartype(opts, 'CellID','string');  %or 'char' if you prefer
T_classRanking_Notnormalized = readtable(filename_classRanking_Notnormalized,opts);
T_classRanking_Notnormalized.Properties.VariableNames("CellID") = "cellID";


%add ranks to T_flywire and to T_dsxfru
%normalized
[Lia,locb] = ismember(T_flywire.cellID,T_classRanking.cellID);
T_flywire.mechanosensory_jo = nan(height(T_flywire),1);
T_flywire.mechanosensory_jo(Lia) = T_classRanking.mechanosensory_jo(locb(Lia>0));
T_flywire.olfactory = nan(height(T_flywire),1);
T_flywire.olfactory(Lia) = T_classRanking.olfactory(locb(Lia>0));
T_flywire.gustatory = nan(height(T_flywire),1);
T_flywire.gustatory(Lia) = T_classRanking.gustatory(locb(Lia>0));
T_flywire.visual_projection = nan(height(T_flywire),1);
T_flywire.visual_projection(Lia) = T_classRanking.visual_projection(locb(Lia>0));

[Lia,locb] = ismember(T_dsxfru.cellID,T_classRanking.cellID);
T_dsxfru.mechanosensory_jo = nan(height(T_dsxfru),1);
T_dsxfru.mechanosensory_jo(Lia) = T_classRanking.mechanosensory_jo(locb(Lia>0));
T_dsxfru.olfactory = nan(height(T_dsxfru),1);
T_dsxfru.olfactory(Lia) = T_classRanking.olfactory(locb(Lia>0));
T_dsxfru.gustatory = nan(height(T_dsxfru),1);
T_dsxfru.gustatory(Lia) = T_classRanking.gustatory(locb(Lia>0));
T_dsxfru.visual_projection = nan(height(T_dsxfru),1);
T_dsxfru.visual_projection(Lia) = T_classRanking.visual_projection(locb(Lia>0));

%not normalized
[Lia,locb] = ismember(T_flywire.cellID,T_classRanking_Notnormalized.cellID);
T_flywire.mechanosensory_jo_notNormalized = nan(height(T_flywire),1);
T_flywire.mechanosensory_jo_notNormalized(Lia) = round(T_classRanking_Notnormalized.mechanosensory_jo(locb(Lia>0)));
T_flywire.olfactory_notNormalized = nan(height(T_flywire),1);
T_flywire.olfactory_notNormalized(Lia) = round(T_classRanking_Notnormalized.olfactory(locb(Lia>0)));
T_flywire.gustatory_notNormalized = nan(height(T_flywire),1);
T_flywire.gustatory_notNormalized(Lia) = round(T_classRanking_Notnormalized.gustatory(locb(Lia>0)));
T_flywire.visual_projection_notNormalized = nan(height(T_flywire),1);
T_flywire.visual_projection_notNormalized(Lia) = round(T_classRanking_Notnormalized.visual_projection(locb(Lia>0)));

[Lia,locb] = ismember(T_dsxfru.cellID,T_classRanking_Notnormalized.cellID);
T_dsxfru.mechanosensory_jo_notNormalized = nan(height(T_dsxfru),1);
T_dsxfru.mechanosensory_jo_notNormalized(Lia) = round(T_classRanking_Notnormalized.mechanosensory_jo(locb(Lia>0)));
T_dsxfru.olfactory_notNormalized = nan(height(T_dsxfru),1);
T_dsxfru.olfactory_notNormalized(Lia) = round(T_classRanking_Notnormalized.olfactory(locb(Lia>0)));
T_dsxfru.gustatory_notNormalized = nan(height(T_dsxfru),1);
T_dsxfru.gustatory_notNormalized(Lia) = round(T_classRanking_Notnormalized.gustatory(locb(Lia>0)));
T_dsxfru.visual_projection_notNormalized = nan(height(T_dsxfru),1);
T_dsxfru.visual_projection_notNormalized(Lia) = round(T_classRanking_Notnormalized.visual_projection(locb(Lia>0)));

%add cell stats to flywire
T_flywire.length_nm = nan(height(T_flywire),1);
T_flywire.area_nm = nan(height(T_flywire),1);
T_flywire.size_nm = nan(height(T_flywire),1);
[Lia,locb] = ismember(T_flywire.cellID,T_cellstats.cellID);
T_flywire.length_nm(Lia) = T_cellstats.length_nm(locb(locb>0));
T_flywire.area_nm(Lia) = T_cellstats.area_nm(locb(locb>0));
T_flywire.size_nm(Lia) = T_cellstats.size_nm(locb(locb>0));

%change neurotransmitter to the info in CODEX (downloaded 1.1.2026)
[Lia, locb] = ismember(T_flywire.cellID,T_neurons.cellID);
T_flywire.nt_type = T_flywire.top_nt;
T_flywire.nt_type(Lia==1) = T_neurons.nt_type(locb(locb>0));
T_flywire.nt_type(~ismember(T_flywire.nt_type,{'ACH','GABA','GLUT','DA','OCT','SER'})) = {'unknown'};
T_flywire.nt_type_score(Lia==1) = T_neurons.nt_type_score(locb(locb>0));
T_flywire.nt_type_score(~ismember(T_flywire.nt_type,{'ACH','GABA','GLUT','DA','OCT','SER'})) = 0;
%T_flywire.nt_type(Lia==1) = T_neurons.nt_type(locb(locb==1));
T_flywire = removevars(T_flywire,{'top_nt','top_nt_conf'});



% %remove kenyon cells - this was done before 'matched networks' were
% created by Arie - currently it is being taken of there
% opts = detectImportOptions(filename_labels);
% opts = setvartype(opts, 'root_id','string');
% T_labels = readtable(filename_labels, opts);
% T_labels.Properties.VariableNames("root_id") = "cellID";
% IDX = contains(lower(T_labels.processed_labels),'kenyon') & contains(lower(T_labels.processed_labels),'cell');
% CellIDs_to_remove = T_labels.cellID(IDX);
% [~,Locb] = ismember(CellIDs_to_remove,T_flywire.cellID);
% Locb = unique(Locb(Locb>0));
% T_flywire(Locb,:) = [];
%T_flywire.Properties.RowNames = T_flywire.cellID;
%T_flywire(CellIDs_to_remove,:) = [];


%mark which cells are dsxfru
[~,loc_in_flywire]= ismember(T_dsxfru.cellID,T_flywire.cellID);
T_flywire.Is_dsxfru(1:size(T_flywire,1)) = 0;%default
T_flywire.Is_dsxfru(loc_in_flywire) = 1;



%  sort rows by primary type within each synonym - without chnaging the order of the synonyms
T = [];
TYPES = unique(T_dsxfru.synonym,'stable');

for ii = 1:length(TYPES)%it is done this way to preserve the original order of the synonyms
    T_temp = T_dsxfru(strcmp(T_dsxfru.synonym,TYPES{ii}),:);
    T_temp = sortrows(T_temp,{'cell_type','side'});
    T = [T;T_temp];
end

T_dsxfru = T;

if exist(filename_matchednetworks)
    %read matched nets
    opts = detectImportOptions(filename_matchednetworks);
    C    = cell(1, size(opts.VariableTypes,2));
    C(:) = {'char'};
    opts.VariableTypes = C;
    T_matched = readtable(filename_matchednetworks, opts);
    T_matched = T_matched(2:end,3:end);%200 matched networks
end

%% add fraction of inputs and outputs (by cell_type and by dsxfru_type) in two ways: with and without excluding within subtypes conectivity
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'add fraction of inputs and outputs (by cell_type and by dsxfru_type) in two ways: with and without excluding within subtypes conectivity');
% if ran twice in a raw - will give an error because of names of columns following outerjoin
% need to run with the original dsxfru table

%takes about 3 minutes - then saved.
% Don't run or don't save if no update to the table!

Cells_originalOrder = T_dsxfru.cellID;

tic

%output to any dsxfru by primary type
T_dsxfru2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.pre_root_id,T_flywire.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_dsxfru2dsxfru.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum_postDsxFru = groupsummary(T_dsxfru2dsxfru, "Pre_Type", "sum", "syn_count");

T_all  = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.pre_root_id,T_flywire.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Pre_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_postDsxFru.Pre_Type,T_sum.Pre_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_to_dsxfru = T_sum;%just to get the right class and size
T_fraction_to_dsxfru.fractionCells_ToDsxfru_by_cellType = T_sum_postDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_to_dsxfru.fractionSynapses_ToDsxfru_by_cellType = T_sum_postDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_to_dsxfru = sortrows(T_fraction_to_dsxfru,{'fractionCells_ToDsxfru_by_cellType','fractionSynapses_ToDsxfru_by_cellType'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_to_dsxfru, 'LeftKeys', 'cell_type', 'RightKeys', 'Pre_Type');


%input from any dsxfru by primary type
T_dsxfru2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.post_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);
T_dsxfru2dsxfru.Post_Type = T_dsxfru.cell_type(Locb(Locb>0));
T_sum_preDsxFru = groupsummary(T_dsxfru2dsxfru, "Post_Type", "sum", "syn_count");

T_all  = T_connectivity(ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.post_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Post_Type = T_dsxfru.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Post_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_preDsxFru.Post_Type,T_sum.Post_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_from_dsxfru = T_sum;%just to get the right class and size
T_fraction_from_dsxfru.fractionCells_FromDsxfru_by_cellType = T_sum_preDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_from_dsxfru.fractionSynapses_FromDsxfru_by_cellType = T_sum_preDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_from_dsxfru = sortrows(T_fraction_from_dsxfru,{'fractionCells_FromDsxfru_by_cellType','fractionSynapses_FromDsxfru_by_cellType'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_from_dsxfru, 'LeftKeys', 'cell_type', 'RightKeys', 'Post_Type');


% output to dsxfru by dsxfru type
T_dsxfru2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.pre_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);
T_dsxfru2dsxfru.Pre_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum_postDsxFru = groupsummary(T_dsxfru2dsxfru, "Pre_Type", "sum", "syn_count");

T_all  = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.pre_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);
T_all.Pre_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum = groupsummary(T_all, "Pre_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_postDsxFru.Pre_Type,T_sum.Pre_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_to_dsxfru = T_sum;%just to get the right class and size
T_fraction_to_dsxfru.fractionCells_ToDsxfru_by_dsxfruType = T_sum_postDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_to_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType = T_sum_postDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_to_dsxfru = sortrows(T_fraction_to_dsxfru,{'fractionCells_ToDsxfru_by_dsxfruType','fractionSynapses_ToDsxfru_by_dsxfruType'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_to_dsxfru, 'LeftKeys', 'synonym', 'RightKeys', 'Pre_Type');


%input from dsxfru by dsxfru type
T_dsxfru2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.post_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_dsxfru2dsxfru.Post_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum_preDsxFru = groupsummary(T_dsxfru2dsxfru, "Post_Type", "sum", "syn_count");

T_all  = T_connectivity(ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.post_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Post_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum = groupsummary(T_all, "Post_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_preDsxFru.Post_Type,T_sum.Post_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_from_dsxfru = T_sum;%just to get the right class and size
T_fraction_from_dsxfru.fractionCells_FromDsxfru_by_dsxfruType = T_sum_preDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_from_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType = T_sum_preDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_from_dsxfru = sortrows(T_fraction_from_dsxfru,{'fractionCells_FromDsxfru_by_dsxfruType','fractionSynapses_FromDsxfru_by_dsxfruType'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_from_dsxfru, 'LeftKeys', 'synonym', 'RightKeys', 'Post_Type');

disp('fraction from/to dsxfru added to table')
% remove and reorder variables
T_dsxfru = removevars(T_dsxfru,{'sum_syn_count_T_fraction_from_dsxfru_1','GroupCount_T_fraction_from_dsxfru_1',...
    'Post_Type_T_fraction_from_dsxfru','sum_syn_count_T_dsxfru_1','GroupCount_T_dsxfru_1','Pre_Type_T_fraction_to_dsxfru',...
    'sum_syn_count_T_fraction_from_dsxfru','GroupCount_T_fraction_from_dsxfru','Post_Type_T_dsxfru'});

T_dsxfru = movevars(T_dsxfru,'fractionSynapses_FromDsxfru_by_dsxfruType','After','cell_type');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_ToDsxfru_by_dsxfruType','After','fractionSynapses_FromDsxfru_by_dsxfruType');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_FromDsxfru_by_cellType','After','fractionSynapses_ToDsxfru_by_dsxfruType');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_ToDsxfru_by_cellType','After','fractionSynapses_FromDsxfru_by_cellType');

T_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType(isnan(T_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType)) = 0;
T_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType(isnan(T_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType)) = 0;
T_dsxfru.fractionSynapses_FromDsxfru_by_cellType(isnan(T_dsxfru.fractionSynapses_FromDsxfru_by_cellType)) = 0;
T_dsxfru.fractionSynapses_ToDsxfru_by_cellType(isnan(T_dsxfru.fractionSynapses_ToDsxfru_by_cellType)) = 0;




%!!!!!!!!!!!! add fraction of inputs and outputs (by cell_type and by dsxfru_type) - **excluding* connections within subtype


%add subtypes to the dsxfru table
TYPES = unique(T_dsxfru.synonym,'stable');
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    lines = find(strcmp(T_dsxfru.synonym,TYPE));
    if isscalar(unique(T_dsxfru.cell_type(lines)))
        T_dsxfru.subtype(lines) =  T_dsxfru.synonym(lines);
    else
        T_dsxfru.subtype(lines) = cellfun(@(x, y) [x '-' y], T_dsxfru.synonym(lines),...
            T_dsxfru.cell_type(lines), 'UniformOutput', false);
    end
end
T_dsxfru = movevars(T_dsxfru,'subtype','After','cell_type');


%remove self connections (within dsxfru subtypes)
[Lia,Locb] = ismember(T_connectivity.pre_root_id,T_dsxfru.cellID);
T_connectivity.presubtype(Lia==1) = T_dsxfru.cell_type(Locb(Lia==1));
[Lia,Locb] = ismember(T_connectivity.post_root_id,T_dsxfru.cellID);
T_connectivity.postsubtype(Lia==1) = T_dsxfru.cell_type(Locb(Lia==1));

Is_same_dsxfru_subtype = strcmp(T_connectivity.presubtype,T_connectivity.postsubtype);

T_connectivity_excluded = T_connectivity(~Is_same_dsxfru_subtype,:);%remove all the connections within a subtype


%from here it is similar to the previous cell, except excluding self
%connections (within subtype)

%output to any dsxfru by primary type
T_dsxfru2dsxfru = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.pre_root_id,T_flywire.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_dsxfru2dsxfru.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum_postDsxFru = groupsummary(T_dsxfru2dsxfru, "Pre_Type", "sum", "syn_count");

T_all  = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.pre_root_id,T_flywire.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Pre_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_postDsxFru.Pre_Type,T_sum.Pre_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_to_dsxfru = T_sum;%just to get the right class and size
T_fraction_to_dsxfru.fractionCells_ToDsxfru_by_cellType = T_sum_postDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_to_dsxfru.fractionSynapses_ToDsxfru_by_cellType_excludeself = T_sum_postDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_to_dsxfru = sortrows(T_fraction_to_dsxfru,{'fractionCells_ToDsxfru_by_cellType','fractionSynapses_ToDsxfru_by_cellType_excludeself'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_to_dsxfru, 'LeftKeys', 'cell_type', 'RightKeys', 'Pre_Type');


%input from any dsxfru by primary type
T_dsxfru2dsxfru = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.post_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);
T_dsxfru2dsxfru.Post_Type = T_dsxfru.cell_type(Locb(Locb>0));
T_sum_preDsxFru = groupsummary(T_dsxfru2dsxfru, "Post_Type", "sum", "syn_count");

T_all  = T_connectivity_excluded(ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.post_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Post_Type = T_dsxfru.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Post_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_preDsxFru.Post_Type,T_sum.Post_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_from_dsxfru = T_sum;%just to get the right class and size
T_fraction_from_dsxfru.fractionCells_FromDsxfru_by_cellType = T_sum_preDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_from_dsxfru.fractionSynapses_FromDsxfru_by_cellType_excludeself = T_sum_preDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_from_dsxfru = sortrows(T_fraction_from_dsxfru,{'fractionCells_FromDsxfru_by_cellType','fractionSynapses_FromDsxfru_by_cellType_excludeself'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_from_dsxfru, 'LeftKeys', 'cell_type', 'RightKeys', 'Post_Type');


% output to dsxfru by dsxfru type
T_dsxfru2dsxfru = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.pre_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);
T_dsxfru2dsxfru.Pre_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum_postDsxFru = groupsummary(T_dsxfru2dsxfru, "Pre_Type", "sum", "syn_count");

T_all  = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.pre_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);
T_all.Pre_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum = groupsummary(T_all, "Pre_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_postDsxFru.Pre_Type,T_sum.Pre_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_to_dsxfru = T_sum;%just to get the right class and size
T_fraction_to_dsxfru.fractionCells_ToDsxfru_by_dsxfruType = T_sum_postDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_to_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType_excludeself = T_sum_postDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_to_dsxfru = sortrows(T_fraction_to_dsxfru,{'fractionCells_ToDsxfru_by_dsxfruType','fractionSynapses_ToDsxfru_by_dsxfruType_excludeself'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_to_dsxfru, 'LeftKeys', 'synonym', 'RightKeys', 'Pre_Type');


%input from dsxfru by dsxfru type
T_dsxfru2dsxfru = T_connectivity_excluded(ismember(T_connectivity_excluded.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2dsxfru.post_root_id,T_dsxfru.cellID);
T_dsxfru2dsxfru = T_dsxfru2dsxfru(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_dsxfru2dsxfru.Post_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum_preDsxFru = groupsummary(T_dsxfru2dsxfru, "Post_Type", "sum", "syn_count");

T_all  = T_connectivity_excluded(ismember(T_connectivity_excluded.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.post_root_id,T_dsxfru.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Post_Type = T_dsxfru.synonym(Locb(Locb>0));
T_sum = groupsummary(T_all, "Post_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_preDsxFru.Post_Type,T_sum.Post_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_from_dsxfru = T_sum;%just to get the right class and size
T_fraction_from_dsxfru.fractionCells_FromDsxfru_by_dsxfruType = T_sum_preDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_from_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType_excludeself = T_sum_preDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_from_dsxfru = sortrows(T_fraction_from_dsxfru,{'fractionCells_FromDsxfru_by_dsxfruType','fractionSynapses_FromDsxfru_by_dsxfruType_excludeself'},'descend');

%adding fields to dsxfru table
T_dsxfru = outerjoin(T_dsxfru, T_fraction_from_dsxfru, 'LeftKeys', 'synonym', 'RightKeys', 'Post_Type');

disp('fraction from/to dsxfru added to table')
% remove and reorder variables
T_dsxfru = removevars(T_dsxfru,{'sum_syn_count_T_fraction_from_dsxfru_1','GroupCount_T_fraction_from_dsxfru_1',...
    'Post_Type_T_fraction_from_dsxfru','sum_syn_count_T_dsxfru_1','GroupCount_T_dsxfru_1','Pre_Type_T_fraction_to_dsxfru',...
    'sum_syn_count_T_fraction_from_dsxfru','GroupCount_T_fraction_from_dsxfru','Post_Type_T_dsxfru'});

T_dsxfru = movevars(T_dsxfru,'fractionSynapses_FromDsxfru_by_dsxfruType_excludeself','After','subtype');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_ToDsxfru_by_dsxfruType_excludeself','After','fractionSynapses_FromDsxfru_by_dsxfruType_excludeself');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_FromDsxfru_by_cellType_excludeself','After','fractionSynapses_ToDsxfru_by_dsxfruType_excludeself');
T_dsxfru = movevars(T_dsxfru,'fractionSynapses_ToDsxfru_by_cellType_excludeself','After','fractionSynapses_FromDsxfru_by_cellType_excludeself');

T_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType_excludeself(isnan(T_dsxfru.fractionSynapses_FromDsxfru_by_dsxfruType_excludeself)) = 0;
T_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType_excludeself(isnan(T_dsxfru.fractionSynapses_ToDsxfru_by_dsxfruType_excludeself)) = 0;
T_dsxfru.fractionSynapses_FromDsxfru_by_cellType_excludeself(isnan(T_dsxfru.fractionSynapses_FromDsxfru_by_cellType_excludeself)) = 0;
T_dsxfru.fractionSynapses_ToDsxfru_by_cellType_excludeself(isnan(T_dsxfru.fractionSynapses_ToDsxfru_by_cellType_excludeself)) = 0;

toc



%bring back to the original length and order
LastRow = find(strcmp(T_dsxfru.synonym,''),1)-1;
T_dsxfru = T_dsxfru(1:LastRow,:);
[~,locb] = ismember(Cells_originalOrder,T_dsxfru.cellID);
T_dsxfru = T_dsxfru(locb,:);


writetable(T_dsxfru,filename_dsxfru_updated)%updating fraction in/out from any dsxfru and when the connections within subtype are excluded


%% create a summary table - used by some of the following figures
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'create a summary table - used by some of the following figures');

%note that 'filename_dsxfru_updated' is being used here
% cellID must be read as string, not numeric - FlyWire root IDs exceed
% double-precision integer range and would silently lose precision otherwise.
opts = detectImportOptions(filename_dsxfru_updated);
opts = setvartype(opts, 'cellID','string');
T_dsxfru = readtable(filename_dsxfru_updated, opts);%The 'update' table also has the fraction in/out

T_dsxfru_summary = table;
nLine = 1;
TYPES = unique(T_dsxfru.synonym);
for nType = 1:length(TYPES)
    TYPE = TYPES{nType};

    idx = find(strcmp(T_dsxfru.synonym,TYPE));%all the cells for this type

    T_dsxfru_summary.type{nLine} = TYPE;
    T_dsxfru_summary.Left(nLine) = sum(strcmp(T_dsxfru.side(idx),'left'));
    T_dsxfru_summary.Right(nLine) = sum(strcmp(T_dsxfru.side(idx),'right'));
    T_dsxfru_summary.Cells(nLine) = length(idx);
    T_dsxfru_summary.super_class{nLine} = T_dsxfru.super_class{idx(1)};

    %ranks
    T_dsxfru_summary.Normrank_mechanosensory_jo_mean(nLine) =...
        mean(T_dsxfru.mechanosensory_jo(idx));
    T_dsxfru_summary.Normrank_olfactory_mean(nLine) =...
        mean(T_dsxfru.olfactory(idx));
    T_dsxfru_summary.Normrank_gustatory_mean(nLine) =...
        mean(T_dsxfru.gustatory(idx));
    T_dsxfru_summary.Normrank_visProj_mean(nLine) =...
        mean(T_dsxfru.visual_projection(idx));

    T_dsxfru_summary.rank_mechanosensory_jo_mean(nLine) =...
        mean(T_dsxfru.mechanosensory_jo_notNormalized(idx));
    T_dsxfru_summary.rank_olfactory_mean(nLine) =...
        mean(T_dsxfru.olfactory_notNormalized(idx));
    T_dsxfru_summary.rank_gustatory_mean(nLine) =...
        mean(T_dsxfru.gustatory_notNormalized(idx));
    T_dsxfru_summary.rank_visProj_mean(nLine) =...
        mean(T_dsxfru.visual_projection_notNormalized(idx));

    %nt - if 80% of the cells per type have a similar nt prediction
    A = T_dsxfru.nt_type(strcmp(T_dsxfru.synonym,TYPE));
    [uniqueS,~,index] = unique(A,'stable');
    count = hist(index,unique(index));%how many instances for each nt
    index = find(count==max(count),1);%the index of the nt with the most cells in this TYPE (if equal take the first one)
    count_max = count(index);%how many cells with the most common nt
    if count_max/sum(count)>=nt_Threshold
        NT = uniqueS{index};
    else
        NT = 'Unknown';
    end
    T_dsxfru_summary.nt_type{nLine} = NT;
    %add - mean_max_in/out(cells)

    nLine = nLine + 1;
end

%% figures 1 - number of left and right cells per type
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figures 1 - number of left and right cells per type');

%must run the previous cell before - creating the summary table

T_dsxfru_summary_sorted = sortrows(T_dsxfru_summary,'Cells','descend');
hf = figure(1); clf(hf); hf.Color = [1 1 1];
%fix labels
for ii = 1:size(T_dsxfru_summary_sorted.type,1)
    us = strfind(T_dsxfru_summary_sorted.type{ii},'_');
    if ~isempty(us)
        T_dsxfru_summary_sorted.type{ii}(us)='-';
    end
end

clear idx

I = find(T_dsxfru_summary_sorted.Cells<=6,1);
for nSubplot = 1:2
    subplot(2,1,nSubplot), hold off

    if nSubplot == 1
        idx = 1:I-1;
    else
        idx = I:size(T_dsxfru_summary_sorted,1);
    end
    ba = bar(table2array(T_dsxfru_summary_sorted(idx,2:3)),'stacked',...
        'FaceColor','flat');
    ba(1).CData = [0 90 181]/255;
    ba(2).CData = [220 50 32]/255;

    ha = gca;
    ha.XTick = 1:length(idx);
    %ha.XTickLabel = string(T_dsxfru_summary_sorted.TYPEname(1:59));
    ha.XTickLabelRotation = 90;
    ha.FontSize = 6;

    for nLine = idx
        STRING = T_dsxfru_summary_sorted.type{nLine};
        if contains(T_dsxfru_summary_sorted.super_class{nLine},'descending')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#803D3D'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'ascending')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#6EB6F6'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'central')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#F9574E'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'visual_centrifugal')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#ACF02E'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'visual_projection')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#E6A01E'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'endocrine')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#8973B2'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'motor')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#B48667'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'visual')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#F4D826'), STRING);
        elseif contains(T_dsxfru_summary_sorted.super_class{nLine},'optic')
            ha.XTickLabel{nLine-idx(1)+1} = sprintf('\\color[rgb]{%f,%f,%f}%s',...
                hex2rgb('#F4D826'), STRING);
        end
    end

    hl = legend('Left','Right','FontSize',12);
    hl.EdgeColor = [1 1 1];
    hl.FontSize = 12;
    box off

    ha = gca;
    ha.FontSize = 12;
    xlim([1 60])

    if nSubplot == 2
        ylim([0 10])
    end

end
%save figure 1
filename = fullfile(figuresFolder, 'Fig1 - Methods and Stats', 'Types_LR');
savefig(gcf,filename)
print(gcf, [filename,'.svg'], '-dsvg');


%% figure 2 fraction connect with dsxfru
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure 2 fraction connect with dsxfru');

hf = figure(2); clf(hf)
hf.Color = [1 1 1];%stacked bar plot of sorted fraction in/out within dsx/fru network

%this cell doesn't depend of the previous code as it first uploads the table with
%the fields that are created earlier

%!!!!!!!!!!!!!!! - make sure this is the correct version
opts = detectImportOptions(filename_dsxfru_updated);
opts = setvartype(opts, 'cellID','string');
T_dsxfru_withFractions = readtable(filename_dsxfru_updated, opts);
%!!!!!!!!!!!!!!!

%list of subtypes
SUBTYPES = cell(1,1);
clear IsDsx FractionIn FractionOut
nSubtype = 1;
TYPES = unique(T_dsxfru_withFractions.synonym,'stable');
for nType = 1:length(TYPES)
    TYPE = TYPES{nType};
    PrimaryTypes = unique(T_dsxfru_withFractions.cell_type(strcmp(T_dsxfru_withFractions.synonym,TYPE)),'stable');
    if isscalar(PrimaryTypes)
        firstIdx = find(strcmp(T_dsxfru_withFractions.synonym,TYPE),1);
        IsDsx(nSubtype) = contains(T_dsxfru_withFractions.Dsx_Fru{firstIdx},'dsx','IgnoreCase',true);
        FractionIn(nSubtype) = T_dsxfru_withFractions.fractionSynapses_FromDsxfru_by_dsxfruType_excludeself(firstIdx);
        FractionOut(nSubtype) = T_dsxfru_withFractions.fractionSynapses_ToDsxfru_by_dsxfruType_excludeself(firstIdx);
        SUBTYPE{nSubtype} = ['  ',TYPE];
        nSubtype = nSubtype + 1;
    else
        for ii = 1:length(PrimaryTypes)
            Idx = find(strcmp(T_dsxfru_withFractions.synonym,TYPE));
            firstIdx = find(strcmp(T_dsxfru_withFractions.synonym,TYPE) & strcmp(T_dsxfru_withFractions.cell_type,PrimaryTypes{ii}),1);
            IsDsx(nSubtype) = contains(T_dsxfru_withFractions.Dsx_Fru{firstIdx},'dsx','IgnoreCase',true);
            FractionIn(nSubtype) = T_dsxfru_withFractions.fractionSynapses_FromDsxfru_by_cellType_excludeself(firstIdx);
            FractionOut(nSubtype) = T_dsxfru_withFractions.fractionSynapses_ToDsxfru_by_cellType_excludeself(firstIdx);

            if FractionIn(nSubtype) + FractionOut(nSubtype) ==...%the most connected primary type
                    max(T_dsxfru_withFractions.fractionSynapses_FromDsxfru_by_cellType_excludeself(Idx)+T_dsxfru_withFractions.fractionSynapses_ToDsxfru_by_cellType_excludeself(Idx))
                SUBTYPE{nSubtype} = ['**',TYPE,'-',PrimaryTypes{ii}];
            else
                SUBTYPE{nSubtype} = ['* ',TYPE,'-',PrimaryTypes{ii}];
            end
            nSubtype = nSubtype + 1;
        end
    end
end


FractionIn(isnan(FractionIn)) = 0;
FractionOut(isnan(FractionOut)) = 0;

Summed_InOut = FractionIn + FractionOut;


[~, I]=  sort(Summed_InOut,'descend');

IsDsx_sorted = IsDsx(I);
TYPES_sorted = SUBTYPE(I);
FractionIn_sorted = FractionIn(I);
FractionOut_sorted = FractionOut(I);
Summed_InOut_sorted = Summed_InOut(I);


% plot
nSubplots = 3;
for nSubplot = 1:nSubplots
    ax = subplot(1,nSubplots,nSubplot);
    RANGE = floor((nSubplot-1)*(1/nSubplots)*length(FractionIn_sorted))+1:floor(nSubplot*(1/nSubplots)*length(FractionIn_sorted));
    barh([FractionIn_sorted(RANGE)', FractionOut_sorted(RANGE)'],'stacked')
    set(gca, 'YDir', 'reverse');

    ha = gca;
    % ha.YTick = 1:length(TYPES_sorted);
    % ha.YTickLabel = TYPES_sorted;
    ha.FontSize = 8;
    %xtickangle(90)
    ylim([0 0.5+length(RANGE)])
    box off
    ha.XAxis.Color = [1 1 1];

    %add text: % in/out
    for ii = 1:length(RANGE)
        text(Summed_InOut_sorted(RANGE(ii))+0.02,ii,num2str(round(100*FractionIn_sorted(RANGE(ii)))),...
            'HorizontalAlignment','left','color',([0, 114, 189])/255,'FontSize',12)
        text(Summed_InOut_sorted(RANGE(ii))+0.08,ii,num2str(round(100*FractionOut_sorted(RANGE(ii)))),...
            'HorizontalAlignment','left','color',([217, 83, 25])/255,'FontSize',12)
    end


    IsDsx_sorted_ = IsDsx_sorted(RANGE);

    ax = gca; % Get current axes
    ax.YTick = 1:length(RANGE); % Set x-ticks
    ax.YTickLabel = []; % Hide default labels

    % Define labels and colors
    labels = TYPES_sorted(RANGE);
    for ii = 1:length(labels)
        s = strfind(labels{ii},'_');
        labels{ii}(s) = '-';
    end

    %color xTickLabels
    colorIndices = find(IsDsx_sorted_); % Indices of labels to color
    dsxColor = [150 0 50]/255; % Color for dsx
    fruColor = [10 125 249]/255; % Color for fru

    % Add custom text labels
    for i = 1:length(labels)
        color = fruColor; % Set fru color
        if ismember(i, colorIndices)
            color = dsxColor; % Set dsx color
        end
        text(ha.XLim(1) - 0.35, i, labels{i}, 'Color', color, 'HorizontalAlignment', 'left', 'FontSize', 8);
    end

    if nSubplot == 1
        XLIM_max = ha.XLim(2);
    else
        ha.XLim(2) = XLIM_max;
    end
end

filename_savefig_Stacked_InOut = fullfile(figuresFolder, 'Fig3 - Connectivity', 'StackedInOut_withinDsxFru');
savefig(gcf,filename_savefig_Stacked_InOut)
print(gcf, [filename_savefig_Stacked_InOut,'.svg'], '-dsvg');


%% dsx(-)fru(-) that are most connected to dsxfru.
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'dsx(-)fru(-) that are most connected to dsxfru.');
% Need to have the tables T_dsxfru and T_flyWire as well as the connections
tic
%from dsx(-)fru(-) to dsx/fru+
T_Negative2dsxfru = T_connectivity(~ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_Negative2dsxfru.pre_root_id,T_flywire.cellID);
T_Negative2dsxfru = T_Negative2dsxfru(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_Negative2dsxfru.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum_postDsxFru = groupsummary(T_Negative2dsxfru, "Pre_Type", "sum", "syn_count");

T_all  = T_connectivity(~ismember(T_connectivity.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.pre_root_id,T_flywire.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Pre_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Pre_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_postDsxFru.Pre_Type,T_sum.Pre_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_to_dsxfru = T_sum;
T_fraction_to_dsxfru.FractionOfCells_postDsxFru = T_sum_postDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_to_dsxfru.FractionOfSynapses_postDsxFru = T_sum_postDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_to_dsxfru = sortrows(T_fraction_to_dsxfru,{'FractionOfCells_postDsxFru','FractionOfSynapses_postDsxFru'},'descend');

LastRow = find(T_fraction_to_dsxfru.FractionOfCells_postDsxFru>=0.3 &...
    T_fraction_to_dsxfru.FractionOfSynapses_postDsxFru >=0.3,1,'last');

for nRow = 1:LastRow
    Pre_Type = T_fraction_to_dsxfru.Pre_Type{nRow};
    CellIDs_pre = T_flywire.cellID(strcmp(T_flywire.cell_type,Pre_Type));
    idx = ismember(T_connectivity.pre_root_id,CellIDs_pre);
    CellIDs_post = T_connectivity.post_root_id(idx);
    Types_Post = unique(T_dsxfru.synonym(ismember(T_dsxfru.cellID,CellIDs_post)));
    T_fraction_to_dsxfru.dsxPost{nRow} = Types_Post;
end



% from dsx/fru+ to dsx(-)fru(-)
T_dsxfru2Negative = T_connectivity(~ismember(T_connectivity.post_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.pre_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_dsxfru2Negative.post_root_id,T_flywire.cellID);
T_dsxfru2Negative = T_dsxfru2Negative(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_dsxfru2Negative.Post_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum_preDsxFru = groupsummary(T_dsxfru2Negative, "Post_Type", "sum", "syn_count");

T_all  = T_connectivity(~ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
[Lia,Locb] = ismember(T_all.post_root_id,T_flywire.cellID);
T_all = T_all(Lia,:);%not sure why a few cell IDs are not in T_flywire
T_all.Post_Type = T_flywire.cell_type(Locb(Locb>0));
T_sum = groupsummary(T_all, "Post_Type", "sum", "syn_count");

[~,Locb] = ismember(T_sum_preDsxFru.Post_Type,T_sum.Post_Type);

T_sum = T_sum(Locb(Locb>0),:);

T_fraction_from_dsxfru = T_sum;
T_fraction_from_dsxfru.FractionOfCells_preDsxFru = T_sum_preDsxFru.GroupCount./T_sum.GroupCount;
T_fraction_from_dsxfru.FractionOfSynapses_preDsxFru = T_sum_preDsxFru.sum_syn_count./T_sum.sum_syn_count;
T_fraction_from_dsxfru = sortrows(T_fraction_from_dsxfru,{'FractionOfCells_preDsxFru','FractionOfSynapses_preDsxFru'},'descend');

LastRow = find(T_fraction_from_dsxfru.FractionOfCells_preDsxFru>=0.3 &...
    T_fraction_from_dsxfru.FractionOfSynapses_preDsxFru>=0.3,1,'last');
for nRow = 1:LastRow
    Post_Type = T_fraction_from_dsxfru.Post_Type{nRow};
    CellIDs_post = T_flywire.cellID(strcmp(T_flywire.cell_type,Post_Type));
    idx = ismember(T_connectivity.post_root_id,CellIDs_post);
    CellIDs_pre = T_connectivity.pre_root_id(idx);
    Types_Pre = unique(T_dsxfru.synonym(ismember(T_dsxfru.cellID,CellIDs_pre)));
    T_fraction_from_dsxfru.dsxPre{nRow} = Types_Pre;
end

%sort by sum of synapse fraction In+Out
[Lia,Locb] = ismember(T_fraction_from_dsxfru.Post_Type,T_fraction_to_dsxfru.Pre_Type);
T_fraction_to_dsxfru_ = T_fraction_to_dsxfru(Locb(Locb>0),:);
T_fraction_from_dsxfru_ = T_fraction_from_dsxfru(Lia,:);
SumInOut = T_fraction_to_dsxfru_.FractionOfSynapses_postDsxFru+T_fraction_from_dsxfru_.FractionOfSynapses_preDsxFru;
[~,I] = sort(SumInOut,'descend');
T_fraction_from_dsxfru_ = T_fraction_from_dsxfru_(I,:);
T_fraction_to_dsxfru_ = T_fraction_to_dsxfru_(I,:);
Summed_InOut_sorted = SumInOut(I);

toc
%% plot - connections of dsxfru(-) to dsxfru(+)
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'plot - connections of dsxfru(-) to dsxfru(+)');
hf = figure(3); clf(hf); hf.Color = [1 1 1];
FractionIn_sorted = T_fraction_from_dsxfru_.FractionOfSynapses_preDsxFru;
FractionOut_sorted = T_fraction_to_dsxfru_.FractionOfSynapses_postDsxFru;
RANGE = 1:find(Summed_InOut_sorted>0.5,1,'last');%50% or more In+Out is dsxfru
barh([FractionIn_sorted(RANGE), FractionOut_sorted(RANGE)],'stacked')
set(gca, 'YDir', 'reverse');
ha = gca;
% ha.YTick = 1:length(TYPES_sorted);
% ha.YTickLabel = TYPES_sorted;
ha.FontSize = 8;
%xtickangle(90)
ylim([0 0.5+length(RANGE)])
box off
ha.XAxis.Color = [1 1 1];

%add text: % in/out
for ii = 1:length(RANGE)
    text(Summed_InOut_sorted(RANGE(ii))+0.015,ii,num2str(round(100*FractionIn_sorted(RANGE(ii)))),...
        'HorizontalAlignment','left','color',([0, 114, 189])/255,'FontSize',12)
    text(Summed_InOut_sorted(RANGE(ii))+0.04,ii,num2str(round(100*FractionOut_sorted(RANGE(ii)))),...
        'HorizontalAlignment','left','color',([217, 83, 25])/255,'FontSize',12)
end

ax = gca; % Get current axes
ax.YTick = 1:length(RANGE); % Set x-ticks
ax.YTickLabel = []; % Hide default labels

% Define labels (add colors by superclass?)
labels = T_fraction_from_dsxfru_.Post_Type(RANGE);
for ii = 1:length(labels)
    s = strfind(labels{ii},'_');
    labels{ii}(s) = '-';
end

% Add custom text labels
for i = 1:length(labels)
    text(ha.XLim(1) - 0.08, i, labels{i}, 'HorizontalAlignment', 'left', 'FontSize', 8);
end

legend('Fraction input from dsx/fru','Fraction output to dsx/fru',...
    'FontSize',12,'location','south','Box','off')


filename_savefig_Stacked_InOut = fullfile(figuresFolder, 'Fig3 - Connectivity', 'StackedInOut_OutsideDsxFru');
savefig(gcf,filename_savefig_Stacked_InOut)
print(gcf, [filename_savefig_Stacked_InOut,'.svg'], '-dsvg');



%% figure 4 - cells per super class
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure 4 - cells per super class');
%similar to Sven's paper - fig2a
%create figure
hf = figure(4); hf.Color = [1 1 1]; hold off

SC = {'endocrine','motor','descending','visual_centrifugal','visual_projection','central','optic','ascending','sensory'};
SC_label = SC; SC_label{4} = 'vis. centr.'; SC_label{5} = 'vis. proj.';

N_L = nan(1,length(SC));
N_R = nan(1,length(SC));
for ii = 1:length(SC)
    N_L(ii) = sum(strcmp(T_dsxfru.super_class,SC{ii}) & strcmpi(T_dsxfru.side,'left'));
    N_R(ii) = sum(strcmp(T_dsxfru.super_class,SC{ii}) & strcmpi(T_dsxfru.side,'right'));
end


X_bias = 1000;
d_y = 0.4;

for ii = 1:length(SC)

    if isempty(find(strcmp(T_colors.label,SC{ii}),1))%temp
        COLOR = '#000000';
    else
        COLOR = T_colors.hex{strcmp(T_colors.label,SC{ii})};
    end
    fill([X_bias X_bias+N_R(ii) X_bias+N_R(ii) X_bias],[ii-d_y ii-d_y ii+d_y ii+d_y],'k','FaceColor',hex2rgb(COLOR)), hold on
    fill([-X_bias -X_bias-N_L(ii) -X_bias-N_L(ii) -X_bias],[ii-d_y ii-d_y ii+d_y ii+d_y],'k','FaceColor',hex2rgb(COLOR))
    text(0,ii,SC_label{ii},'Color',hex2rgb(COLOR),'FontSize',16,'HorizontalAlignment','center')
    text(X_bias+N_R(ii)+100,ii,num2str(N_R(ii)),'Color',hex2rgb(COLOR),'FontSize',16,'HorizontalAlignment','left')
    text(-X_bias-N_L(ii)-100,ii,num2str(N_L(ii)),'Color',hex2rgb(COLOR),'FontSize',16,'HorizontalAlignment','right')

end

plot([-3000 3000],[3.5 3.5],':k','LineWidth',2)
plot([-3000 3000],[7.5 7.5],':k','LineWidth',2)

box off
title('neuron (super classes)','FontSize',16)
text(X_bias,9.7,'Right','HorizontalAlignment','left','FontSize',16)
text(-X_bias,9.7,'Left','HorizontalAlignment','right','FontSize',16)

axis off


filename = fullfile(figuresFolder, 'Fig1 - Methods and Stats', 'dsxfru_LR_bySuperclass');
savefig(gcf,filename)
print(gcf, [filename,'.svg'], '-dsvg');


%% figure 5 - bias to more/less synapses with dsx/fru
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure 5 - bias to more/less synapses with dsx/fru');

hf = figure(5); hf.Color = [1 1 1]; hold off

nPermutations = 100;

for nCell_inDsxFru = 1:size(T_dsxfru.cellID,1)
    CellID = T_dsxfru.cellID{nCell_inDsxFru};

    %intputs
    T = T_connectivity(contains(T_connectivity.post_root_id,CellID),:);

    % Summing B for each unique value in A
    T_PrePartners_oneCell = groupsummary(T, 'pre_root_id', 'sum', 'syn_count');

    % Renaming the column for clarity
    T_PrePartners_oneCell.Properties.VariableNames = {'pre_root_id', 'GroupCount', 'syn_count'};

    % Removing unnecessary GroupCount column
    T_PrePartners_oneCell.GroupCount = [];


    T_PrePartners_oneCell.IsDsxFru = ismember(T_PrePartners_oneCell.pre_root_id,T_dsxfru.cellID);
    Fraction_preDsxFru = sum(T_PrePartners_oneCell.syn_count(T_PrePartners_oneCell.IsDsxFru))/sum(T_PrePartners_oneCell.syn_count);

    Fraction_preDsxFru_permuted = zeros(1,nPermutations);
    T_PrePartners_oneCell_ = T_PrePartners_oneCell;
    for nPermut = 1:nPermutations
        T_PrePartners_oneCell_.IsDsxFru = T_PrePartners_oneCell_.IsDsxFru(randperm(height(T_PrePartners_oneCell)), :);

        Fraction_preDsxFru_permuted(nPermut) = sum(T_PrePartners_oneCell_.syn_count(T_PrePartners_oneCell_.IsDsxFru))/...
            sum(T_PrePartners_oneCell_.syn_count);
    end
    Bias_inputs = (Fraction_preDsxFru - mean(Fraction_preDsxFru_permuted))/std(Fraction_preDsxFru_permuted);

    %outputs
    T = T_connectivity(contains(T_connectivity.pre_root_id,CellID),:);

    % Summing B for each unique value in A
    T_PostPartners_oneCell = groupsummary(T, 'post_root_id', 'sum', 'syn_count');

    % Renaming the column for clarity
    T_PostPartners_oneCell.Properties.VariableNames = {'post_root_id', 'GroupCount', 'syn_count'};

    % Removing unnecessary GroupCount column
    T_PostPartners_oneCell.GroupCount = [];

    T_PostPartners_oneCell.IsDsxFru = ismember(T_PostPartners_oneCell.post_root_id,T_dsxfru.cellID);
    Fraction_postDsxFru = sum(T_PostPartners_oneCell.syn_count(T_PostPartners_oneCell.IsDsxFru))/sum(T_PostPartners_oneCell.syn_count);

    Fraction_postDsxFru_permuted = zeros(1,nPermutations);
    T_PostPartners_oneCell_ = T_PostPartners_oneCell;
    for nPermut = 1:nPermutations
        T_PostPartners_oneCell_.IsDsxFru = T_PostPartners_oneCell_.IsDsxFru(randperm(height(T_PostPartners_oneCell)), :);

        Fraction_postDsxFru_permuted(nPermut) = sum(T_PostPartners_oneCell_.syn_count(T_PostPartners_oneCell_.IsDsxFru))/...
            sum(T_PostPartners_oneCell_.syn_count);
    end
    Bias_outputs = (Fraction_postDsxFru - mean(Fraction_postDsxFru_permuted))/std(Fraction_postDsxFru_permuted);

    %update the table
    T_dsxfru.Fraction_preDsxFru(nCell_inDsxFru) = Fraction_preDsxFru;
    T_dsxfru.Fraction_postDsxFru(nCell_inDsxFru) = Fraction_postDsxFru;
    T_dsxfru.BiasForInputs(nCell_inDsxFru) = Bias_inputs;
    T_dsxfru.BiasForOutputs(nCell_inDsxFru) = Bias_outputs;
end

%mean bias per type
TYPES = unique(T_dsxfru.synonym,'stable');
T = table;
T.synonym = TYPES;
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    T.InBias(nType) =  mean(T_dsxfru.BiasForInputs(strcmp(T_dsxfru.synonym,TYPE)));
    T.OutBias(nType) = mean(T_dsxfru.BiasForOutputs(strcmp(T_dsxfru.synonym,TYPE)));
end

I = T_dsxfru.BiasForInputs(~isnan(T_dsxfru.BiasForInputs));
O = T_dsxfru.BiasForOutputs(~isnan(T_dsxfru.BiasForOutputs));

T = table;
T.synonym = TYPES;
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    T.InBias(nType) = mean(T_dsxfru.BiasForInputs(strcmp(T_dsxfru.synonym,TYPE)));
    T.OutBias(nType) = mean(T_dsxfru.BiasForOutputs(strcmp(T_dsxfru.synonym,TYPE)));
end

d = 0.75;
[counts, edges] = histcounts(I, min(I):d:max(I));
plot(edges(1:end-1)+diff(edges(1:2)),counts,'LineWidth',2)
hold on
[counts, edges] = histcounts(O, min(O):0.5:max(O));
plot(edges(1:end-1)+diff(edges(1:2)),counts,'LineWidth',2)
T_dsxfru.synonym(T_dsxfru.BiasForInputs>2)
box off
ha = gca;
plot([0 0],[0 ha.YLim(2)],':k','LineWidth',2)
plot([-2 -2],[0 ha.YLim(2)],':k','LineWidth',1.5)
plot([2 2],[0 ha.YLim(2)],':k','LineWidth',1.5)
legend('Inputs','Outputs','Box','off')
xlim([-4 6])
xlabel('Bias (std)')

disp('In bias<=-2:')
disp(T.synonym(T.InBias<-2))
disp('Out bias<=-2:')
disp(T.synonym(T.OutBias<-2))
disp('In bias>=2:')
disp(T.synonym(T.InBias>2))
disp('Out bias>=2: ')
disp(T.synonym(T.OutBias>2))

%add names of types with large bias
text(-3.5,150,T.synonym(T.InBias<-2),'Color',[0 0.45 0.74],'VerticalAlignment','top')
text(-3.5,170,T.synonym(T.OutBias<-2),'Color',[0.85 0.33 0.1],'VerticalAlignment','bottom')
text(3.5,150,T.synonym(T.InBias>2),'Color',[0 0.45 0.74],'VerticalAlignment','top')
text(3.5,170,T.synonym(T.OutBias>2),'Color',[0.85 0.33 0.1],'VerticalAlignment','bottom')



filename = fullfile(figuresFolder, 'Fig3 - Connectivity', 'dsxfru_BiasToWithin');
savefig(gcf,filename)
print(gcf, [filename,'.svg'], '-dsvg');

%% figure(6) - comparing rank between dsxfru and the matched networks
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure(6) - comparing rank between dsxfru and the matched networks');
hf = figure(6); clf(hf); hf.Color = [1 1 1];
Lia_dsxfru = ismember(T_flywire.cellID,T_dsxfru.cellID);
jitter_ = 0.1;

for ii = 1:100
    Lia = ismember(T_flywire.cellID,T_matched{ii,:});

    subplot(241)%mechanosensory
    plot(1+jitter_*randn(1,1)-jitter_/2,...
        mean(T_flywire.mechanosensory_jo(Lia)),'ko','MarkerFaceColor','k')
    hold on
    subplot(242)%gustatory
    plot(1+jitter_*randn(1,1)-jitter_/2,...
        mean(T_flywire.gustatory(Lia)),'ko','MarkerFaceColor','k')
    hold on
    subplot(243)%olfactory
    plot(1+jitter_*randn(1,1)-jitter_/2,...
        mean(T_flywire.olfactory(Lia)),'ko','MarkerFaceColor','k')
    hold on
    subplot(244)%visual projection
    plot(1+jitter_*randn(1,1)-jitter_/2,...
        mean(T_flywire.visual_projection(Lia)),'ko','MarkerFaceColor','k')
    hold on

    subplot(234)%mechanosensory/gustatory
    plot(mean(T_flywire.mechanosensory_jo(Lia)),mean(T_flywire.gustatory(Lia)),'ko','MarkerFaceColor','k')
    hold on
    subplot(235)%mechanosensory/olfactory
    plot(mean(T_flywire.mechanosensory_jo(Lia)),mean(T_flywire.olfactory(Lia)),'ko','MarkerFaceColor','k')
    hold on
    subplot(236)%olfactory/gustatory
    plot(mean(T_flywire.olfactory(Lia)),mean(T_flywire.gustatory(Lia)),'ko','MarkerFaceColor','k')
    hold on
end

%add the dsxfru group
subplot(241)%mechanosensory
plot(1,mean(T_flywire.mechanosensory_jo(Lia_dsxfru)),'ro','MarkerFaceColor','r')
ylabel('rank from mechanosensory'), box off
xlim([0.5 1.5])
ha = gca;ha.XTick = [];
subplot(242)%gustatory
plot(1,mean(T_flywire.gustatory(Lia_dsxfru)),'ro','MarkerFaceColor','r')
ylabel('rank from gustatory'), box off
xlim([0.5 1.5])
ha = gca;ha.XTick = [];
subplot(243)%olfactory
plot(1,mean(T_flywire.olfactory(Lia_dsxfru)),'ro','MarkerFaceColor','r')
ylabel('rank from olfactory'), box off
xlim([0.5 1.5])
ha = gca;ha.XTick = [];
subplot(244)%visual projection
plot(1,mean(T_flywire.visual_projection(Lia_dsxfru)),'ro','MarkerFaceColor','r')
ylabel('rank from visual projection'), box off
xlim([0.5 1.5])
ha = gca;ha.XTick = [];

subplot(234)%mechanosensory/gustatory
plot(mean(T_flywire.mechanosensory_jo(Lia_dsxfru)),...
    mean(T_flywire.gustatory(Lia_dsxfru)),'ro','MarkerFaceColor','r')
xlabel('Mechanosensory'), ylabel('Gustatory'), box off
subplot(235)%mechanosensory/olfactory
plot(mean(T_flywire.mechanosensory_jo(Lia_dsxfru)),...
    mean(T_flywire.olfactory(Lia_dsxfru)),'ro','MarkerFaceColor','r')
xlabel('Mechanosensory'), ylabel('Olfactory'), box off
subplot(236)%olfactory/gustatory
plot(mean(T_flywire.olfactory(Lia_dsxfru)),...
    mean(T_flywire.gustatory(Lia_dsxfru)),'ro','MarkerFaceColor','r')
xlabel('Olfactory'), ylabel('Gustatory'), box off


% save figure
filename = fullfile(figuresFolder, 'Fig7 - Sensory', 'rank_frudsxVSmatched');
figsave(filename,gcf);
print(gcf, [filename,'.svg'], '-dsvg');

%% figure(7) - ranks: modality by modality
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure(7) - ranks: modality by modality');
hf = figure(7); clf(hf); hf.Color = [1 1 1];
N_Subtypes2Show = 40;

% Find unique combinations of dsxfru type + primary type
[uniqueCombinations, ~, idx] = unique([categorical(T_dsxfru.synonym) categorical(T_dsxfru.cell_type)], 'rows');


subplot(141)
% mechanosensory
groupMean = splitapply(@mean, T_dsxfru.mechanosensory_jo, idx);
SummaryTable = table(uniqueCombinations,unique(idx),groupMean);
SummaryTable  = sortrows(SummaryTable,'groupMean','ascend');
SummaryTable.Properties.VariableNames("groupMean") = "mechanosensory_jo_mean";
SummaryTable_mechanosensory = SummaryTable;

temp = cellstr(SummaryTable.uniqueCombinations);
[~,Locb] = ismember(temp(:,1),T_dsxfru.synonym);
SuperClass = T_dsxfru.super_class(Locb);
[~,Locb] = ismember(SuperClass,T_colors.label);
Colors_hex = T_colors.hex(Locb);
Colors_RGB = cell2mat(cellfun(@(c) sscanf(c(2:end), '%2x%2x%2x')'/255,Colors_hex,'UniformOutput', false));

SUBGROUPS = cellfun(@(x, y) [x '-' y], temp(:, 1), temp(:, 2), 'UniformOutput', false);
SUBGROUPS = cellfun(@(x) strrep(x, '_', '-'), SUBGROUPS, 'UniformOutput', false);
SummaryTable_mechanosensory.SUBGROUPS = SUBGROUPS;

YData = 1:max(idx);
plot(SummaryTable.mechanosensory_jo_mean,YData,'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k')

ha = gca;
ha.YDir = 'reverse';
box off

% Remove default Y labels
yticks(YData);
yticklabels(repmat({''}, size(SUBGROUPS))); % Set empty Y tick labels

% Add colored text labels manually
for i = 1:N_Subtypes2Show
    text(min(xlim)+0.7, YData(i), SUBGROUPS{i}, 'Color', Colors_RGB(i,:), 'FontSize', 12, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end


title("Mechanosensory-jo"), xlabel('Normalized rank'),
box off
ylim([1 N_Subtypes2Show])

subplot(142)
%olfactory
groupMean = splitapply(@mean, T_dsxfru.olfactory, idx);
SummaryTable = table(uniqueCombinations,unique(idx),groupMean);
SummaryTable  = sortrows(SummaryTable,'groupMean','ascend');
SummaryTable.Properties.VariableNames("groupMean") = "olfactory_mean";
SummaryTable_olfactory = SummaryTable;

temp = cellstr(SummaryTable.uniqueCombinations);
[~,Locb] = ismember(temp(:,1),T_dsxfru.synonym);
SuperClass = T_dsxfru.super_class(Locb);
[~,Locb] = ismember(SuperClass,T_colors.label);
Colors_hex = T_colors.hex(Locb);
Colors_RGB = cell2mat(cellfun(@(c) sscanf(c(2:end), '%2x%2x%2x')'/255,Colors_hex,'UniformOutput', false));

SUBGROUPS = cellfun(@(x, y) [x '-' y], temp(:, 1), temp(:, 2), 'UniformOutput', false);
SUBGROUPS = cellfun(@(x) strrep(x, '_', '-'), SUBGROUPS, 'UniformOutput', false);
SummaryTable_olfactory.SUBGROUPS = SUBGROUPS;

YData = 1:max(idx);
plot(SummaryTable.olfactory_mean,YData,'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k')

ha = gca;
ha.YDir = 'reverse';
box off

% Remove default Y labels
yticks(YData);
yticklabels(repmat({''}, size(SUBGROUPS))); % Set empty Y tick labels

% Add colored text labels manually
for i = 1:N_Subtypes2Show
    text(min(xlim)-0.5, YData(i), SUBGROUPS{i}, 'Color', Colors_RGB(i,:), 'FontSize', 12, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

title("Olfactory"), xlabel('Normalized rank'),
box off
ylim([1 40])

subplot(143)
%gustatory
groupMean = splitapply(@mean, T_dsxfru.gustatory, idx);
SummaryTable = table(uniqueCombinations,unique(idx),groupMean);
SummaryTable  = sortrows(SummaryTable,'groupMean','ascend');
SummaryTable.Properties.VariableNames("groupMean") = "gustatory_mean";
SummaryTable_gustatory = SummaryTable;

temp = cellstr(SummaryTable.uniqueCombinations);
[~,Locb] = ismember(temp(:,1),T_dsxfru.synonym);
SuperClass = T_dsxfru.super_class(Locb);
[~,Locb] = ismember(SuperClass,T_colors.label);
Colors_hex = T_colors.hex(Locb);
Colors_RGB = cell2mat(cellfun(@(c) sscanf(c(2:end), '%2x%2x%2x')'/255,Colors_hex,'UniformOutput', false));

SUBGROUPS = cellfun(@(x, y) [x '-' y], temp(:, 1), temp(:, 2), 'UniformOutput', false);
SUBGROUPS = cellfun(@(x) strrep(x, '_', '-'), SUBGROUPS, 'UniformOutput', false);
SummaryTable_gustatory.SUBGROUPS = SUBGROUPS;

YData = 1:max(idx);
plot(SummaryTable.gustatory_mean,YData,'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k')

ha = gca;
ha.YDir = 'reverse';
box off

% Remove default Y labels
yticks(YData);
yticklabels(repmat({''}, size(SUBGROUPS))); % Set empty Y tick labels

% Add colored text labels manually
for i = 1:N_Subtypes2Show
    text(min(xlim)+0.4, YData(i), SUBGROUPS{i}, 'Color', Colors_RGB(i,:), 'FontSize', 12, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

title("Gustatory"), xlabel('Normalized rank'),
box off
ylim([1 40])


subplot(144)
%visual proj
groupMean = splitapply(@mean, T_dsxfru.visual_projection, idx);
SummaryTable = table(uniqueCombinations,unique(idx),groupMean);
SummaryTable  = sortrows(SummaryTable,'groupMean','ascend');
SummaryTable.Properties.VariableNames("groupMean") = "visual_mean";
SummaryTable_visual = SummaryTable;

temp = cellstr(SummaryTable.uniqueCombinations);
[~,Locb] = ismember(temp(:,1),T_dsxfru.synonym);
SuperClass = T_dsxfru.super_class(Locb);
[~,Locb] = ismember(SuperClass,T_colors.label);
Colors_hex = T_colors.hex(Locb);
Colors_RGB = cell2mat(cellfun(@(c) sscanf(c(2:end), '%2x%2x%2x')'/255,Colors_hex,'UniformOutput', false));

SUBGROUPS = cellfun(@(x, y) [x '-' y], temp(:, 1), temp(:, 2), 'UniformOutput', false);
SUBGROUPS = cellfun(@(x) strrep(x, '_', '-'), SUBGROUPS, 'UniformOutput', false);
SummaryTable_visual.SUBGROUPS = SUBGROUPS;

YData = 1:max(idx);
plot(SummaryTable.visual_mean,YData,'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k')

ha = gca;
ha.YDir = 'reverse';
box off

% Remove default Y labels
yticks(YData);
yticklabels(repmat({''}, size(SUBGROUPS))); % Set empty Y tick labels

% Add colored text labels manually
for i = 1:N_Subtypes2Show
    text(min(xlim)+5.4, YData(i), SUBGROUPS{i}, 'Color', Colors_RGB(i,:), 'FontSize', 12, ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'middle');
end

title("Visual"), xlabel('Normalized rank'),
box off
ylim([1 40])




T = join(SummaryTable_mechanosensory, SummaryTable_olfactory, 'Keys', 'SUBGROUPS');
T = join(T, SummaryTable_gustatory, 'Keys', 'SUBGROUPS');
SummaryTable = join(T, SummaryTable_visual, 'Keys', 'SUBGROUPS');
SummaryTable = removevars(SummaryTable,{'uniqueCombinations_SummaryTable_olfactory','Var2_SummaryTable_mechanosensory',...
    'uniqueCombinations_SummaryTable_olfactory','Var2_SummaryTable_olfactory','uniqueCombinations_T','Var2_T',...
    'uniqueCombinations_SummaryTable_visual','Var2_SummaryTable_visual','uniqueCombinations_SummaryTable_mechanosensory'});
SummaryTable = movevars(SummaryTable,'SUBGROUPS','Before','mechanosensory_jo_mean');

% save figure
filename = fullfile(figuresFolder, 'Fig7 - Sensory', 'rank_byModality');
figsave(filename,gcf);
savefig(gcf, filename)
print(gcf, [filename,'.svg'], '-dsvg');

%% figures(8) - ranks: pairs of modalities
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figures(8) - ranks: pairs of modalities');

%run after the revious cell (that creates 'SummaryTable')!!!

hf = figure(8); clf(hf); hf.Color = [1 1 1];
LIM = 10; %x-y limits (zoom on small ranks)

M = SummaryTable.mechanosensory_jo_mean;
O = SummaryTable.olfactory_mean;
G = SummaryTable.gustatory_mean;
V = SummaryTable.visual_mean;

L = SummaryTable.SUBGROUPS;

subplot(231), hold off
%mechanosensory, olfactory
XX = M(M<=LIM & O<=LIM);
YY = O(M<=LIM & O<=LIM);
LL = L(M<=LIM & O<=LIM);
for ii = 1:length(XX)%the l;oop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Mechanosensory'), ylabel('Olfactory')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

subplot(232), hold off
%mechanosensory, gustatory
XX = M(M<=LIM & G<=LIM);
YY = G(M<=LIM & G<=LIM);
LL = L(M<=LIM & G<=LIM);
for ii = 1:length(XX)%the l;oop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Mechanosensory'), ylabel('Gustatory')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

subplot(233), hold off
%gustatory, olfactory
XX = G(G<=LIM & O<=LIM);
YY = O(G<=LIM & O<=LIM);
LL = L(G<=LIM & O<=LIM);
[~,I] = sort(XX); XX = XX(I); YY = YY(I); LL = LL(I);%sort numbers from left to right
for ii = 1:length(XX)%the l;oop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Gustatory'), ylabel('Olfactory')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

subplot(234), hold off
%visual, gustatory
XX = G(G<=LIM & V<=LIM);
YY = V(G<=LIM & V<=LIM);
LL = L(G<=LIM & V<=LIM);
for ii = 1:length(XX)%the loop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Visual-proj'), ylabel('Olfactory')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

subplot(235), hold off
%visual, olfactory
XX = O(O<=LIM & V<=LIM);
YY = V(O<=LIM & V<=LIM);
LL = L(O<=LIM & V<=LIM);
for ii = 1:length(XX)%the l;oop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Visual-proj'), ylabel('gustatory')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

subplot(236), hold off
%visual-proj, mehcanosensory-jo
XX = M(M<=LIM & V<=LIM);
YY = V(M<=LIM & V<=LIM);
LL = L(M<=LIM & V<=LIM);
for ii = 1:length(XX)%the l;oop is for the legend..
    plot(XX(ii),YY(ii),'o','MarkerFaceColor',[0.9 0.9 0.9],'MarkerEdgeColor','k'), hold on
end
text(XX,YY+0.4,num2cell(1:length(LL)),'HorizontalAlignment','center')

axis equal, xlim([0 LIM]), ylim([0 LIM]), box off
ha = gca; ha.FontSize=14; ha.XTick = 0:2:LIM; ha.YTick = 0:2:LIM;
xlabel('Visual-proj'), ylabel('Mechanosensory-jo')

LEGEND = cell(1,length(LL));
for N = 1:length(LL)
    LEGEND{N} = [num2str(N), '-', LL{N}]; % Concatenate N and original string
end
legend(LEGEND,'Box','off')

% save figure
filename = fullfile(figuresFolder, 'Fig8 - Sensory', 'rank_ModalityPairs');
figsave(filename, gcf);
print(gcf, [filename,'.svg'], '-dsvg');
savefig(gcf, filename);

%% strongest connections - focus on specific circuits
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'strongest connections - focus on specific circuits');

%This loop creates subgroups (so if one dsxfru type has N>1 primary types, each primary type is considered separately)
TYPES = unique(T_dsxfru.synonym,'stable');
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    lines = find(strcmp(T_dsxfru.synonym,TYPE));
    if isscalar(unique(T_dsxfru.cell_type(lines)))
        T_dsxfru.subtype(lines) =  T_dsxfru.synonym(lines);
    else
        T_dsxfru.subtype(lines) = cellfun(@(x, y) [x '-' y], T_dsxfru.synonym(lines),...
            T_dsxfru.cell_type(lines), 'UniformOutput', false);
    end
end

T_dsxfru = movevars(T_dsxfru,'subtype','After','cell_type');

% add nt by subgroup to T_dsxfru
TYPES = unique(T_dsxfru.subtype);
for nType = 1:length(TYPES)
    idx = find(strcmp(T_dsxfru.subtype,TYPES(nType)));
    nt_Onesubtype = T_dsxfru.nt_type(idx);
    allEmpty = all(cellfun(@isempty, nt_Onesubtype));
    if allEmpty
        T_dsxfru.nt_type_persubgroup(idx) = {'unknown'};
        continue
    end
    [uniqueValues, ~, ic] = unique(nt_Onesubtype);
    counts = accumarray(ic, 1); % Count occurrences
    proportions = counts / sum(counts); % Compute proportions
    dominantIdx = find(proportions >= nt_Threshold, 1);
    if ~isempty(dominantIdx)
        T_dsxfru.nt_type_persubgroup(idx) = uniqueValues(dominantIdx); % Assign dominant value
    else
        T_dsxfru.nt_type_persubgroup(idx) = {'unknown'}; % Assign 'unknown' if no value meets the threshold
    end
end

T_dsxfru = movevars(T_dsxfru,'nt_type_persubgroup','After','nt_type');



Conn_Threshold = 0.01;

%dsxfru2dsxfru - strongest
T_dsxfru2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);
T_dsxfru2All = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID),:);
T_All2dsxfru = T_connectivity(ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);

%group by type - dsxfru2dsxfru
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_dsxfru2dsxfru.pre_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_dsxfru2dsxfru.preType = T_dsxfru.subtype(locations);
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_dsxfru2dsxfru.post_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_dsxfru2dsxfru.postType = T_dsxfru.subtype(locations);
% Find unique combinations of pre + post dsxfru type
[uniqueCombinations, ~, idx] = unique([categorical(T_dsxfru2dsxfru.preType) categorical(T_dsxfru2dsxfru.postType)], 'rows');
groupSum = splitapply(@sum, T_dsxfru2dsxfru.syn_count, idx);
T_dsxfru2dsxfru_grouped = table(uniqueCombinations,unique(idx),groupSum);
PrePostTypes = cellstr(T_dsxfru2dsxfru_grouped.uniqueCombinations);
T_dsxfru2dsxfru_grouped.preType = PrePostTypes(:,1);
T_dsxfru2dsxfru_grouped.postType = PrePostTypes(:,2);
% remove and reorder variables
T_dsxfru2dsxfru_grouped = removevars(T_dsxfru2dsxfru_grouped,{'uniqueCombinations','Var2'});
T_dsxfru2dsxfru_grouped = movevars(T_dsxfru2dsxfru_grouped,'groupSum','After','postType');

%group by type - dsxfru2All
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_dsxfru2All.pre_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_dsxfru2All.preType = T_dsxfru.subtype(locations);
T_dsxfru2All_grouped = groupsummary(T_dsxfru2All, "preType", "sum", "syn_count");
T_dsxfru2All_grouped = removevars(T_dsxfru2All_grouped,'GroupCount');

%group by type - All2dsxfru
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_All2dsxfru.post_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_All2dsxfru.postType = T_dsxfru.subtype(locations);
T_All2dsxfru_grouped = groupsummary(T_All2dsxfru, "postType", "sum", "syn_count");
T_All2dsxfru_grouped = removevars(T_All2dsxfru_grouped,'GroupCount');

%add fraction of pre/post connections of a given pair from all connections
%of the pre/post types
locations = arrayfun(@(x) find(strcmp(T_dsxfru2All_grouped.preType,x)), T_dsxfru2dsxfru_grouped.preType);
T_dsxfru2dsxfru_grouped.preToAny = T_dsxfru2All_grouped.sum_syn_count(locations);
locations = arrayfun(@(x) find(strcmp(T_All2dsxfru_grouped.postType,x)), T_dsxfru2dsxfru_grouped.postType);
T_dsxfru2dsxfru_grouped.postFromAny = T_All2dsxfru_grouped.sum_syn_count(locations);

%fraction of synapses for a given pair out of all the pre/post synapses of
%the cells in the pair
T_dsxfru2dsxfru_grouped.Fraction_oneTypePre = T_dsxfru2dsxfru_grouped.groupSum./T_dsxfru2dsxfru_grouped.preToAny;
T_dsxfru2dsxfru_grouped.Fraction_oneTypePost = T_dsxfru2dsxfru_grouped.groupSum./T_dsxfru2dsxfru_grouped.postFromAny;


%add nt
[Lia,Locb] = ismember(T_dsxfru2dsxfru_grouped.preType,T_dsxfru.subtype);
T_dsxfru2dsxfru_grouped.preType_nt(Lia) = T_dsxfru.nt_type_persubgroup(Locb);
[Lia,Locb] = ismember(T_dsxfru2dsxfru_grouped.postType,T_dsxfru.subtype);
T_dsxfru2dsxfru_grouped.postType_nt(Lia) = T_dsxfru.nt_type_persubgroup(Locb);

T_dsxfru2dsxfru_grouped = movevars(T_dsxfru2dsxfru_grouped,'preType_nt','After','preType');
T_dsxfru2dsxfru_grouped = movevars(T_dsxfru2dsxfru_grouped,'postType_nt','After','postType');


%can run this line independently for every new Conn_Threshold, given that T_dsxfru2dsxfru_grouped exists
T_withinDsxFru_filtered = T_dsxfru2dsxfru_grouped(T_dsxfru2dsxfru_grouped.Fraction_oneTypePre>Conn_Threshold & T_dsxfru2dsxfru_grouped.Fraction_oneTypePost>Conn_Threshold,:);


filename = fullfile(figuresFolder, 'Fig6 - Dsx-centric network', 'Tables_Connectivity_BetweenWithin_dsxFru_All.mat');
save(filename,'T_dsxfru2dsxfru','T_dsxfru2dsxfru_grouped','T_withinDsxFru_filtered','T_All2dsxfru','T_All2dsxfru_grouped','T_dsxfru2All','T_dsxfru2All_grouped')

%% Direct connections: dsxfru to descending
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'Direct connections: dsxfru to descending');

% !!! run this cell after running the first two cells of the script (reading the data) and the previous cell !!!

Min_fromDsxFru = 0.1;%for descending that are not in the dsxfru list, what fraction of inputs synapses must be from dsxfru for this descending to be included
%in the filtered table


T_descending = T_dsxfru(strcmp(T_dsxfru.super_class,'descending'),:);

Lia = ismember(T_dsxfru2dsxfru.post_root_id,T_descending.cellID);
T_dsxfru2descending = T_dsxfru2dsxfru(Lia,:);
T_dsxfru2descending_groupedBypost = groupsummary(T_dsxfru2descending, "postType", "sum", "syn_count");
T_dsxfru2descending_groupedByprepost = groupsummary(T_dsxfru2descending, ["preType","postType"], "sum", "syn_count");

Lia = ismember(T_All2dsxfru.post_root_id,T_descending.cellID);
T_All2descending = T_All2dsxfru(Lia,:);
T_All2descending_groupedBypost = groupsummary(T_All2descending, "postType", "sum", "syn_count");


%make them in the same order (sum_syn_count=0 when no inputs from dsxfru)
[Lia,Locb] = ismember(T_All2descending_groupedBypost.postType,T_dsxfru2descending_groupedBypost.postType);

T_All2descending_groupedBypost.Syn_From_dsxfru(Lia) = T_dsxfru2descending_groupedBypost.sum_syn_count(Locb(Locb>0));

% remove and reorder variables
T_All2descending_groupedBypost = removevars(T_All2descending_groupedBypost,'GroupCount');
T_All2descending_groupedBypost = renamevars(T_All2descending_groupedBypost,"sum_syn_count","Syn_From_flywire");

%sort by fraction in from dsxfru
T_All2descending_groupedBypost.fractionFromDsxfru = T_All2descending_groupedBypost.Syn_From_dsxfru./T_All2descending_groupedBypost.Syn_From_flywire;
T_All2descending_groupedBypost = sortrows(T_All2descending_groupedBypost,'fractionFromDsxfru','descend');

%add fraction of synapses from dsxfru, flywire..
[~, Locb] = ismember(T_dsxfru2descending_groupedByprepost.postType, T_All2descending_groupedBypost.postType);
T_dsxfru2descending_groupedByprepost.Syn_From_dsxfru = T_All2descending_groupedBypost.Syn_From_dsxfru(Locb);
T_dsxfru2descending_groupedByprepost.Fraction_of_dsxfru = T_dsxfru2descending_groupedByprepost.sum_syn_count./T_dsxfru2descending_groupedByprepost.Syn_From_dsxfru;
T_dsxfru2descending_groupedByprepost.fractionFromDsxfru = T_All2descending_groupedBypost.fractionFromDsxfru(Locb);
T_dsxfru2descending_groupedByprepost.Syn_From_flywire = T_All2descending_groupedBypost.Syn_From_flywire(Locb);
T_dsxfru2descending_groupedByprepost.Fraction_of_flywire = T_dsxfru2descending_groupedByprepost.sum_syn_count./T_dsxfru2descending_groupedByprepost.Syn_From_flywire;

%sort according to the sum of synapses from dsxfru and then by the fraction from each type
T_dsxfru2descending_groupedByprepost = sortrows(T_dsxfru2descending_groupedByprepost,["fractionFromDsxfru","Fraction_of_dsxfru"],["descend", "descend"]);

%change the names of the subtypses as we use those names again later.. (when looking at descending that are not in the dsxfru list)
T_All2DSXFRUdescending_groupedBypost = T_All2descending_groupedBypost;
T_dsxfru2DSXFRUdescending_groupedByprepost = T_dsxfru2descending_groupedByprepost;
T_dsxfru2DSXFRUdescending_groupedByprepost.IsDescendingDsxFru(1:height(T_dsxfru2DSXFRUdescending_groupedByprepost)) = 1;

% remove and reorder variables
T_dsxfru2DSXFRUdescending_groupedByprepost = removevars(T_dsxfru2DSXFRUdescending_groupedByprepost,'GroupCount');
T_dsxfru2DSXFRUdescending_groupedByprepost = movevars(T_dsxfru2DSXFRUdescending_groupedByprepost,{'IsDescendingDsxFru','Syn_From_flywire',...
    'Syn_From_dsxfru','fractionFromDsxfru','sum_syn_count','Fraction_of_dsxfru','Fraction_of_flywire'},'After','postType');



%now do the same for descending neurons that are not in the dsxfru list

%first, add primary types to postTypes in T_dsxfru2All and to T_connectivity
[Lia,Locb] = ismember(T_dsxfru2All.post_root_id,T_flywire.cellID);
T_dsxfru2All = T_dsxfru2All(Lia,:);
T_dsxfru2All.postType = T_flywire.cell_type(Locb(Locb>0));

[Lia,Locb] = ismember(T_connectivity.post_root_id,T_flywire.cellID);
T_connectivity = T_connectivity(Lia,:);
T_connectivity.postType = T_flywire.cell_type(Locb(Locb>0));


%find all the pairs with post type descending
T_descending = T_flywire(strcmp(T_flywire.super_class,'descending'),:);
Lia = ismember(T_descending.cellID,T_dsxfru.cellID);
T_descending = T_descending(~Lia,:);


%then, find the descending that are not dsxfru but have dsxfru inputs
Lia = ismember(T_dsxfru2All.post_root_id,T_descending.cellID);
T_dsxfru2descending = T_dsxfru2All(Lia,:);
T_dsxfru2descending_groupedBypost = groupsummary(T_dsxfru2descending, "postType", "sum", "syn_count");
T_dsxfru2descending_groupedByprepost = groupsummary(T_dsxfru2descending, ["preType","postType"], "sum", "syn_count");

Lia = ismember(T_connectivity.post_root_id,T_descending.cellID);
T_All2descending = T_connectivity(Lia,:);
T_All2descending_groupedBypost = groupsummary(T_All2descending, "postType", "sum", "syn_count");


%make them in the same order (sum_syn_count=0 when no inputs from dsxfru)
[Lia,Locb] = ismember(T_All2descending_groupedBypost.postType,T_dsxfru2descending_groupedBypost.postType);

T_All2descending_groupedBypost.Syn_From_dsxfru(Lia) = T_dsxfru2descending_groupedBypost.sum_syn_count(Locb(Locb>0));

% remove and reorder variables
T_All2descending_groupedBypost = removevars(T_All2descending_groupedBypost,'GroupCount');
T_All2descending_groupedBypost = renamevars(T_All2descending_groupedBypost,"sum_syn_count","Syn_From_flywire");

%sort by fraction in from dsxfru
T_All2descending_groupedBypost.fractionFromDsxfru = T_All2descending_groupedBypost.Syn_From_dsxfru./T_All2descending_groupedBypost.Syn_From_flywire;
T_All2descending_groupedBypost = sortrows(T_All2descending_groupedBypost,'fractionFromDsxfru','descend');

%add fraction of synapses from dsxfru, flywire..
[~, Locb] = ismember(T_dsxfru2descending_groupedByprepost.postType, T_All2descending_groupedBypost.postType); % Find indices of T.C in T1 columns
T_dsxfru2descending_groupedByprepost.Syn_From_dsxfru = T_All2descending_groupedBypost.Syn_From_dsxfru(Locb);
T_dsxfru2descending_groupedByprepost.Fraction_of_dsxfru = T_dsxfru2descending_groupedByprepost.sum_syn_count./T_dsxfru2descending_groupedByprepost.Syn_From_dsxfru;
T_dsxfru2descending_groupedByprepost.fractionFromDsxfru = T_All2descending_groupedBypost.fractionFromDsxfru(Locb);
T_dsxfru2descending_groupedByprepost.Syn_From_flywire = T_All2descending_groupedBypost.Syn_From_flywire(Locb);
T_dsxfru2descending_groupedByprepost.Fraction_of_flywire = T_dsxfru2descending_groupedByprepost.sum_syn_count./T_dsxfru2descending_groupedByprepost.Syn_From_flywire;

%sort according to the sum of synapses from dsxfru and then by the fraction from each type
T_dsxfru2descending_groupedByprepost = sortrows(T_dsxfru2descending_groupedByprepost,["fractionFromDsxfru","Fraction_of_dsxfru"],["descend", "descend"]);

T_dsxfru2descending_groupedByprepost.IsDescendingDsxFru(1:height(T_dsxfru2descending_groupedByprepost)) = 0;

% remove and reorder variables
T_dsxfru2descending_groupedByprepost = removevars(T_dsxfru2descending_groupedByprepost,'GroupCount');
T_dsxfru2descending_groupedByprepost = movevars(T_dsxfru2descending_groupedByprepost,{'IsDescendingDsxFru','Syn_From_flywire','Syn_From_dsxfru',...
    'fractionFromDsxfru','sum_syn_count','Fraction_of_dsxfru','Fraction_of_flywire'},'After','postType');

%union and sort the tables with descending that are and are not in the dsxfru list
T_dsxfru2AnyDescending_groupedByprepost = [T_dsxfru2DSXFRUdescending_groupedByprepost;T_dsxfru2descending_groupedByprepost];
T_dsxfru2AnyDescending_groupedByprepost = sortrows(T_dsxfru2AnyDescending_groupedByprepost,["fractionFromDsxfru","Fraction_of_dsxfru"],["descend", "descend"]);



T_dsxfru2AnyDescending_groupedByprepost_filtered =...
    T_dsxfru2AnyDescending_groupedByprepost(T_dsxfru2AnyDescending_groupedByprepost.fractionFromDsxfru>Min_fromDsxFru,:);




filename = fullfile(figuresFolder, 'Fig9 - DNs', 'Tables_FruDsx2Descending.mat');
save(filename,'T_dsxfru2descending_groupedByprepost')
%% figure(9) - directed graph: dsxfru to descending
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'figure(9) - directed graph: dsxfru to descending');
hf = figure(9); clf(hf); hf.Color = [1 1 1];
subplot(311)%to make it flat..

T = T_dsxfru2AnyDescending_groupedByprepost_filtered;

% Create a directed graph
G = digraph(T.preType, T.postType, T.Fraction_of_flywire);

% Compute hierarchical (Sugiyama) layout and plot
h = plot(G,'Layout','layered');

% Adjust edge width based on weight
h.LineWidth = rescale(G.Edges.Weight, 0.5, 5); % Scale to reasonable width range

% Remove edge labels
h.EdgeLabel = [];

% Label nodes with their names
%h.NodeLabel = G.Nodes.Name;

% Get node coordinates
X = h.XData;
Y = h.YData;

% Extract unique node names
uniqueNodes = G.Nodes.Name;

nodeColors = zeros(length(uniqueNodes),3);
% Extract RGB values for each node (normalize from [0,255] to [0,1])
for ii = 1:length(uniqueNodes)
    idx = find(strcmp(T_dsxfru.subtype,uniqueNodes{ii}),1);
    if  ~isempty(idx) && contains(T_dsxfru.Dsx_Fru{idx},'dsx/','IgnoreCase',true)%dsx/fru
        nodeColors(ii,1:3) = [150 150 150]/255;
    elseif  ~isempty(idx) && contains(T_dsxfru.Dsx_Fru{idx},'dsx','IgnoreCase',true)%dsx
        nodeColors(ii,1:3) = [150 0 50]/255;
    elseif ~isempty(idx)%fru
        nodeColors(ii,1:3) = [0 125 250]/255;
    else
        nodeColors(ii,1:3) = [0 0 0];
    end

end

% Add rotated and coloredtext labels at node positions
D = 0.05;
IsDescending = ismember(uniqueNodes,T.postType);
for i = 1:numel(G.Nodes.Name)
    S = G.Nodes.Name{i};
    S(strfind(S,'_')) = '-';
    rgb = nodeColors(i,:); % Get RGB color for the node

    if Y(i) > 1.5 && IsDescending(i)
        text(X(i), Y(i)+D, G.Nodes.Name{i}, 'Rotation', 90, 'HorizontalAlignment', 'left', ...
            'FontSize', 10, 'FontWeight', 'bold','VerticalAlignment','middle', 'Color', rgb);
    elseif Y(i) > 1.5 && ~IsDescending(i)
        text(X(i), Y(i)+D, G.Nodes.Name{i}, 'Rotation', 90, 'HorizontalAlignment', 'left', ...
            'FontSize', 10, 'FontWeight', 'normal','VerticalAlignment','middle', 'Color', rgb);
    elseif Y(i) < 1.5 && IsDescending(i)
        text(X(i), Y(i)-D, G.Nodes.Name{i}, 'Rotation', 90, 'HorizontalAlignment', 'right', ...
            'FontSize', 10, 'FontWeight', 'bold','VerticalAlignment','middle', 'Color', rgb);
    else %Y(i) < 1.5 && ~IsDescending(i)
        text(X(i), Y(i)-D, G.Nodes.Name{i}, 'Rotation', 90, 'HorizontalAlignment', 'right', ...
            'FontSize', 10, 'FontWeight', 'normal','VerticalAlignment','middle', 'Color', rgb);
    end
end


box off
ha = gca; 
ha.XAxis.Color = [1 1 1]; ha.YAxis.Color = [1 1 1];


filename = fullfile(figuresFolder, 'Fig9 - DNs', 'dsxfru2Descending');
savefig(gcf,filename)
print(gcf, [filename,'.svg'], '-dsvg');
%print(gcf, [filename,'.png'], '-dpng', '-opengl');



%% connections: auditory and dsxfru
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'connections: auditory and dsxfru');

Conn_Threshold = 0.01;

%add 'subtype' columns - dsxfru
TYPES = unique(T_dsxfru.synonym,'stable');
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    lines = find(strcmp(T_dsxfru.synonym,TYPE));
    if isscalar(unique(T_dsxfru.cell_type(lines)))
        T_dsxfru.subtype(lines) =  T_dsxfru.synonym(lines);
    else
        T_dsxfru.subtype(lines) = cellfun(@(x, y) [x '-' y], T_dsxfru.synonym(lines),...
            T_dsxfru.cell_type(lines), 'UniformOutput', false);
    end
end
T_dsxfru = movevars(T_dsxfru,'subtype','After','cell_type');

% add nt by subgroup to T_dsxfru
TYPES = unique(T_dsxfru.subtype);
for nType = 1:length(TYPES)
    idx = find(strcmp(T_dsxfru.subtype,TYPES(nType)));
    nt_Onesubtype = T_dsxfru.nt_type(idx);
    allEmpty = all(cellfun(@isempty, nt_Onesubtype));
    if allEmpty
        T_dsxfru.nt_type_persubgroup(idx) = {'unknown'};
        continue
    end
    [uniqueValues, ~, ic] = unique(nt_Onesubtype);
    counts = accumarray(ic, 1); % Count occurrences
    proportions = counts / sum(counts); % Compute proportions
    dominantIdx = find(proportions >= 0.6, 1);
    if ~isempty(dominantIdx)
        T_dsxfru.nt_type_persubgroup(idx) = uniqueValues(dominantIdx); % Assign dominant value
    else
        T_dsxfru.nt_type_persubgroup(idx) = {'unknown'}; % Assign 'unknown' if no value meets the threshold
    end
end

T_dsxfru = movevars(T_dsxfru,'nt_type_persubgroup','After','nt_type');

%add 'subtype' columns - auditory
TYPES = unique(T_auditory.auditory_synonym,'stable');
for nType = 1:length(TYPES)
    TYPE = TYPES(nType);
    lines = find(strcmp(T_auditory.auditory_synonym,TYPE));
    if isscalar(unique(T_auditory.cell_type(lines)))
        T_auditory.subtype(lines) =  T_auditory.auditory_synonym(lines);
    else
        T_auditory.subtype(lines) = cellfun(@(x, y) [x '-' y], T_auditory.auditory_synonym(lines),...
            T_auditory.cell_type(lines), 'UniformOutput', false);
    end
end
T_auditory = movevars(T_auditory,'subtype','After','auditory_synonym');


% add nt by subgroup to T_auditory
TYPES = unique(T_auditory.subtype);
for nType = 1:length(TYPES)
    idx = find(strcmp(T_auditory.subtype,TYPES(nType)));
    nt_Onesubtype = T_auditory.nt_type(idx);
    allEmpty = all(cellfun(@isempty, nt_Onesubtype));
    if allEmpty
        T_auditory.nt_type_persubgroup(idx) = {'unknown'};
        continue
    end
    [uniqueValues, ~, ic] = unique(nt_Onesubtype);
    counts = accumarray(ic, 1); % Count occurrences
    proportions = counts / sum(counts); % Compute proportions
    dominantIdx = find(proportions >= 0.6, 1);
    if ~isempty(dominantIdx)
        T_auditory.nt_type_persubgroup(idx) = uniqueValues(dominantIdx); % Assign dominant value
    else
        T_auditory.nt_type_persubgroup(idx) = {'unknown'}; % Assign 'unknown' if no value meets the threshold
    end
end

T_auditory = movevars(T_auditory,'nt_type_persubgroup','After','nt_type');




%dsxfru2auditory
T_dsxfru2auditory = T_connectivity(ismember(T_connectivity.pre_root_id,T_dsxfru.cellID) &...
    ismember(T_connectivity.post_root_id,T_auditory.cellID),:);

%group by type - dsxfru2auditory
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_dsxfru2auditory.pre_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_dsxfru2auditory.preType_dsxfru = T_dsxfru.subtype(locations);
locations = arrayfun(@(x) find(T_auditory.cellID == x, 1, 'first'), T_dsxfru2auditory.post_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_dsxfru2auditory.postType_auditory = T_auditory.subtype(locations);
% Find unique combinations of pre + post types
[uniqueCombinations, ~, idx] = unique([categorical(T_dsxfru2auditory.preType_dsxfru) categorical(T_dsxfru2auditory.postType_auditory)], 'rows');
groupSum = splitapply(@sum, T_dsxfru2auditory.syn_count, idx);
T_dsxfru2auditory_grouped = table(uniqueCombinations,unique(idx),groupSum);
PrePostTypes = cellstr(T_dsxfru2auditory_grouped.uniqueCombinations);
T_dsxfru2auditory_grouped.preType_dsxfru = PrePostTypes(:,1);
T_dsxfru2auditory_grouped.postType_auditory = PrePostTypes(:,2);
% remove and reorder variables
T_dsxfru2auditory_grouped = removevars(T_dsxfru2auditory_grouped,{'uniqueCombinations','Var2'});
T_dsxfru2auditory_grouped = movevars(T_dsxfru2auditory_grouped,'groupSum','After','postType_auditory');


% add fraction of dsx2All and All2auditory (then filter by relative connections)
[Lia,Locb] = ismember(T_connectivity.post_root_id,T_dsxfru2auditory.post_root_id);
T_AlltoAuditory = T_connectivity(Lia,:);
T_AlltoAuditory.postType = T_dsxfru2auditory.postType_auditory(Locb(Locb>0));
T_AlltoAuditory_grouped = groupsummary(T_AlltoAuditory, "postType", "sum", "syn_count");
[~,Locb] = ismember(T_dsxfru2auditory_grouped.postType_auditory,T_AlltoAuditory_grouped.postType);
T_dsxfru2auditory_grouped.PostFromAll = T_AlltoAuditory_grouped.sum_syn_count(Locb);

[Lia,Locb] = ismember(T_connectivity.pre_root_id,T_dsxfru2auditory.pre_root_id);
T_Dsxfru2All = T_connectivity(Lia,:);
T_Dsxfru2All.preType = T_dsxfru2auditory.preType_dsxfru(Locb(Locb>0));
T_Dsxfru2All_grouped = groupsummary(T_Dsxfru2All, "preType", "sum", "syn_count");
[~,Locb] = ismember(T_dsxfru2auditory_grouped.preType_dsxfru,T_Dsxfru2All_grouped.preType);
T_dsxfru2auditory_grouped.PreToAll = T_Dsxfru2All_grouped.sum_syn_count(Locb);

% if auditory type is also dsxfru type - add the dsxfru type
for nType = 1:height(T_dsxfru2auditory_grouped)
    idx_auditory = find(strcmp(T_auditory.subtype,T_dsxfru2auditory_grouped.postType_auditory(nType)),1);
    CellID = T_auditory.cellID{idx_auditory};
    idx_dsxfru = find(strcmp(T_dsxfru.cellID,CellID));
    if isempty(idx_dsxfru)
        T_dsxfru2auditory_grouped.postType_dsxfru{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_dsxfru2auditory_grouped.postType_dsxfru{nType} = T_dsxfru.subtype{idx_dsxfru};
    end
end


% if dsxfru type is also auditory type - add the auditory type
for nType = 1:height(T_dsxfru2auditory_grouped)
    idx_dsxfru = find(strcmp(T_dsxfru.subtype,T_dsxfru2auditory_grouped.preType_dsxfru(nType)),1);
    CellID = T_dsxfru.cellID{idx_dsxfru};
    idx_auditory = find(strcmp(T_auditory.cellID,CellID));
    if isempty(idx_auditory)
        T_dsxfru2auditory_grouped.preType_auditory{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_dsxfru2auditory_grouped.preType_auditory{nType} = T_auditory.subtype{idx_auditory};
    end
end

T_dsxfru2auditory_grouped = movevars(T_dsxfru2auditory_grouped,{'preType_auditory','postType_dsxfru',...
    'postType_auditory'},'After','preType_dsxfru');

% auditory2dsx
T_auditory2dsxfru = T_connectivity(ismember(T_connectivity.pre_root_id,T_auditory.cellID) &...
    ismember(T_connectivity.post_root_id,T_dsxfru.cellID),:);


%group by type - auditory2dsxfru
locations = arrayfun(@(x) find(T_auditory.cellID == x, 1, 'first'), T_auditory2dsxfru.pre_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_auditory2dsxfru.preType_auditory = T_auditory.subtype(locations);
locations = arrayfun(@(x) find(T_dsxfru.cellID == x, 1, 'first'), T_auditory2dsxfru.post_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_auditory2dsxfru.postType_dsxfru = T_dsxfru.subtype(locations);
% Find unique combinations of pre + post dsxfru type
[uniqueCombinations, ~, idx] = unique([categorical(T_auditory2dsxfru.preType_auditory) categorical(T_auditory2dsxfru.postType_dsxfru)], 'rows');
groupSum = splitapply(@sum, T_auditory2dsxfru.syn_count, idx);
T_auditory2dsxfru_grouped = table(uniqueCombinations,unique(idx),groupSum);
PrePostTypes = cellstr(T_auditory2dsxfru_grouped.uniqueCombinations);
T_auditory2dsxfru_grouped.preType_auditory = PrePostTypes(:,1);
T_auditory2dsxfru_grouped.postType_dsxfru = PrePostTypes(:,2);
% remove and reorder variables
T_auditory2dsxfru_grouped = removevars(T_auditory2dsxfru_grouped,{'uniqueCombinations','Var2'});
T_auditory2dsxfru_grouped = movevars(T_auditory2dsxfru_grouped,'groupSum','After','postType_dsxfru');


% add fraction of Auditory2All and All2Dsxfru (then filter by relative connections)
[Lia,Locb] = ismember(T_connectivity.post_root_id,T_auditory2dsxfru.post_root_id);
T_AlltoDsxfru = T_connectivity(Lia,:);
T_AlltoDsxfru.postType = T_auditory2dsxfru.postType_dsxfru(Locb(Locb>0));
T_AlltoDsxfru_grouped = groupsummary(T_AlltoDsxfru, "postType", "sum", "syn_count");
[~,Locb] = ismember(T_auditory2dsxfru_grouped.postType_dsxfru,T_AlltoDsxfru_grouped.postType);
T_auditory2dsxfru_grouped.PostFromAll = T_AlltoDsxfru_grouped.sum_syn_count(Locb);

[Lia,Locb] = ismember(T_connectivity.pre_root_id,T_auditory2dsxfru.pre_root_id);
T_Auditory2All = T_connectivity(Lia,:);
T_Auditory2All.preType = T_auditory2dsxfru.preType_auditory(Locb(Locb>0));
T_Auditory2All_grouped = groupsummary(T_Auditory2All, "preType", "sum", "syn_count");
[~,Locb] = ismember(T_auditory2dsxfru_grouped.preType_auditory,T_Auditory2All_grouped.preType);
T_auditory2dsxfru_grouped.PreToAll = T_Auditory2All_grouped.sum_syn_count(Locb);

% if auditory type is also dsxfru type - add the dsxfru type
for nType = 1:height(T_auditory2dsxfru_grouped)
    idx_auditory = find(strcmp(T_auditory.subtype,T_auditory2dsxfru_grouped.preType_auditory(nType)),1);
    CellID = T_auditory.cellID{idx_auditory};
    idx_dsxfru = find(strcmp(T_dsxfru.cellID,CellID));
    if isempty(idx_dsxfru)
        T_auditory2dsxfru_grouped.preType_dsxfru{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_auditory2dsxfru_grouped.preType_dsxfru{nType} = T_dsxfru.subtype{idx_dsxfru};
    end
end

% if dsxfru type is also auditory type - add the auditory type
for nType = 1:height(T_auditory2dsxfru_grouped)
    idx_dsxfru = find(strcmp(T_dsxfru.subtype,T_auditory2dsxfru_grouped.postType_dsxfru(nType)),1);
    CellID = T_dsxfru.cellID{idx_dsxfru};
    idx_auditory = find(strcmp(T_auditory.cellID,CellID));
    if isempty(idx_auditory)
        T_auditory2dsxfru_grouped.postType_auditory{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_auditory2dsxfru_grouped.postType_auditory{nType} = T_auditory.subtype{idx_auditory};
    end
end


T_auditory2dsxfru_grouped = movevars(T_auditory2dsxfru_grouped,{'preType_dsxfru','preType_auditory','postType_dsxfru',...
    'postType_auditory'},'Before','groupSum');


% auditory2auditory
T_auditory2auditory = T_connectivity(ismember(T_connectivity.pre_root_id,T_auditory.cellID) &...
    ismember(T_connectivity.post_root_id,T_auditory.cellID),:);


%group by type - auditory2auditory
locations = arrayfun(@(x) find(T_auditory.cellID == x, 1, 'first'), T_auditory2auditory.pre_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_auditory2auditory.preType_auditory = T_auditory.subtype(locations);
locations = arrayfun(@(x) find(T_auditory.cellID == x, 1, 'first'), T_auditory2auditory.post_root_id);
locations(isempty(locations)) = 0;  % Ensure missing values are set to 0
T_auditory2auditory.postType_auditory = T_auditory.subtype(locations);
% Find unique combinations of pre + post dsxfru type
[uniqueCombinations, ~, idx] = unique([categorical(T_auditory2auditory.preType_auditory) categorical(T_auditory2auditory.postType_auditory)], 'rows');
groupSum = splitapply(@sum, T_auditory2auditory.syn_count, idx);
T_auditory2auditory_grouped = table(uniqueCombinations,unique(idx),groupSum);
PrePostTypes = cellstr(T_auditory2auditory_grouped.uniqueCombinations);
T_auditory2auditory_grouped.preType_auditory = PrePostTypes(:,1);
T_auditory2auditory_grouped.postType_auditory = PrePostTypes(:,2);
% remove and reorder variables
T_auditory2auditory_grouped = removevars(T_auditory2auditory_grouped,{'uniqueCombinations','Var2'});
T_auditory2auditory_grouped = movevars(T_auditory2auditory_grouped,'groupSum','After','postType_auditory');


% add fraction of Auditory2All and All2Dsxfru (then filter by relative connections)
[Lia,Locb] = ismember(T_connectivity.post_root_id,T_auditory2auditory.post_root_id);
T_AlltoAuditory = T_connectivity(Lia,:);
T_AlltoAuditory.postType = T_auditory2auditory.postType_auditory(Locb(Locb>0));
T_Alltoauditory_grouped = groupsummary(T_AlltoAuditory, "postType", "sum", "syn_count");
[~,Locb] = ismember(T_auditory2auditory_grouped.postType_auditory,T_Alltoauditory_grouped.postType);
T_auditory2auditory_grouped.PostFromAll = T_Alltoauditory_grouped.sum_syn_count(Locb);

[Lia,Locb] = ismember(T_connectivity.pre_root_id,T_auditory2auditory.pre_root_id);
T_Auditory2All = T_connectivity(Lia,:);
T_Auditory2All.preType = T_auditory2auditory.preType_auditory(Locb(Locb>0));
T_Auditory2All_grouped = groupsummary(T_Auditory2All, "preType", "sum", "syn_count");
[~,Locb] = ismember(T_auditory2auditory_grouped.preType_auditory,T_Auditory2All_grouped.preType);
T_auditory2auditory_grouped.PreToAll = T_Auditory2All_grouped.sum_syn_count(Locb);

% if pre auditory type is also dsxfru type - add the dsxfru type
for nType = 1:height(T_auditory2auditory_grouped)
    idx_auditory = find(strcmp(T_auditory.subtype,T_auditory2auditory_grouped.preType_auditory(nType)),1);
    CellID = T_auditory.cellID{idx_auditory};
    idx_dsxfru = find(strcmp(T_dsxfru.cellID,CellID));
    if isempty(idx_dsxfru)
        T_auditory2auditory_grouped.preType_dsxfru{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_auditory2auditory_grouped.preType_dsxfru{nType} = T_dsxfru.subtype{idx_dsxfru};
    end
end

% if post auditory type is also dsxfru type - add the dsxfru type
for nType = 1:height(T_auditory2auditory_grouped)
    idx_auditory = find(strcmp(T_auditory.subtype,T_auditory2auditory_grouped.postType_auditory(nType)),1);
    CellID = T_auditory.cellID{idx_auditory};
    idx_dsxfru = find(strcmp(T_dsxfru.cellID,CellID));
    if isempty(idx_dsxfru)
        T_auditory2auditory_grouped.postType_dsxfru{nType} = '';
    else%this auditory subtype is also a dsxfru subtype
        T_auditory2auditory_grouped.postType_dsxfru{nType} = T_dsxfru.subtype{idx_dsxfru};
    end
end

T_auditory2auditory_grouped = movevars(T_auditory2auditory_grouped,{'preType_dsxfru','preType_auditory','postType_dsxfru',...
    'postType_auditory'},'Before','groupSum');



%combine all three tables
T_dsxfru_auditory_united = [T_dsxfru2auditory_grouped; T_auditory2dsxfru_grouped; T_auditory2auditory_grouped];

% Keep only unique rows
[~, uniqueIdx] = unique(cell2table(T_dsxfru_auditory_united{:,1:4}), 'rows', 'stable');
T_dsxfru_auditory_united = T_dsxfru_auditory_united(uniqueIdx, :);

%add nt by subtype
%dsx
[Lia,Locb] = ismember(T_dsxfru_auditory_united.preType_dsxfru,T_dsxfru.subtype);
T_dsxfru_auditory_united.preTypeDsxfru_nt(Lia>0) = T_dsxfru.nt_type_persubgroup(Locb(Locb>0));
[Lia,Locb] = ismember(T_dsxfru_auditory_united.postType_dsxfru,T_dsxfru.subtype);
T_dsxfru_auditory_united.postTypeDsxfru_nt(Lia>0) = T_dsxfru.nt_type_persubgroup(Locb(Locb>0));
%auditory
[Lia,Locb] = ismember(T_dsxfru_auditory_united.preType_auditory,T_auditory.subtype);
T_dsxfru_auditory_united.preTypeAuditory_nt(Lia>0) = T_auditory.nt_type_persubgroup(Locb(Locb>0));
[Lia,Locb] = ismember(T_dsxfru_auditory_united.postType_auditory,T_auditory.subtype);
T_dsxfru_auditory_united.postTypeAuditory_nt(Lia>0) = T_auditory.nt_type_persubgroup(Locb(Locb>0));

T_dsxfru_auditory_united = movevars(T_dsxfru_auditory_united,'preTypeDsxfru_nt','After','preType_dsxfru');
T_dsxfru_auditory_united = movevars(T_dsxfru_auditory_united,'preTypeAuditory_nt','After','preType_auditory');
T_dsxfru_auditory_united = movevars(T_dsxfru_auditory_united,'postTypeDsxfru_nt','After','postType_dsxfru');
T_dsxfru_auditory_united = movevars(T_dsxfru_auditory_united,'postTypeAuditory_nt','After','postType_auditory');

%filter by fraction connected and add nt
T_dsxfru_auditory_united_filtered = T_dsxfru_auditory_united(T_dsxfru_auditory_united.groupSum./T_dsxfru_auditory_united.PostFromAll>Conn_Threshold &...
    T_dsxfru_auditory_united.groupSum./T_dsxfru_auditory_united.PreToAll>Conn_Threshold,:);


filename = fullfile(figuresFolder, 'Fig7 - Sensory', 'Tables_dsxfru_auditory.mat');
save(filename,'T_dsxfru_auditory_united','T_dsxfru_auditory_united_filtered')



%plot


%filter by fraction of synapses
% T_dsxfru2auditory_grouped_filtered =...
%     T_dsxfru2auditory_grouped(T_dsxfru2auditory_grouped.groupSum./T_dsxfru2auditory_grouped.PostFromAll>Conn_Threshold &...
%     T_dsxfru2auditory_grouped.groupSum./T_dsxfru2auditory_grouped.PreToAll>Conn_Threshold,:);




%% dsx-centric: Three layers: layer 1 = direct connectivity to pMN1,2 (this one threshold), then layer 2:
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'dsx-centric: Three layers: layer 1 = direct connectivity to pMN1,2 (this one threshold), then layer 2:');
% direct connection with layer 1 with a second threshold.
% eventually T_layer1, T_layer2 are used to create the figure.

%run after the first two cells + the cell "strongest connections - focus on specific circuits"

Threshold_layer1 = 0.01;
Threshold_layer2 = 0.03;


%layer0: pMN1, pMN2
%layer1: Fru/Dsx types that are connected with pMN1,2 with strength above Threshold_layer1
%layer2: Fru/Dsx types that are connected with layer1 with strength above Threshold_layer2
%layer3: Fru-/Dsx- types that are connected with pMN1,2 with strength above Threshold_layer2


%directly connected to Dsx/Fru
T = T_dsxfru2dsxfru_grouped(contains(T_dsxfru2dsxfru_grouped.postType,'pMN') | contains(T_dsxfru2dsxfru_grouped.preType,'pMN'),:);
%strong connections only
T_layer1 = T(T.Fraction_oneTypePre>=Threshold_layer1 & T.Fraction_oneTypePost>=Threshold_layer1,:);
TYPES_layer1 = unique([T_layer1.preType; T_layer1.postType]);
TYPES_layer1 = TYPES_layer1(~contains(TYPES_layer1,'pMN'));
%direct connections with layer 1
T = T_dsxfru2dsxfru_grouped(ismember(T_dsxfru2dsxfru_grouped.preType,TYPES_layer1) | ismember(T_dsxfru2dsxfru_grouped.postType,TYPES_layer1),:);
%strong connections only
T_layer2 = T(T.Fraction_oneTypePre>=Threshold_layer2 & T.Fraction_oneTypePost>=Threshold_layer2,:);

%% add layer 3: non-dsxfru to/from layer 1
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'add layer 3: non-dsxfru to/from layer 1');


%----------------------------------------
% Fill pre/post cell types from FlyWire
%----------------------------------------

% initialize if needed
if ~ismember('pre_cellType', T_connectivity.Properties.VariableNames)
    T_connectivity.pre_cellType = repmat({''}, height(T_connectivity), 1);
end
if ~ismember('post_cellType', T_connectivity.Properties.VariableNames)
    T_connectivity.post_cellType = repmat({''}, height(T_connectivity), 1);
end

% if they are not cell already, convert to cell temporarily
if ~iscell(T_connectivity.pre_cellType)
    T_connectivity.pre_cellType = cellstr(string(T_connectivity.pre_cellType));
end
if ~iscell(T_connectivity.post_cellType)
    T_connectivity.post_cellType = cellstr(string(T_connectivity.post_cellType));
end

%----------------------------------------
% Annotate from T_flywire
%----------------------------------------
[Lia, locb] = ismember(T_connectivity.pre_root_id, T_flywire.cellID);
mapIdx = locb(Lia);
T_connectivity.pre_cellType(Lia) = T_flywire.cell_type(mapIdx);

[Lia, locb] = ismember(T_connectivity.post_root_id, T_flywire.cellID);
mapIdx = locb(Lia);
T_connectivity.post_cellType(Lia) = T_flywire.cell_type(mapIdx);

%----------------------------------------
% For dsx/fru, replace cell type by subtype
%----------------------------------------
[Lia, locb] = ismember(T_connectivity.pre_root_id, T_dsxfru.cellID);
mapIdx = locb(Lia);
T_connectivity.pre_cellType(Lia) = T_dsxfru.subtype(mapIdx);

[Lia, locb] = ismember(T_connectivity.post_root_id, T_dsxfru.cellID);
mapIdx = locb(Lia);
T_connectivity.post_cellType(Lia) = T_dsxfru.subtype(mapIdx);

%----------------------------------------
% Clean missing / empty values
%----------------------------------------
idx = cellfun(@isempty, T_connectivity.pre_cellType);
T_connectivity.pre_cellType(idx) = {'unknown'};

idx = cellfun(@isempty, T_connectivity.post_cellType);
T_connectivity.post_cellType(idx) = {'unknown'};

% convert through string to standardize missing handling
T_connectivity.pre_cellType  = string(T_connectivity.pre_cellType);
T_connectivity.post_cellType = string(T_connectivity.post_cellType);

T_connectivity.pre_cellType(ismissing(T_connectivity.pre_cellType))   = "unknown";
T_connectivity.post_cellType(ismissing(T_connectivity.post_cellType)) = "unknown";

% optional: remove surrounding whitespace
T_connectivity.pre_cellType  = strtrim(T_connectivity.pre_cellType);
T_connectivity.post_cellType = strtrim(T_connectivity.post_cellType);

T_connectivity.pre_cellType(T_connectivity.pre_cellType=="")   = "unknown";
T_connectivity.post_cellType(T_connectivity.post_cellType=="") = "unknown";

% categorical for grouping
T_connectivity.pre_cellType  = categorical(T_connectivity.pre_cellType);
T_connectivity.post_cellType = categorical(T_connectivity.post_cellType);


%----------------------------------------
% Group summaries
%----------------------------------------
G = groupsummary(T_connectivity, ...
    {'pre_cellType','post_cellType'}, ...
    'sum', 'syn_count');

G_pre = groupsummary(T_connectivity, ...
    'pre_cellType', 'sum', 'syn_count');
G_pre.Properties.VariableNames{'sum_syn_count'} = 'sum_pre';

G_post = groupsummary(T_connectivity, ...
    'post_cellType', 'sum', 'syn_count');
G_post.Properties.VariableNames{'sum_syn_count'} = 'sum_post';

%----------------------------------------
% Join marginals back
%----------------------------------------
G = join(G, G_pre, 'Keys', 'pre_cellType');
G = join(G, G_post, 'Keys', 'post_cellType');

%----------------------------------------
% Fractions
%----------------------------------------
G.Fraction_oneTypePre  = G.sum_syn_count ./ G.sum_pre;
G.Fraction_oneTypePost = G.sum_syn_count ./ G.sum_post;

%----------------------------------------
% Remove group-count columns if they exist
%----------------------------------------
varsToRemove = {'GroupCount_G','GroupCount_G_pre','GroupCount'};
varsToRemove = intersect(varsToRemove, G.Properties.VariableNames);
G(:, varsToRemove) = [];

%----------------------------------------
% only strong connections with layer 1
%----------------------------------------
T = G(ismember(G.pre_cellType,{'pMN1 (DNp13)','pMN2 (vpoDN)'}) | ismember(G.post_cellType,{'pMN1 (DNp13)','pMN2 (vpoDN)'}),:);
T_layer3 = T(T.Fraction_oneTypePre >= Threshold_layer2 & ...
             T.Fraction_oneTypePost >= Threshold_layer2, :);

T_layer3 = renamevars(T_layer3, 'pre_cellType', 'preType');
T_layer3 = renamevars(T_layer3, 'post_cellType', 'postType');

%Note: Unlike T_layer2, T_layer3 doesn't content previous layers - only the new
%connections, which are the ones directly between dsx-/fru- and pMN1/2
T_layer3 = T_layer3(~ismember( ...
    [string(T_layer3.preType), string(T_layer3.postType)], ...
    [string(T_layer2.preType), string(T_layer2.postType)], ...
    'rows'), :);
%%
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), '');




%add vpoEN, vpoIN - need to update for a symmetric criterion
TYPES_layer2 = unique([T_layer2.preType;T_layer2.postType]);

%vpoEN
idx = find(strcmp(T_flywire.cell_type,'vpoEN'));
CellIDs_vpoEN = T_flywire.cellID(idx);

%vpoEN to Fru/Dsx
idx = find(ismember(T_All2dsxfru.pre_root_id,CellIDs_vpoEN) & ismember(T_All2dsxfru.postType,TYPES_layer2));
T = T_All2dsxfru(idx,:);
T_grouped = groupsummary(T, "postType", "sum", "syn_count");
[~,Locb]=ismember(T_grouped.postType,T_All2dsxfru_grouped.postType);
T_grouped.sum_syn_count = T_All2dsxfru_grouped.sum_syn_count(Locb,:);
T_vpoEN2DsxFru = T_grouped(T_grouped.GroupCount./T_grouped.sum_syn_count>=Threshold_layer2,:);

%vpoEN from Fru/Dsx
idx = find(ismember(T_dsxfru2All.post_root_id,CellIDs_vpoEN) & ismember(T_dsxfru2All.preType,TYPES_layer2));
T = T_dsxfru2All(idx,:);
T_grouped = groupsummary(T, "preType", "sum", "syn_count");
[~,Locb]=ismember(T_grouped.preType,T_dsxfru2All_grouped.preType);
T_grouped.sum_syn_count = T_dsxfru2All_grouped.sum_syn_count(Locb,:);
T_DsxFru2vpoEN = T_grouped(T_grouped.GroupCount./T_grouped.sum_syn_count>=Threshold_layer2,:);


filename = fullfile(figuresFolder, 'Fig6 - Dsx-centric network', 'Dsx-centric.mat');
save(filename,'T_layer1','TYPES_layer1','T_layer2','TYPES_layer2','T_vpoEN2DsxFru','T_DsxFru2vpoEN')

%% statistics: comparing dsxfru to matched networks/flywire: superclass, neurotransmitter, partners, synapses, length,area,size
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'statistics: comparing dsxfru to matched networks/flywire: superclass, neurotransmitter, partners, synapses, length,area,size');

% figure 10 - superclass of dsxfru vs the rest of the brain (excluding kanyon cells)
hf = figure(10); clf(hf); hf.Color = [1 1 1];
subplot(321)%superclass

nMatched = 100;


SC = {'central','optic','visual_projection','visual_centrifugal','descending','ascending','sensory','endocrine','motor'};

N_flywire = nan(1,length(SC));
N_dsxfru = nan(1,length(SC));
for ii = 1:length(SC)
    N_flywire(ii) = length(find(strcmp(T_flywire.super_class,SC{ii})))/...
        length(find(~strcmp(T_flywire.super_class,'endocrine')));
    N_dsxfru(ii) = length(find(strcmp(T_dsxfru.super_class,SC{ii})))/...
        length(find(~strcmp(T_dsxfru.super_class,'endocrine')));

    idx = strfind(SC{ii},'_');
    if ~isempty(idx)
        SC{ii}(idx)='-';
    end
end
hb = bar([N_dsxfru;N_flywire]');
hb(1).FaceColor = [0 0 0];
hb(2).FaceColor = [0.5 0.5 0.5];

ha = gca;
ha.XTick = 1:length(SC);
ha.XTickLabel = SC;
xtickangle(45)
box off
ha.FontSize = 12;
hl = legend('Fru/Dsx','FlyWire');
hl.Box = 'off';
ylabel('Fraction')

subplot(323)
%nt
nt = {'ACH','GLUT','GABA','DA','SER','OCT'};
T_flywire_ = T_flywire(~contains(T_flywire.nt_type,'unknown')' &...
    ~cellfun(@isempty,T_flywire.nt_type)',:);

T_dsxfru_ = T_dsxfru(~cellfun(@isempty,T_dsxfru.nt_type)',:);

clear T_nt_flywire T_nt_dsxfru
T_nt_grouped_flywire = groupsummary(T_flywire_, "nt_type");
[~,Locb] = ismember(nt,T_nt_grouped_flywire.nt_type);
T_nt_flywire = (T_nt_grouped_flywire.GroupCount(Locb)./sum(T_nt_grouped_flywire.GroupCount))';

T_nt_grouped_dsxfru = groupsummary(T_dsxfru_, "nt_type");
[~,Locb] = ismember(nt,T_nt_grouped_dsxfru.nt_type);
T_nt_dsxfru(Locb>0) = T_nt_grouped_dsxfru.GroupCount(Locb(Locb>0))./sum(T_nt_grouped_dsxfru.GroupCount);
T_nt_dsxfru(Locb == 0) = 0;

T_nt_matched = [];
%mean_nt_dsx
for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    T_ = T(~contains(T.nt_type,'Unknown')' &...
        ~cellfun(@isempty,T.nt_type)',:);
    T_nt_grouped = groupsummary(T_, "nt_type");
    [~,Locb] = ismember(nt,T_nt_grouped.nt_type);
    T_nt_matched_(Locb>0) = T_nt_grouped.GroupCount(Locb(Locb>0))./sum(T_nt_grouped.GroupCount);
    T_nt_matched_(Locb == 0) = 0;
    T_nt_matched = [T_nt_matched;T_nt_matched_];
end


T_nt_matched_mean = mean(T_nt_matched);
T_nt_matched_std = std(T_nt_matched);

hb = bar([T_nt_dsxfru;T_nt_matched_mean;T_nt_flywire]');
hb(1).FaceColor = [0 0 0];
hb(2).FaceColor = [137 115 178]/255;
hb(3).FaceColor = [0.5 0.5 0.5];
% add errorbars
hold on
x = hb(2).XEndPoints;
errorbar(x,T_nt_matched_mean, T_nt_matched_std, 'k', 'linestyle', 'none', 'linewidth', 1.5);

ha = gca;
ha.XTick = 1:length(nt);
ha.XTickLabel = nt;
xtickangle(45)
box off
ha.FontSize = 12;
hl = legend('Fru/Dsx','Matched (+-std)','FlyWire');
hl.Box = 'off';
ylabel('Fraction')

subplot(3,10,21)%partners
jitter_ = 0.02;

%find the number of partners and synapses (pre, post) for each cell
PostPartners = groupsummary(T_connectivity, 'pre_root_id', 'numunique', 'post_root_id');
PrePartners = groupsummary(T_connectivity, 'post_root_id', 'numunique', 'pre_root_id');
PostSynapses = groupsummary(T_connectivity, 'pre_root_id', 'sum', 'syn_count');
PreSynapses = groupsummary(T_connectivity, 'post_root_id', 'sum', 'syn_count');

%update T_flywire - add number of pre/posts synapses/partners
[Lia, Locb] = ismember(T_flywire.cellID,PostPartners.pre_root_id);
T_flywire.PostPartners(Lia(Lia>0)) = PostPartners.numunique_post_root_id(Locb(Locb>0));
[Lia, Locb] = ismember(T_flywire.cellID,PrePartners.post_root_id);
T_flywire.PrePartners(Lia(Lia>0)) = PrePartners.numunique_pre_root_id(Locb(Locb>0));

[Lia, Locb] = ismember(T_flywire.cellID,PostSynapses.pre_root_id);
T_flywire.PostSynapses(Lia(Lia>0)) = PostSynapses.sum_syn_count(Locb(Locb>0));
[Lia, Locb] = ismember(T_flywire.cellID,PreSynapses.post_root_id);
T_flywire.PreSynapses(Lia(Lia>0)) = PreSynapses.sum_syn_count(Locb(Locb>0));


T = T_flywire(ismember(T_flywire.cellID,T_dsxfru.cellID),:);
InputPartners_DsxFru = mean(T.PrePartners);
OutputPartners_DsxFru = mean(T.PostPartners);
InputPartners_FlyWire = mean(T_flywire.PrePartners);
OutputPartners_FlyWire = mean(T_flywire.PostPartners);

%matched partners
InputPartners_Matched = zeros(1,nMatched);
OutputPartners_Matched = zeros(1,nMatched);
for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    InputPartners_Matched(ii) = mean(T.PrePartners);
    OutputPartners_Matched(ii) = mean(T.PostPartners);
end

hold off
X_InPartners_matched = 1 + jitter_*randn(1,length(InputPartners_Matched))-jitter_/2;
plot(X_InPartners_matched,InputPartners_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1]), hold on
plot([0.9 1.1],[InputPartners_DsxFru InputPartners_DsxFru],'k','LineWidth',3)
plot([0.9 1.1],[InputPartners_FlyWire InputPartners_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)


X_OutPartners_matched = 2 + jitter_*randn(1,length(OutputPartners_Matched))-jitter_/2;
plot(X_OutPartners_matched,OutputPartners_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1])
plot([1.9 2.1],[OutputPartners_DsxFru OutputPartners_DsxFru],'k','LineWidth',3)
plot([1.9 2.1],[OutputPartners_FlyWire OutputPartners_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)

%hl = legend('Matched networks','Fru/Dsx','FlyWire');
%hl.Box = 'off';
xlim([0.5 2.5])
ha = gca;
ha.XTick = [1 2];
ha.XTickLabel = {'Input','Output'};
ha.XTickLabelRotation = 45;
box off
ylabel('Partners/Neuron')


subplot(3,10,22)%synapses
T = T_flywire(ismember(T_flywire.cellID,T_dsxfru.cellID),:);

InputSynapses_DsxFru = mean(T.PreSynapses);
OutputSynapses_DsxFru = mean(T.PostSynapses);
InputSynapses_FlyWire = mean(T_flywire.PreSynapses);
OutputSynapses_FlyWire = mean(T_flywire.PostSynapses);
%matched synapses
InputSynapses_Matched = zeros(1,nMatched);
OutputSynapses_Matched = zeros(1,nMatched);
for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    InputSynapses_Matched(ii) = mean(T.PreSynapses);
    OutputSynapses_Matched(ii) = mean(T.PostSynapses);
end

hold off
X_InSynapses_matched = 1 + jitter_*randn(1,length(InputSynapses_Matched))-jitter_/2;
plot(X_InSynapses_matched,InputSynapses_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1]), hold on
plot([0.9 1.1],[InputSynapses_DsxFru InputSynapses_DsxFru],'k','LineWidth',3)
plot([0.9 1.1],[InputSynapses_FlyWire InputSynapses_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)


X_OutSynapses_matched = 2 + jitter_*randn(1,length(OutputSynapses_Matched))-jitter_/2;
plot(X_OutSynapses_matched,OutputSynapses_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1])
plot([1.9 2.1],[OutputSynapses_DsxFru OutputSynapses_DsxFru],'k','LineWidth',3)
plot([1.9 2.1],[OutputSynapses_FlyWire OutputSynapses_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)

%hl = legend('Matched networks','Fru/Dsx','FlyWire');
%hl.Box = 'off';
xlim([0.5 2.5])
ha = gca;
ha.XTick = [1 2];
ha.XTickLabel = {'Input','Output'};
ha.XTickLabelRotation = 45;
box off
ylabel('Synapses/Neuron')

subplot(3,10,23)%length
T = T_flywire(ismember(T_flywire.cellID,T_dsxfru.cellID),:);

Length_DsxFru = mean(T.length_nm);
Length_FlyWire = mean(T_flywire.length_nm);

%matched synapses
length_Matched = zeros(1,nMatched);

for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    length_Matched(ii) = mean(T.length_nm);
end

hold off
X_matched = 1 + jitter_*randn(1,length(InputSynapses_Matched))-jitter_/2;
plot(X_matched,length_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1]), hold on
plot([0.97 1.03],[Length_DsxFru Length_DsxFru],'k','LineWidth',3)
plot([0.97 1.03],[Length_FlyWire Length_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)
xlim([0.9 1.1])
ha = gca;
ha.XTick = 1;
ha.XTickLabel = 'Length';
box off
%hl = legend('Matched Networks','Fru/Dsx','FlyWire'); hl.Box = 'off'; hl.Location = 'southwest';

subplot(3,10,24)%area
T = T_flywire(ismember(T_flywire.cellID,T_dsxfru.cellID),:);

Area_DsxFru = mean(T.area_nm);
Area_FlyWire = mean(T_flywire.area_nm);

%matched synapses
area_Matched = zeros(1,nMatched);
for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    area_Matched(ii) = mean(T.area_nm);
end

hold off
X_matched = 1 + jitter_*randn(1,length(OutputSynapses_Matched))-jitter_/2;
plot(X_matched,area_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1]), hold on
plot([0.97 1.03],[Area_DsxFru Area_DsxFru],'k','LineWidth',3)
plot([0.97 1.03],[Area_FlyWire Area_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)
xlim([0.9 1.1])
ha = gca;
ha.XTick = 1;
ha.XTickLabel = 'Area';
box off
%hl = legend('Matched Networks','Fru/Dsx','FlyWire'); hl.Box = 'off'; hl.Location = 'southwest';

subplot(3,10,25)%size
T = T_flywire(ismember(T_flywire.cellID,T_dsxfru.cellID),:);

Size_DsxFru = mean(T.size_nm);
Size_FlyWire = mean(T_flywire.size_nm);

%matched synapses
size_Matched = zeros(1,nMatched);
for ii = 1:nMatched
    T = T_flywire(ismember(T_flywire.cellID,T_matched{ii,:}),:);
    size_Matched(ii) = mean(T.size_nm);
end

hold off
X_matched = 1 + jitter_*randn(1,length(OutputSynapses_Matched))-jitter_/2;
plot(X_matched,size_Matched,'o','MarkerFaceColor',[137,115,178]/255,'MarkerEdgeColor',[1 1 1]), hold on
plot([0.97 1.03],[Size_DsxFru Size_DsxFru],'k','LineWidth',3)
plot([0.97 1.03],[Size_FlyWire Size_FlyWire],'Color',[0.5 0.5 0.5],'LineWidth',3)
xlim([0.9 1.1])
ha = gca;
ha.XTick = 1;
ha.XTickLabel = 'Size';
box off
%hl = legend('Matched Networks','Fru/Dsx','FlyWire'); hl.Box = 'off'; hl.Location = 'southwest';%save figure

filename = fullfile(figuresFolder, 'Fig1 - Methods and Stats', 'Fig_1S3_stats');
figsave(filename, gcf);


%% connectivity between vpoEN and LC31b and pC2l, DNp13 and pIP5.... (not part of the fru/dsx paper - just helps exploring)
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'connectivity between vpoEN and LC31b and pC2l, DNp13 and pIP5.... (not part of the fru/dsx paper - just helps exploring)');
% Need to run the first two cells first, to get the relevant tables.

tic

NAMES = {'AVLP029','vpoEN','LC31b','pC2la','pC2lb','pC2lc','pC2ld','DNp13','pIP5','aSP10a','pC1a','pC1b','pC1c','pC1d','pC1e'};

SYNAPSES = NaN(length(NAMES),length(NAMES));

for ii = 1:length(NAMES)
    for jj = 1:length(NAMES)
        PRE = T_dsxfru.cellID(strcmp(T_dsxfru.synonym,NAMES{ii}));%in the dsx/fru list
        if isempty(PRE)%vpoEN
            PRE = T_flywire.cellID(strcmp(T_flywire.cell_type,NAMES{ii}));%not in the dsx/fru list
        end

        POST = T_dsxfru.cellID(strcmp(T_dsxfru.synonym,NAMES{jj}));%not in the dsx/fru list
        if isempty(POST)%vpoEN
            POST = T_flywire.cellID(strcmp(T_flywire.cell_type,NAMES{jj}));%not in the dsx/fru list
        end

        idx = find(ismember(T_connectivity.pre_root_id,PRE) & ismember(T_connectivity.post_root_id,POST));

        SYNAPSES(ii,jj) = sum(T_connectivity.syn_count(idx));
    end
end

filename_saveVars = fullfile(figuresFolder, 'Fig9 - experimental validation', 'LocalConnectivity.mat');
save(filename_saveVars,'NAMES','SYNAPSES')

toc

% create and save a table
% Make sure NAMES is a column (15×1) for the first table column
cellType = NAMES(:);   % from 1x15 → 15x1

% MATLAB table variable names must be valid identifiers
varNames = matlab.lang.makeValidName(NAMES);

% Create table from the synapse matrix
T_syn = array2table(SYNAPSES, 'VariableNames', varNames);

% Add first column with cell type names
T = addvars(T_syn, cellType, 'Before', 1, 'NewVariableNames', 'cell_Type');

filename_saveTable = fullfile(figuresFolder, 'Fig9 - experimental validation', 'LocalConnectivity.xlsx');
writetable(T, filename_saveTable)

%% get the list of cells for ranks 1-3 from: Mech. JO; Olfactory; Gustatory; Visual Proj.
fprintf(1, '[%s] >>> %s\n', datestr(now,'HH:MM:SS'), 'get the list of cells for ranks 1-3 from: Mech. JO; Olfactory; Gustatory; Visual Proj.');

%!!!!!!!!!!!!!!! - make sure this is the correct version
%T_dsxfru_withFractions = readtable('/Users/ddeutsch/Dropbox/My Documents/MyOwnLab/Experiments/Connectomics/dsx_fru/Shared_dsxfru/data/Dsxfru_783_V15_updated.xlsx');
%!!!!!!!!!!!!!!!

modalities = [
    "mechanosensory_jo_notNormalized"
    "olfactory_notNormalized"
    "gustatory_notNormalized"
    "visual_projection_notNormalized"];

for i = 1:numel(modalities)
    colName = modalities(i);
    disp('====')
    disp(['Modality: ',colName])
    for rank = 1:4
        disp(['Rank = ',num2str(rank)])
        idx = find(T_dsxfru_withFractions.(colName)==rank);
        IDs = T_dsxfru_withFractions.cellID(idx);
        V = [];
        for ii = 1:length(IDs)
            V = [V,',',IDs{ii}];
        end
        V = V(2:end);%remove the first comma
        disp(V)
        disp(['N = ',num2str(length(IDs)),' cells'])

        %types
        TYPES = T_dsxfru_withFractions.subtype(idx);

        [uniqueStrings, ~, idx] = unique(TYPES);
        counts = accumarray(idx, 1);
        [~, order] = sort(counts, 'descend');
        sortedUnique = uniqueStrings(order);
        sortedCounts = counts(order);
        disp(sortedUnique)
        disp(sortedCounts')
    end
end