# AlphaFold Non-Docker setup

## Install miniconda

```
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh
```

## Create a new conda environment and update

```
conda create --name alphafold python==3.8
conda update -n base conda
```

## Activate conda environment

```
conda activate alphafold
```

## Install dependencies

- Change `cudnn==8.2.1` and `cudatoolkit==11.0.3` versions if they are not supported in your system

```
conda install -y -c anaconda cudnn==8.2.1
conda install -y -c bioconda hmmer hhsuite==3.3.0 kalign2
conda install -y -c conda-forge openmm==7.5.1 cudatoolkit==11.0.3 pdbfixer
```

## Download alphafold [git repo](https://github.com/deepmind/alphafold.git)

```
git clone https://github.com/deepmind/alphafold.git
alphafold_path="/path/to/alphafold/git/repo"
```

## Download chemical properties to the common folder

```
wget -q -P alphafold/alphafold/common/ https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt
```

## Install alphafold dependencies

- Change `jaxlib==0.1.69+cuda<111>` version if this is not supported in your system

_Note:_ jax updgrade: cuda111 supports cuda 11.3 - https://github.com/google/jax/issues/6628

```
pip install absl-py==0.13.0 biopython==1.79 chex==0.0.7 dm-haiku==0.0.4 dm-tree==0.1.6 immutabledict==2.0.0 jax==0.2.14 ml-collections==0.1.0 numpy==1.19.5 scipy==1.7.0 tensorflow==2.5.0

pip install --upgrade jax jaxlib==0.1.69+cuda111 -f https://storage.googleapis.com/jax-releases/jax_releases.html
```

## Apply OpenMM patch

```
# $alphafold_path variable is set to the alphafold git repo directory (absolute path)

cd ~/anaconda3/envs/alphafold/lib/python3.8/site-packages/ && patch -p0 < $alphafold_path/docker/openmm.patch

# or

cd ~/miniconda3/envs/alphafold/lib/python3.8/site-packages/ && patch -p0 < $alphafold_path/docker/openmm.patch
```

## Download all databases

- Follow https://github.com/deepmind/alphafold#genetic-databases

## Finally, running alphafold

- Use this [bash script](https://github.com/kalininalab/alphafold_non_docker/blob/main/run_alphafold.sh)

```
Usage: run_alphafold.sh <OPTIONS>
Required Parameters:
-d <data_dir>     Path to directory of supporting data
-o <output_dir>   Path to a directory that will store the results.
-m <model_names>  Names of models to use (a comma separated list)
-f <fasta_path>   Path to a FASTA file containing one sequence
-t <max_template_date> Maximum template release date to consider (ISO-8601 format - i.e. YYYY-MM-DD). Important if folding historical test sets
Optional Parameters:
-b <benchmark>    Run multiple JAX model evaluations to obtain a timing that excludes the compilation time, which should be more indicative of the time required for inferencing many proteins (default: 'False')
-g <use_gpu>      Enable NVIDIA runtime to run with GPUs(default: 'True')
-a <gpu_devices>  Comma separated list of devices to pass to NVIDIA_VISIBLE_DEVICES' (default: 'all')
-p <preset>       Choose preset model configuration - no ensembling (full_dbs) or 8 model ensemblings (casp14) (default: 'full_dbs')
```

- One can also edit the script and modify the `CUDA_VISIBLE_DEVICES` to a different GPU than the device with id '_0_' (default setting), or to use more devices just change it to, for example: `CUDA_VISIBLE_DEVICES=0,1,2`
- This script needs to be put into the top directory of the alphafold git repo that you have downloaded

```
# Directory structure
alphafold
├── alphafold
├── CONTRIBUTING.md
├── docker
├── example
├── imgs
├── LICENSE
├── README.md
├── requirements.txt
├── run_alphafold.py
├── run_alphafold.sh    <--- Copy the bash script and put it here
├── run_alphafold_test.py
├── scripts
└── setup.py
```

- Put your query sequence (only one sequence per fasta file) in a fasta file <filename.fasta>. Query sequence was obtained from [here](https://colab.research.google.com/drive/1qWO6ArwDMeba1Nl57kk_cQ8aorJ76N6x)
- Run the script

```
# Example run
bash run_alphafold.sh -d ./alphafold_data/ -o ./dummy_test/ -m model_1 -f ./example/query.fasta -t 2020-05-14
```

- The results folder `dummy_test` can be found in this git repo along with the query (`example/query.fasta`) used
- The arguments to the script follows the original naming of the alphafold parameters, except for `fasta_paths`. This script can do only one fasta query at a time. So use a terminal multiplexer (example: tmux/screen) to do multiple runs.
- For further information refer [here](https://github.com/deepmind/alphafold).
- Happy folding!

### Disclaimer

- We do not guarantee that this will work for everyone
- The non-docker version was tested with the following system configuration 
    - Dell server
        - CPU: AMD EPYC 7601 2.2 GHz
        - RAM: 1 TB
        - GPU: NVIDIA Tesla V100 16G
        - OS: CentOS 7 (kernel 3.10.0-1160.24.1.el7.x86_64)
        - Cuda: 11.3
        - NVIDIA driver version: 470.42.01
