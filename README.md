# AlphaFold Non-Docker setup

## **Setup and installation**
### **Install miniconda**

``` bash
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && bash Miniconda3-latest-Linux-x86_64.sh
```

### **Create a new conda environment and update**

``` bash
conda create --name alphafold python==3.8
conda update -n base conda
```

### **Activate conda environment**

``` bash
conda activate alphafold
```

### **Install dependencies**

- Change `cudatoolkit==11.2.2` version if it is not supported in your system

``` bash
conda install -y -c conda-forge openmm==7.5.1 cudatoolkit==11.2.2 pdbfixer
conda install -y -c bioconda hmmer hhsuite==3.3.0 kalign2
```

- Change `jaxlib==0.3.25+cuda11.cudnn805` version if this is not supported in your system

``` bash
pip install absl-py==1.0.0 biopython==1.79 chex==0.0.7 dm-haiku==0.0.9 dm-tree==0.1.6 immutabledict==2.0.0 jax==0.3.25 ml-collections==0.1.0 numpy==1.21.6 pandas==1.3.4 protobuf==3.20.1 scipy==1.7.0 tensorflow-cpu==2.9.0

pip install --upgrade --no-cache-dir jax==0.3.25 jaxlib==0.3.25+cuda11.cudnn805 -f https://storage.googleapis.com/jax-releases/jax_cuda_releases.html
```

### **Download alphafold release v2.3.1**

``` bash
wget https://github.com/deepmind/alphafold/archive/refs/tags/v2.3.1.tar.gz && tar -xzf v2.3.1.tar.gz && export alphafold_path="$(pwd)/alphafold-2.3.1"
```

### **Download chemical properties to the common folder**

``` bash
wget -q -P $alphafold_path/alphafold/common/ https://git.scicore.unibas.ch/schwede/openstructure/-/raw/7102c63615b64735c4941278d92b554ec94415f8/modules/mol/alg/src/stereo_chemical_props.txt
```

### **Apply OpenMM patch**

``` bash
# $alphafold_path variable is set to the alphafold git repo directory (absolute path)

cd ~/anaconda3/envs/alphafold/lib/python3.8/site-packages/ && patch -p0 < $alphafold_path/docker/openmm.patch

# or

cd ~/miniconda3/envs/alphafold/lib/python3.8/site-packages/ && patch -p0 < $alphafold_path/docker/openmm.patch
```

### **Download all databases**

