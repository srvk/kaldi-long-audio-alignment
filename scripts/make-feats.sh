#!/bin/bash

# Copyright 2017  Speech Lab, EE Dept., IITM (Author: Srinivas Venkattaramanujam)

#. ./longaudio_vars.sh
source_file=$1
working_dir=$2
log_dir=$3
data_dir=$4
(rm -f $data_dir/feats.scp $data_dir/cmvn.scp || echo "") >> $log_dir/output.log 2>&1

awk '{print $1,$1}' $source_file | tee $data_dir/utt2spk | \
    ./utils/utt2spk_to_spk2utt.pl > $data_dir/spk2utt
utils/fix_data_dir.sh $data_dir > /dev/null 2>&1

#cut -d' ' -f1<$source_file > $working_dir/utt 2> $log_dir/err.log
#paste $working_dir/utt $working_dir/utt | sort > $data_dir/utt2spk
#cp $data_dir/utt2spk $data_dir/spk2utt
#rm $working_dir/utt
#(rm $data_dir/feats.scp $data_dir/cmvn.scp || echo "") >> $log_dir/output.log 2>&1

steps/make_mfcc.sh --nj 1  $data_dir $working_dir/tmp/logdir/ $working_dir/tmp/mfccdir >> $log_dir/output.log 2> $log_dir/err.log
steps/compute_cmvn_stats.sh $data_dir $working_dir/tmp/logdir/ $working_dir/tmp/cmvndir >> $log_dir/output.log 2> $log_dir/err.log
