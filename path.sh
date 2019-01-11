export KALDI_ROOT=`pwd`/../kaldi
#DIRNAME=`pwd` && export KALDI_ROOT="${DIRNAME%/*/*/*}"
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:../kaldi/tools/irstlm/scripts:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh
export PATH=$KALDI_ROOT/tools/sctk/bin:$PATH
export LC_ALL=C

#export PATH=$KALDI_ROOT/tools/sctk/bin:$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:/data/ASR1/tools/sox-14.4.2/install/bin:/opt/python34/bin:/home/python27:/home/python27/bin:/opt/gcc/4.9.2/bin:/opt/perl/bin:/data/ASR5/fmetze/kaldi-latest/tools/sctk/bin:/data/ASR5/fmetze/kaldi-latest/src/bin:/data/ASR5/fmetze/kaldi-latest/src/chainbin:/data/ASR5/fmetze/kaldi-latest/src/featbin:/data/ASR5/fmetze/kaldi-latest/src/fgmmbin:/data/ASR5/fmetze/kaldi-latest/src/fstbin:/data/ASR5/fmetze/kaldi-latest/src/gmmbin:/data/ASR5/fmetze/kaldi-latest/src/ivectorbin:/data/ASR5/fmetze/kaldi-latest/src/kwsbin:/data/ASR5/fmetze/kaldi-latest/src/latbin:/data/ASR5/fmetze/kaldi-latest/src/lmbin:/data/ASR5/fmetze/kaldi-latest/src/nnet2bin:/data/ASR5/fmetze/kaldi-latest/src/nnet3bin:/data/ASR5/fmetze/kaldi-latest/src/nnetbin:/data/ASR5/fmetze/kaldi-latest/src/online2bin:/data/ASR5/fmetze/kaldi-latest/src/onlinebin:/data/ASR5/fmetze/kaldi-latest/src/rnnlmbin:/data/ASR5/fmetze/kaldi-latest/src/sgmm2bin:/data/ASR5/fmetze/kaldi-latest/src/sgmmbin:/data/ASR5/fmetze/kaldi-latest/src/tfrnnlmbin:/data/ASR5/fmetze/kaldi-latest/egs/aspire/s5/utils/:/data/ASR5/fmetze/kaldi-latest/tools/openfst/bin:/data/ASR5/fmetze/kaldi-latest/egs/aspire/s5:/opt/autoconf-2.68/bin/:/opt/automake-1.10.3/bin/:/opt/python27/bin:/opt/openmpi/bin:/usr/lib64/qt-3.3/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/opt/ganglia/bin:/opt/ganglia/sbin:/usr/java/latest/bin:/opt/maui/bin:/opt/torque/bin:/opt/torque/sbin:/opt/rocks/bin:/opt/rocks/sbin:/home/fmetze/bin

#export PATH=$PATH:/data/ASR5/fmetze/kaldi-latest/tools/irstlm/bin
#export IRSTLM=/data/ASR5/fmetze/kaldi-latest/tools/irstlm
#../kaldi/tools/irstlm
export IRSTLM=/usr/lib/irstlm
export PATH=$PATH:$IRSTLM/bin
