#!/bin/bash

# Copyright 2017  Speech Lab, EE Dept., IITM (Author: Srinivas Venkattaramanujam)

# find 2000h -name '*0' -type d | xargs -n 1 -P 20 ./longaudio_forcealign.sh --stage 2 --data-dir
# may also work differently: cat 2000.2.sh | xargs -n 1 -d "\n" -P 20 bash -c

# cat 2000h.2.sh | sed 's/--working.*true //' | awk '{printf("echo -e \\#\\!/bin/bash\\\\n\\#SBATCH --workdir=/data/VOL1/fmetze/kaldi-long-audio-alignment\\\\n\\#SBATCH --output=/scratch/slurm-%j.out\\\\n\\#SBATCH --export=ALL\\\\n%s | sbatch\n", $0)}' > v && chmod 755 v & ./v

# find 2000h -name '*0' -type d | awk '{print $1,$1 }' | xargs -n 2 -P 20 sh -c './longaudio_forcealign.sh --stage 2 --data-dir "$1" >\\& $0.log'

. ./path.sh # ensure kaldi, IRSTLM and sctk are in path
. ./cmd.sh
. ./longaudio_vars.sh
set -e
stage=0
working_dir=""
create_dir="true"
while [[ $# -gt 1 ]]
do
	arg=$1
	case $arg in
		--working-dir)
			working_dir=$2
			shift
			shift
			;;
		--data-dir)
			data_dir=$2
			shift
			shift
			;;
		--stage)
			stage=$2
			shift
			shift
			;;
		--create-dir)
			create_dir=$2
			shift
			shift
			;;			
	esac
done;
if [ -z "$working_dir" ]; then
    working_dir=`mktemp -dp /scratch`
fi
data_dir=`echo $data_dir | sed "s/\/$//"`
new_dir=${data_dir}_segmented
segment_store=$working_dir/segments_store
log_dir=$working_dir/log
mkdir -p $working_dir
mkdir -p $log_dir
mkdir -p $segment_store
mkdir -p $working_dir/tmp/mfccdir

