#!/bin/bash
# Description: AlphaFold non-docker version
# Author: Sanjay Kumar Srikakulam

usage() {
        echo ""
        echo "Please make sure all required parameters are given"
        echo "Usage: $0 <OPTIONS>"
        echo "Required Parameters:"
        echo "-d <data_dir>         Path to directory of supporting data"
        echo "-o <output_dir>       Path to a directory that will store the results."
        echo "-f <fasta_paths>      Path to FASTA files containing sequences. If a FASTA file contains multiple sequences, then it will be folded as a multimer. To fold more sequences one after another, write the files separated by a comma"
        echo "-t <max_template_date> Maximum template release date to consider (ISO-8601 format - i.e. YYYY-MM-DD). Important if folding historical test sets"
        echo "Optional Parameters:"
        echo "-g <use_gpu>          Enable NVIDIA runtime to run with GPUs (default: true)"
        echo "-r <run_relax>        Whether to run the final relaxation step on the predicted models. Turning relax off might result in predictions with distracting stereochemical violations but might help in case you are having issues with the relaxation stage (default: true)"
        echo "-e <enable_gpu_relax> Run relax on GPU if GPU is enabled (default: true)"
        echo "-n <openmm_threads>   OpenMM threads (default: all available cores)"
        echo "-a <gpu_devices>      Comma separated list of devices to pass to 'CUDA_VISIBLE_DEVICES' (default: 0)"
        echo "-m <model_preset>     Choose preset model configuration - the monomer model, the monomer model with extra ensembling, monomer model with pTM head, or multimer model (default: 'monomer')"
        echo "-c <db_preset>        Choose preset MSA database configuration - smaller genetic database config (reduced_dbs) or full genetic database config (full_dbs) (default: 'full_dbs')"
        echo "-p <use_precomputed_msas> Whether to read MSAs that have been written to disk. WARNING: This will not check if the sequence, database or configuration have changed (default: 'false')"
        echo "-l <num_multimer_predictions_per_model> How many predictions (each with a different random seed) will be generated per model. E.g. if this is 2 and there are 5 models then there will be 10 predictions per input. Note: this FLAG only applies if model_preset=multimer (default: 5)"
        echo "-b <benchmark>        Run multiple JAX model evaluations to obtain a timing that excludes the compilation time, which should be more indicative of the time required for inferencing many proteins (default: 'false')"
        echo ""
        exit 1
}

while getopts ":d:o:f:t:g:r:e:n:a:m:c:p:l:b:" i; do
        case "${i}" in
        d)
                data_dir=$OPTARG
        ;;
        o)
                output_dir=$OPTARG
        ;;
        f)
                fasta_path=$OPTARG
        ;;
        t)
                max_template_date=$OPTARG
        ;;
        g)
                use_gpu=$OPTARG
        ;;
        r)
                run_relax=$OPTARG
        ;;
        e)
                enable_gpu_relax=$OPTARG
        ;;
        n)
                openmm_threads=$OPTARG
        ;;
        a)
                gpu_devices=$OPTARG
        ;;
        m)
                model_preset=$OPTARG
        ;;
        c)
                db_preset=$OPTARG
        ;;
        p)
                use_precomputed_msas=$OPTARG
        ;;
        l)
                num_multimer_predictions_per_model=$OPTARG
        ;;
        b)
                benchmark=$OPTARG
        ;;
        esac
done

# Parse input and set defaults
if [[ "$data_dir" == "" || "$output_dir" == "" || "$fasta_path" == "" || "$max_template_date" == "" ]] ; then
    usage
fi

if [[ "$benchmark" == "" ]] ; then
    benchmark=false
fi

if [[ "$use_gpu" == "" ]] ; then
    use_gpu=true
fi

if [[ "$gpu_devices" == "" ]] ; then
    gpu_devices=0
fi

if [[ "$run_relax" == "" ]] ; then
    run_relax="true"
fi

if [[ "$enable_gpu_relax" == "" ]] ; then
    enable_gpu_relax="true"
fi

if [[ "$enable_gpu_relax" == true && "$use_gpu" == true ]] ; then
    use_gpu_relax="true"
else
    use_gpu_relax="false"
fi

if [[ "$num_multimer_predictions_per_model" == "" ]] ; then
    num_multimer_predictions_per_model=5
fi

if [[ "$model_preset" == "" ]] ; then
    model_preset="monomer"
fi

