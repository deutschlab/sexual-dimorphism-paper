# MATLAB setup

Both scripts in this folder compute their own paths relative to the
repository root (`repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))))`),
so no path editing is required beyond what's described below. Run them from
MATLAB with this folder's file open (or `cd` anywhere, since the scripts
locate themselves automatically).

## 1. Raw/external data (`data/raw/`)

`data/raw/` is not tracked in git (see `.gitignore`) because these files are
either very large or maintained by a separate project. Create the folder and
place the following files inside it before running `FruDsx_analysis.m` or
`FruDsx_Network_Layout.m`:

### `Supplemental_file1_neuron_annotations.tsv`
Published by Berg et al. (PMID 41279223). Download the version used for this
paper (pinned to commit `f02717b`):

```sh
curl -L -o data/raw/Supplemental_file1_neuron_annotations.tsv \
  https://raw.githubusercontent.com/flyconnectome/flywire_annotations/f02717b/supplemental_files/Supplemental_file1_neuron_annotations.tsv
```

### `connections_princeton783.csv`, `cell_stats783.csv`, `neurons783.csv`
Downloaded from [CODEX](https://codex.flywire.ai/?dataset=fafb), FlyWire
dataset version 783. CODEX exports these as compressed `.csv.gz` files - log
in to CODEX, select dataset version 783, export each table below, then unzip
to get the named `.csv` file:
- the connectivity/synapse table → unzip to get `connections_princeton783.csv`
- the cell statistics table (length/area/size per cell) → unzip to get `cell_stats783.csv`
- the neuron table (incl. neurotransmitter predictions) → unzip to get `neurons783.csv`

These were downloaded 2026-01-01; if CODEX's version-783 export differs, that
reflects an upstream data update rather than a change in the analysis.

## 2. The `sfas` Python package (used by `FruDsx_Network_Layout.m`)

The network layout script calls a small external Python package, `sfas`
(https://github.com/arie-matsliah/sfas), through MATLAB's `pyenv`/`py.*`
bridge. Set it up once:

```sh
conda create --name sfas python=3.10
conda activate sfas
git clone https://github.com/arie-matsliah/sfas.git ../sfas
python -m pip install ../sfas
conda run -n sfas which python   # copy this path
```

Then open `FruDsx_Network_Layout.m` and set `sfasPythonPath` (near the
`%% python environment` section) to the path printed above.

## 3. Helper functions (`src/matlab/helpers/`)

- `hex2rgb.m` - a small public utility by Chad A. Greene (MATLAB File
  Exchange, 2014), vendored here so the scripts run without any extra
  toolbox installation.
- `figsave.m` - saves the current figure to PNG and SVG.

Both are added to the path automatically by both scripts.

## 4. Outputs

Figures and intermediate tables are written to `figures/` and
`data/intermediate/` (both gitignored), created automatically on first run.