# Florian - we should really create links to these folders in the working directory
# before we use them and add stuff to them, we should not link stuff that we will
# generate, i.e. G.fst
mkdir -p $working_dir/model
ln -st $working_dir/model $(realpath -s $model_dir/*)
model_dir=$working_dir/model
graph_dir=$model_dir/graph
rm -f $graph_dir && mkdir $graph_dir
mkdir $working_dir/lang && \
    ln -st $working_dir/lang $(realpath -s $lang_dir/words.txt $lang_dir/L.fst $lang_dir/L_disambig.fst $lang_dir/phones.txt $lang_dir/phones) && \
    lang_dir=$working_dir/lang
[ -f $lang_dir/silence.csl ] && ln -st $working_dir/lang $(realpath -s $lang_dir/silence.csl)
mkdir $working_dir/data && \
    cp $data_dir/wav.scp $data_dir/text $working_dir/data && \
    data_dir=$working_dir/data && \
    awk '{print $1,$1}' $data_dir/wav.scp | tee $data_dir/utt2spk > $data_dir/spk2utt

if [ $stage -ge 1 ]; then
    # mfcc and cmvn
    #(rm $data_dir/segments || echo "") >> $log_dir/output.log 2>&1
    (mv $data_dir/text $data_dir/text_1 > $log_dir/output.log 2>$log_dir/err.log) || exit 1
    echo "Making feats in $working_dir"
    if [ 1 -gt 0 ]; then
	scripts/make-feats.sh $data_dir/wav.scp $working_dir $log_dir $data_dir 2> $log_dir/err.log
	# VAD and segmentation based on VAD
	#head -1 $data_dir/feats.scp
	echo "Doing VAD segments"
	(compute-vad scp:$data_dir/feats.scp ark,t:- 2> $log_dir/err.log || exit 1) | tee $working_dir/vad.ark | sed -e 's/.*\[ *//' -e 's/ *\] *//' | tr ' ' '\n' | uniq -c | awk 'BEGIN { i=0; a=0.0; s=1000 }; {if ($2==1) { while ($1 > s) { print "segment_"i,"key_1",a/100,(a+s)/100; i+=1; $1-=s; a+=s }; print "segment_"i,"key_1",a/100,(a+$1)/100; i+=1 }; a+=$1}' | tee $working_dir/segments > $data_dir/segments
	# split_vad.py considers even one frame of 0 (silence) as potential breakpoint. But you might want to change it
	#(scripts/split_vad.py $working_dir/vad.ark  2> ${log_dir}/err.log || exit 1) | sort > $data_dir/segments 
	#cp $data_dir/segments $working_dir/segments 2> $log_dir/err.log || exit 1
	echo "Computing features for segments obtained using VAD"
	scripts/make-feats.sh $data_dir/segments $working_dir $log_dir $data_dir 2>${log_dir}/err.log
    else
	steps/make_mfcc.sh --nj 1 $data_dir $working_dir/tmp/logdir/ $working_dir/tmp/vaddir 2>${log_dir}/err.log
	feat-to-len scp:$data_dir/feats.scp | awk '{printf ("%s %s %f %f\n", "segment_0", "key_1", 0.0, 0.01*$1)}' | tee $working_dir/segments > $data_dir/segments
	sed -i 's/key_1/segment_0/' $data_dir/feats.scp
	awk '{print $1,$1}' $data_dir/feats.scp | tee $data_dir/utt2spk > $data_dir/spk2utt
	echo "Doing VAD"
	(compute-vad scp:$data_dir/feats.scp ark,t:$working_dir/tmp/vaddir/vad.ark 2> $log_dir/err.log || exit 1)
	(select-voiced-frames scp:$data_dir/feats.scp ark,t:$working_dir/tmp/vaddir/vad.ark ark:- | copy-feats ark:- ark,scp:$working_dir/tmp/mfccdir/feats-vad.ark,$data_dir/feats-vad.scp 2> $log_dir/err.log || exit 1)
	mv $data_dir/feats.scp $data_dir/feats-novad.scp && mv $data_dir/feats-vad.scp $data_dir/feats.scp
	steps/compute_cmvn_stats.sh $data_dir $working_dir/tmp/logdir/ $working_dir/tmp/cmvndir >> $log_dir/output.log 2> $log_dir/err.log
    fi
    
    echo "Preparing text files: text_actual"
    (cat $data_dir/text_1 2> $log_dir/err.log || exit 1) | cut -d' ' -f2- | sed 's/^ \+//g' | sed 's/ \+$//g' | tr -s ' ' > $working_dir/text_actual 
    echo "Preparing text files: lm_text"
    (cat $working_dir/text_actual 2> $log_dir/err.log || exit 1) | sed -e 's:^:<s> :' -e 's:$: </s>:' > $working_dir/lm_text
    echo "Preparing text files: initializing WORD_TIMINGS file with all -1 -1"
    (scripts/sym2int.py ${lang_dir}/words.txt $working_dir/text_actual 2> $log_dir/err.log || exit 1) | tr ' ' '\n' | sed 's/$/ -1 -1/g' > $working_dir/WORD_TIMINGS
    #echo "Preparation of text files over in $working_dir"
    if [ 1 -gt 0 ]; then
	echo "Preparing trigram LM"
	scripts/build-trigram.sh $working_dir $working_dir/lm_text $lang_dir >> $log_dir/output.log 2> $log_dir/err.log || exit 1
	#echo "Trigram LM created using $working_dir/lm_text"
    else
	echo "Preparing transducer"
	scripts/build-transducer.sh $working_dir $working_dir/text_actual false $lang_dir
	#echo "Transducer created using $working_dir/text_actual"
    fi
    # build graph and decode
    echo "Executing build-graph-decode-hyp.sh"
    num_lines=`wc -l $data_dir/feats.scp | cut -d' ' -f1` # min of num_lines and 20 for num_jobs
    # $(($num_lines>20?20:$num_lines))
    scripts/build-graph-decode-hyp.sh 1 decode $working_dir $log_dir $data_dir $lang_dir $model_dir $graph_dir $island_length 2> $log_dir/err.log || exit 1
    # create a status file which specifies which segments are done and pending and save timing information for each aligned word
    num_text_words=`wc -w $working_dir/text_ints | cut -d' ' -f1`
    text_end_index=$((num_text_words-1))
    audio_duration=`(wav-to-duration --read-entire-file scp:$data_dir/wav.scp ark,t:- 2>> $log_dir/output.log) | cut -d' ' -f2`
    scripts/make-status-and-word-timings.sh $working_dir $working_dir 0 $text_end_index 0.00 $audio_duration $log_dir 2> $log_dir/err.log || (echo "Failed: make-status-and-word-timings.sh" && exit 1)
    utils/int2sym.pl -f 1 $lang_dir/words.txt  $working_dir/WORD_TIMINGS > $working_dir/WORD_TIMINGS.iter0
    echo "Iter 0 decode over (`grep -- -1 $working_dir/WORD_TIMINGS | wc -l`)"