if [[ "$model_preset" != "monomer" && "$model_preset" != "monomer_casp14" && "$model_preset" != "monomer_ptm" && "$model_preset" != "multimer" ]] ; then
    echo "Unknown model preset! Using default ('monomer')"
    model_preset="monomer"
fi

if [[ "$db_preset" == "" ]] ; then
    db_preset="full_dbs"
fi

if [[ "$db_preset" != "full_dbs" && "$db_preset" != "reduced_dbs" ]] ; then
    echo "Unknown database preset! Using default ('full_dbs')"
    db_preset="full_dbs"
fi

if [[ "$use_precomputed_msas" == "" ]] ; then
    use_precomputed_msas="false"
fi

# This bash script looks for the run_alphafold.py script in its current working directory, if it does not exist then exits
current_working_dir=$(pwd)
alphafold_script="$current_working_dir/run_alphafold.py"

if [ ! -f "$alphafold_script" ]; then
    echo "Alphafold python script $alphafold_script does not exist."
    exit 1
fi

# Export ENVIRONMENT variables and set CUDA devices for use
# CUDA GPU control
export CUDA_VISIBLE_DEVICES=-1
if [[ "$use_gpu" == true ]] ; then
    export CUDA_VISIBLE_DEVICES=0

    if [[ "$gpu_devices" ]] ; then
        export CUDA_VISIBLE_DEVICES=$gpu_devices
    fi
fi

# OpenMM threads control
if [[ "$openmm_threads" ]] ; then
    export OPENMM_CPU_THREADS=$openmm_threads
fi

# TensorFlow control
export TF_FORCE_UNIFIED_MEMORY='1'

# JAX control
export XLA_PYTHON_CLIENT_MEM_FRACTION='4.0'

# Path and user config (change me if required)
uniref90_database_path="$data_dir/uniref90/uniref90.fasta"
uniprot_database_path="$data_dir/uniprot/uniprot.fasta"
mgnify_database_path="$data_dir/mgnify/mgy_clusters_2022_05.fa"
bfd_database_path="$data_dir/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt"
small_bfd_database_path="$data_dir/small_bfd/bfd-first_non_consensus_sequences.fasta"
uniref30_database_path="$data_dir/uniref30/UniRef30_2021_03"
pdb70_database_path="$data_dir/pdb70/pdb70"
pdb_seqres_database_path="$data_dir/pdb_seqres/pdb_seqres.txt"
template_mmcif_dir="$data_dir/pdb_mmcif/mmcif_files"
obsolete_pdbs_path="$data_dir/pdb_mmcif/obsolete.dat"

# Binary path (change me if required)
hhblits_binary_path=$(which hhblits)
hhsearch_binary_path=$(which hhsearch)
jackhmmer_binary_path=$(which jackhmmer)
kalign_binary_path=$(which kalign)

command_args="--fasta_paths=$fasta_path --output_dir=$output_dir --max_template_date=$max_template_date --db_preset=$db_preset --model_preset=$model_preset --benchmark=$benchmark --use_precomputed_msas=$use_precomputed_msas --num_multimer_predictions_per_model=$num_multimer_predictions_per_model --run_relax=$run_relax --use_gpu_relax=$use_gpu_relax --logtostderr"

database_paths="--uniref90_database_path=$uniref90_database_path --mgnify_database_path=$mgnify_database_path --data_dir=$data_dir --template_mmcif_dir=$template_mmcif_dir --obsolete_pdbs_path=$obsolete_pdbs_path"

binary_paths="--hhblits_binary_path=$hhblits_binary_path --hhsearch_binary_path=$hhsearch_binary_path --jackhmmer_binary_path=$jackhmmer_binary_path --kalign_binary_path=$kalign_binary_path"

if [[ $model_preset == "multimer" ]]; then
	database_paths="$database_paths --uniprot_database_path=$uniprot_database_path --pdb_seqres_database_path=$pdb_seqres_database_path"
else
	database_paths="$database_paths --pdb70_database_path=$pdb70_database_path"
fi

if [[ "$db_preset" == "reduced_dbs" ]]; then
	database_paths="$database_paths --small_bfd_database_path=$small_bfd_database_path"
else
	database_paths="$database_paths --uniref30_database_path=$uniref30_database_path --bfd_database_path=$bfd_database_path"
fi

# Run AlphaFold with required parameters
$(python $alphafold_script $binary_paths $database_paths $command_args)
