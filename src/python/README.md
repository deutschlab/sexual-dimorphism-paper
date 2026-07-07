# Python setup

The plotting code requires Python 3.12 or newer. A small Conda environment is
recommended:

```sh
conda create --name sexual-dimorphism python=3.12
conda activate sexual-dimorphism
python -m pip install -r src/python/requirements.txt
git clone https://github.com/koonimaru/radialtree.git ../radialtree
python -m pip install ../radialtree
```

Run these commands from the repository root. The clone is placed beside this
repository to keep the working tree clean.
