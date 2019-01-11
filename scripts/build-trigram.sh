#!/bin/bash

# Copyright 2017  Speech Lab, EE Dept., IITM (Author: Srinivas Venkattaramanujam)

. ./path.sh
#. ./longaudio_vars.sh
working_dir=$1
input_file=$2
lang_dir=$3
tmp_dir=`mktemp -d`
echo "doing trigram lm"
build-lm.sh -i $input_file -o $working_dir/lm.gz -n 3 -t $tmp_dir && rm -rf $tmp_dir
compile-lm $working_dir/lm.gz -t=yes /dev/stdout | grep -v unk | gzip -c > $working_dir/lm.arpa.gz
gunzip -c $working_dir/lm.arpa.gz | arpa2fst --disambig-symbol=#0 --read-symbol-table=$lang_dir/words.txt - $lang_dir/G.fst