- Option 1: Use our [download_db.sh script](https://github.com/kalininalab/alphafold_non_docker/blob/main/download_db.sh) which uses wget, rsync, gunzip and tar instead of aria2c
    - Our script maintains the AF2 [download directory structure](https://github.com/deepmind/alphafold#genetic-databases)
- Option 2: Follow https://github.com/deepmind/alphafold#genetic-databases

``` bash
# To use our download_db script (download the script first)
Usage: download_db.sh <OPTIONS>
Required Parameters:
-d <download_dir>     Absolute path to the AF2 download directory (example: /home/johndoe/alphafold_data)
Optional Parameters:
-m <download_mode>    full_dbs or reduced_dbs mode [default: full_dbs]

# To download all data (full_dbs mode)
# The script will create the folder </home/johndoe/alphafold_data> if it does not exist
bash download_db.sh -d </home/johndoe/alphafold_data>

# To download reduced version of the databases (reduced_dbs mode)
# The script will create the folder </home/johndoe/alphafold_data> if it does not exist
bash download_db.sh -d </home/johndoe/alphafold_data> -m reduced_dbs
```

## **Running alphafold (v2.3.1)**
- Use this [bash script](https://github.com/kalininalab/alphafold_non_docker/blob/main/run_alphafold.sh)

``` bash
Usage: run_alphafold.sh <OPTIONS>
Required Parameters:
-d <data_dir>         Path to directory of supporting data
-o <output_dir>       Path to a directory that will store the results.
-f <fasta_paths>      Path to FASTA files containing sequences. If a FASTA file contains multiple sequences, then it will be folded as a multimer. To fold more sequences one after another, write the files separated by a comma
-t <max_template_date> Maximum template release date to consider (ISO-8601 format - i.e. YYYY-MM-DD). Important if folding historical test sets
Optional Parameters:
-g <use_gpu>          Enable NVIDIA runtime to run with GPUs (default: true)
-r <run_relax>        Whether to run the final relaxation step on the predicted models. Turning relax off might result in predictions with distracting stereochemical violations but might help in case you are having issues with the relaxation stage (default: true)
-e <enable_gpu_relax> Run relax on GPU if GPU is enabled (default: true)
-n <openmm_threads>   OpenMM threads (default: all available cores)
-a <gpu_devices>      Comma separated list of devices to pass to 'CUDA_VISIBLE_DEVICES' (default: 0)
-m <model_preset>     Choose preset model configuration - the monomer model, the monomer model with extra ensembling, monomer model with pTM head, or multimer model (default: 'monomer')
-c <db_preset>        Choose preset MSA database configuration - smaller genetic database config (reduced_dbs) or full genetic database config (full_dbs) (default: 'full_dbs')
-p <use_precomputed_msas> Whether to read MSAs that have been written to disk. WARNING: This will not check if the sequence, database or configuration have changed (default: 'false')
-l <num_multimer_predictions_per_model> How many predictions (each with a different random seed) will be generated per model. E.g. if this is 2 and there are 5 models then there will be 10 predictions per input. Note: this FLAG only applies if model_preset=multimer (default: 5)
-b <benchmark>        Run multiple JAX model evaluations to obtain a timing that excludes the compilation time, which should be more indicative of the time required for inferencing many proteins (default: 'false')


```

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

- Put your query sequence in a fasta file <filename.fasta>.

    - In the below example query sequence was obtained from [here](https://colab.research.google.com/drive/1qWO6ArwDMeba1Nl57kk_cQ8aorJ76N6x)
- Running the script

```
# Example run (Uses the GPU with index id 0 as default)
bash run_alphafold.sh -d ./alphafold_data/ -o ./dummy_test/ -f ./example/query.fasta -t 2020-05-14

# OR for CPU only run
bash run_alphafold.sh -d ./alphafold_data/ -o ./dummy_test/ -f ./example/query.fasta -t 2020-05-14 -g False
```

- The results folder `dummy_test` can be found in this git repo along with the query (`example/query.fasta`) used
- The arguments to the script follows the original naming of the alphafold parameters, except for `fasta_paths`. This script can do only one fasta query at a time. So use a terminal multiplexer (example: tmux/screen) to do multiple runs.
- One can also control the number of cores used by OpenMM using the `-n` argument (dafult: uses all available cores)
- For further information refer [here](https://github.com/deepmind/alphafold)

### **Running AlphaFold-Multimer**
- All steps are the same as when running the monomer system, but you will have to
    - provide an input fasta with multiple sequences,
    - set *-m multimer* option when running *run_alphafold.sh* script,

    ```
    # Example run (Uses the GPU with index id 0 as default)
    bash run_alphafold.sh -d alphafold_data/ -o dummy_test/ -f multimer_query.fasta -t 2021-11-01 -m multimer
    ```

### **Examples (Modified from [AF2](https://github.com/deepmind/alphafold#examples))**

Below are examples on how to use AlphaFold in different scenarios.

#### **Folding a monomer**

Say we have a monomer with the sequence `<SEQUENCE>`. The input fasta should be:

```fasta
>sequence_name
<SEQUENCE>
```

Then run the following command:

```bash
bash run_alphafold.sh -d alphafold_data/ -o dummy_test/ -f monomer.fasta -t 2021-11-01 -m monomer
```

#### **Folding a homomer**

Say we have a homomer from a prokaryote with 3 copies of the same sequence
`<SEQUENCE>`. The input fasta should be:

```fasta
>sequence_1
<SEQUENCE>
>sequence_2
<SEQUENCE>
>sequence_3
<SEQUENCE>
```

Then run the following command:

```bash
bash run_alphafold.sh -d alphafold_data/ -o dummy_test/ -f homomer.fasta -t 2021-11-01 -m multimer
```

#### **Folding a heteromer**

Say we have a heteromer A2B3 of unknown origin, i.e. with 2 copies of
`<SEQUENCE A>` and 3 copies of `<SEQUENCE B>`. The input fasta should be:

```fasta
>sequence_1
<SEQUENCE A>
>sequence_2
<SEQUENCE A>
>sequence_3
<SEQUENCE B>
>sequence_4
<SEQUENCE B>
>sequence_5
<SEQUENCE B>
```

Then run the following command:

```bash
bash run_alphafold.sh -d alphafold_data/ -o dummy_test/ -f heteromer.fasta -t 2021-11-01 -m multimer
```

## API changes

### **API changes between v2.2.0 and v2.3.1**
- AF2 parameters link and database download links have been updated.
- Updated package requirements

### **API changes between v2.1.1 and v2.2.0**
- The is_prokaryote option *-l* is removed.
- New option *-l* is now used for setting the number of multimer predictions per model
- Options for relaxation *-r* and to enable GPU relaxation *-e* are added
- AF2 parameters link has been updated in the download_db.sh script (users should download this new parameters when using AF2 v2.2.0)

### **API changes between v2.0.0 and v2.1.1**
- The preset flag *-p* was split into *-c* (db_preset) and *-m* (model_preset) in our *run_alphafold.sh*
    - Four model presets (for option *-m*) are now supported
        - monomer
        - monomer_casp14
        - monomer_ptm
        - multimer
    - Two db preset configurations (for option *-c*) are supported
        - full_dbs
        - reduced_dbs
- The model names to use are not specified using *-m* option anymore. If you want to customize model names you will have to modify the appropriate MODEL_PRESETS dictionary in *alphafold/model/config.py*

## **Disclaimer**

- We do not guarantee that this will work for everyone
- The non-docker version was tested with the following system configuration
    - Dell server
        - CPU: AMD EPYC 7601 2.2 GHz
        - RAM: 1 TB
        - GPU: NVIDIA Tesla V100 16G
        - OS: CentOS 7 (kernel 3.10.0-1160.24.1.el7.x86_64)
        - Cuda: 11.3
        - NVIDIA driver version: 470.42.01
    - Storage
        - Downloaded database size: 2.2 TB (uncompressed)
