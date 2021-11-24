#!/bin/bash
# Description: Downloads and unzips all required data for AlphaFold2 (AF2).
# Author: Sanjay Kumar Srikakulam

# Since some parts of the script may resemble AlphaFold's download scripts copyright and License notice is added.
# Copyright 2021 DeepMind Technologies Limited
# Licensed under the Apache License, Version 2.0 (the "License");
# You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

set -e

# Input processing
usage() {
        echo ""
        echo "Please make sure all required parameters are given"
        echo "Usage: $0 <OPTIONS>"
        echo "Required Parameters:"
        echo "-d <download_dir>     Absolute path to the AF2 download directory (example: /home/johndoe/alphafold_data)"
        echo "Optional Parameters:"
        echo "-m <download_mode>    full_dbs or reduced_dbs mode [default: full_dbs]"
        echo ""
        exit 1
}

while getopts ":d:m:" i; do
        case "${i}" in
        d)
                download_dir=$OPTARG
        ;;
        m)
                download_mode=$OPTARG
        ;;
        esac
done

if [[  $download_dir == "" ]]; then
    usage
fi

if [[  $download_mode == "" ]]; then
    download_mode="full_dbs"
fi

if [[ $download_mode != "full_dbs" && $download_mode != "reduced_dbs" ]]; then
    echo "Download mode '$download_mode' is not recognized"
    usage
fi

# Check if rsync, wget, gunzip and tar command line utilities are available
check_cmd_line_utility(){
    cmd=$1
    if ! command -v "$cmd" &> /dev/null; then
        echo "Command line utility '$cmd' could not be found. Please install."
        exit 1
    fi    
}

check_cmd_line_utility "wget"
check_cmd_line_utility "rsync"
check_cmd_line_utility "gunzip"
check_cmd_line_utility "tar"

# Make AF2 data directory structure
params="$download_dir/params"
mgnify="$download_dir/mgnify"
pdb70="$download_dir/pdb70"
pdb_mmcif="$download_dir/pdb_mmcif"
mmcif_download_dir="$pdb_mmcif/data_dir"
mmcif_files="$pdb_mmcif/mmcif_files"
uniclust30="$download_dir/uniclust30"
uniref90="$download_dir/uniref90"
uniprot="$download_dir/uniprot"
pdb_seqres="$download_dir/pdb_seqres"

download_dir=$(realpath "$download_dir")
mkdir --parents "$download_dir"
mkdir "$params" "$mgnify" "$pdb70" "$pdb_mmcif" "$mmcif_download_dir" "$mmcif_files" "$uniclust30" "$uniref90" "$uniprot" "$pdb_seqres"

# Download AF2 parameters
echo "Downloading AF2 parameters"
params_filename="alphafold_params_2021-10-27.tar"
wget -P "$params" "https://storage.googleapis.com/alphafold/alphafold_params_2021-10-27.tar"
tar --extract --verbose --file="$params/$params_filename" --directory="$params" --preserve-permissions
rm "$params/$params_filename"

# Download BFD/Reduced BFD database
if [[ "$download_mode" = "full_dbs" ]]; then
    echo "Downloading BFD database"
    bfd="$download_dir/bfd"
    mkdir "$bfd"
    bfd_filename="bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz"
    wget -P "$bfd" "https://storage.googleapis.com/alphafold-databases/casp14_versions/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt.tar.gz"
    tar --extract --verbose --file="$bfd/$bfd_filename" --directory="$bfd"
    rm "$bfd/$bfd_filename"
else
    echo "Downloading reduced BFD database"
    small_bfd="$download_dir/small_bfd"
    mkdir "$small_bfd"
    small_bfd_filename="bfd-first_non_consensus_sequences.fasta.gz"
    wget -P "$small_bfd" "https://storage.googleapis.com/alphafold-databases/reduced_dbs/bfd-first_non_consensus_sequences.fasta.gz"
    (cd "$small_bfd" && gunzip "$small_bfd/$small_bfd_filename")
fi

# Download MGnify database
echo "Downloading MGnify database"
mgnify_filename="mgy_clusters_2018_12.fa.gz"
wget -P "$mgnify" "https://storage.googleapis.com/alphafold-databases/casp14_versions/${mgnify_filename}"
(cd "$mgnify" && gunzip "$mgnify/$mgnify_filename")

# Download PDB70 database
echo "Downloading PDB70 database"
pdb70_filename="pdb70_from_mmcif_200401.tar.gz"
wget -P "$pdb70" "http://wwwuser.gwdg.de/~compbiol/data/hhsuite/databases/hhsuite_dbs/old-releases/${pdb70_filename}"
tar --extract --verbose --file="$pdb70/$pdb70_filename" --directory="$pdb70"
rm "$pdb70/$pdb70_filename"

# Download PDB obsolete data
wget -P "$pdb_mmcif" "ftp://ftp.wwpdb.org/pub/pdb/data/status/obsolete.dat"

# Download PDB mmCIF database
echo "Downloading PDB mmCIF database"
rsync --recursive --links --perms --times --compress --info=progress2 --delete --port=33444 rsync.rcsb.org::ftp_data/structures/divided/mmCIF/ "$mmcif_download_dir"
find "$mmcif_download_dir/" -type f -iname "*.gz" -exec gunzip {} +
find "$mmcif_download_dir" -type d -empty -delete

for sub_dir in "$mmcif_download_dir"/*; do
  mv "$sub_dir/"*.cif "$mmcif_files"
done

find "$mmcif_download_dir" -type d -empty -delete

# Download Uniclust30 database
echo "Downloading Uniclust30 database"
uniclust30_filename="uniclust30_2018_08_hhsuite.tar.gz"
wget -P "$uniclust30" "https://storage.googleapis.com/alphafold-databases/casp14_versions/${uniclust30_filename}"
tar --extract --verbose --file="$uniclust30/$uniclust30_filename" --directory="$uniclust30"
rm "$uniclust30/$uniclust30_filename"

# Download Uniref90 database
echo "Downloading Unifef90 database"
uniref90_filename="uniref90.fasta.gz"
wget -P "$uniref90" "ftp://ftp.uniprot.org/pub/databases/uniprot/uniref/uniref90/${uniref90_filename}"
(cd "$uniref90" && gunzip "$uniref90/$uniref90_filename")

# Download Uniprot database
echo "Downloading Uniprot (TrEMBL and Swiss-Prot) database"
trembl_filename="uniprot_trembl.fasta.gz"
trembl_unzipped_filename="uniprot_trembl.fasta"
wget -P "$uniprot" "ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/${trembl_filename}"
(cd "$uniprot" && gunzip "$uniprot/$trembl_filename")

sprot_filename="uniprot_sprot.fasta.gz"
sprot_unzipped_filename="uniprot_sprot.fasta"
wget -P "$uniprot" "ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/complete/${sprot_filename}"
(cd "$uniprot" && gunzip "$uniprot/$sprot_filename")

# Concatenate TrEMBL and Swiss-Prot, rename to uniprot and clean up.
cat "$uniprot/$sprot_unzipped_filename" >> "$uniprot/$trembl_unzipped_filename"
mv "$uniprot/$trembl_unzipped_filename" "$uniprot/uniprot.fasta"
rm "$uniprot/$sprot_unzipped_filename"

# Download PDB seqres database
wget -P "$pdb_seqres" "ftp://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt"

echo "All AF2 required data is downloaded"