fi

if [ $stage -ge 2 ]; then 
segment_id=`wc -l $working_dir/segments | cut -d' ' -f1`
for x in `seq 1 $((num_iters-1))`;do
#	echo "segment id is $segment_id"
	# grep PENDING from status file
	# for each PENDING entry, do; tc of segment_id
	# make segment file, utt2spk, spk2utt
	# make lm
	# mkgraph
	# decode
	# get the decoded output and put in the TEMPSTATUS file
	# merge TEMPSTATUS and STATUS
	# repeat
	echo "Doing iteration ${x}. Starting segment id: $segment_id"
	while read y; do
		echo $y >> $log_dir/output.log
		mkdir -p $segment_store/${segment_id}
		# make segments 10-15 seconds segments TODO
		echo "segment_$segment_id key_1 `echo $y | cut -d' ' -f 1,2 `" > $data_dir/segments
		scripts/make-feats.sh $data_dir/segments $working_dir $log_dir $data_dir 2>${log_dir}/err.log
		cp $data_dir/segments $segment_store/${segment_id}/segments
		time_begin="`echo $y | cut -d' ' -f1`"
		time_end="`echo $y | cut -d' ' -f2`"
		word_begin_index=`echo $y | cut -d' ' -f4 `
		word_begin_index=$((word_begin_index+1))
		word_end_index=`echo $y | cut -d' ' -f5`
		word_end_index=$((word_end_index+1))
		word_string=`cat $working_dir/text_actual | cut -d' ' -f $word_begin_index-$word_end_index`
		word_begin_index=$((word_begin_index-1))
		word_end_index=$((word_end_index-1))
		echo "<s> $word_string </s>" > $segment_store/${segment_id}/lm_text
		echo "$word_string" > $segment_store/${segment_id}/text_actual
		if [ $x -eq $((num_iters-3)) ]; then
			scripts/build-transducer.sh $segment_store/${segment_id} $segment_store/${segment_id}/text_actual false $lang_dir >> $log_dir/output.log 2> $log_dir/err.log || (echo "Failed $segment_id: build-transducer.sh false")
			#exit 1
		elif [ $x -eq $((num_iters-2)) ]; then
			scripts/build-transducer.sh $segment_store/${segment_id} $segment_store/${segment_id}/text_actual true $lang_dir >> $log_dir/output.log 2> $log_dir/err.log || (echo "Failed $segment_id: build-transducer.sh true")
		        #exit 1
		else
			scripts/build-trigram.sh $segment_store/${segment_id} $segment_store/${segment_id}/lm_text $lang_dir >> $log_dir/output.log 2> $log_dir/err.log || (echo "Failed $segment_id: build-trigram.sh")
			#exit 1
		fi
		scripts/build-graph-decode-hyp.sh 1 decode_${segment_id} $segment_store/${segment_id} $log_dir $data_dir $lang_dir $model_dir $graph_dir $island_length 2> $log_dir/err.log || \
		    (scripts/build-trigram.sh $segment_store/${segment_id} $segment_store/${segment_id}/lm_text $lang_dir >> $log_dir/output.log 2> $log_dir/err.log && scripts/build-graph-decode-hyp.sh 1 decode_${segment_id} $segment_store/${segment_id} $log_dir $data_dir $lang_dir $model_dir $graph_dir $island_length 2> $log_dir/err.log)
		scripts/make-status-and-word-timings.sh $working_dir $segment_store/${segment_id} \
							$word_begin_index $word_end_index $time_begin $time_end $log_dir 2> $log_dir/err.log || (echo "Failed $segment_id: make-status-and-word-timings.sh" && (echo $y > $segment_store/${segment_id}/ALIGNMENT_STATUS))
		cat $segment_store/${segment_id}/ALIGNMENT_STATUS >> $working_dir/ALIGNMENT_STATUS.working.iter${x} # this file is appended with ALIGNMENT_STATUS of each segment of the iteration.
		segment_id=$((segment_id+1))
	done < <(cat $working_dir/ALIGNMENT_STATUS | grep PENDING)
	utils/int2sym.pl -f 1 $lang_dir/words.txt  $working_dir/WORD_TIMINGS > $working_dir/WORD_TIMINGS.iter${x}
	cp $working_dir/ALIGNMENT_STATUS $working_dir/ALIGNMENT_STATUS.iter$((x-1))
	cat $working_dir/ALIGNMENT_STATUS | grep 'DONE' > $working_dir/ALIGNMENT_STATUS.tmp
	cat $working_dir/ALIGNMENT_STATUS.working.iter${x} >> $working_dir/ALIGNMENT_STATUS.tmp
	cat $working_dir/ALIGNMENT_STATUS.tmp | sort -s -k 1,1n > $working_dir/ALIGNMENT_STATUS.tmp2
	# clean up the alignment file so that ALIGNMENT_STATUS has DONE and PENDING in alternate lines
	echo "Cleaning up Alignment Status" >> $log_dir/output.log
	scripts/cleanup_status.py $working_dir/ALIGNMENT_STATUS.tmp2 > $working_dir/ALIGNMENT_STATUS
	rm $working_dir/ALIGNMENT_STATUS.tmp*
	rm $working_dir/ALIGNMENT_STATUS.working.iter${x} # might need for debugging
done;
fi

#rm -r $model_dir/decode_* || echo ""
#echo "converting integer ids to words in"
utils/int2sym.pl -f 1 $lang_dir/words.txt  $working_dir/WORD_TIMINGS > $working_dir/WORD_TIMINGS.words
#rm -rf $data_dir
#mv ${data_dir}.laa.bkp $data_dir
if [ $create_dir == "true" ]; then
	echo "Creating $new_dir"
	mkdir -p $new_dir
	x=`echo "$data_dir" | rev | cut -d'/' -f1 | rev`
	# the following script makes a segment with 10 words but if there is no timing info for the 10th word, we proceed until we find a word with known timing
	scripts/timing_to_segment_and_text.py $working_dir/WORD_TIMINGS.words $x $new_dir/segments $new_dir/text `(wav-to-duration --read-entire-file scp:${data_dir}/wav.scp ark,t:- 2>> $log_dir/output.log) | cut -d' ' -f2`
	echo "${x} `cat ${data_dir}/wav.scp|cut -d' ' -f2-`" > $new_dir/wav.scp
	cut -d ' ' -f1 $new_dir/segments | sed "s/$/ $x/g" > $new_dir/utt2spk
	cut -d ' ' -f1 $new_dir/segments | sed "s/^/$x /g" > $new_dir/spk2utt
	cp $working_dir/vad.ark $working_dir/WORD_TIMINGS.words $new_dir
	[ -f $new_dir/WORD_TIMINGS.words ] || cp -f $working_dir/WORD_TIMINGS.iter2 $new_dir/WORD_TIMINGS.words
	[ -f $new_dir/WORD_TIMINGS.words ] || cp -f $working_dir/WORD_TIMINGS.iter1 $new_dir/WORD_TIMINGS.words
	[ -f $new_dir/WORD_TIMINGS.words ] || cp -f $working_dir/WORD_TIMINGS.iter0 $new_dir/WORD_TIMINGS.words
fi

touch $new_dir/.done
echo "Finished successfully (`grep -- -1 $working_dir/WORD_TIMINGS | wc -l`)"
