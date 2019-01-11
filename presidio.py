#!/usr/bin/env python

# This script will create the data folder to run this thing on
# a presidio-style file

# To use:
# presidio.py file.mp3 file.stm words.txt folder


from __future__ import print_function

import json, zipfile, glob, os, sys, datetime, string, re


def main(audio, stm, words, outdir):
    #
    # main function
    #
    key='key_1'
    with open(os.path.join(outdir, 'utt2spk'), 'w') as fp:
        print ('{k:s} {k:s}'.format(k=key), file=fp)
    with open(os.path.join(outdir, 'spk2utt'), 'w') as fp:
        print ('{k:s} {k:s}'.format(k=key), file=fp)
    with open(os.path.join(outdir, 'wav.scp'), 'w') as fp:
        print ('{k:s} ffmpeg -loglevel warning -i {audio:s} -f sox - | sox -t sox - -c 1 -b 16 -r 8000 -t wav - remix {channel:d} |'.format(k=key, channel=1, audio=audio), file=fp)

    text = []
    oknoise=re.compile('^\[(LAUGHTER|LAUGHING|INAUDIBLE|ACK)\]$')
    for line in stm:
        for word in line.split(' ')[6:]:
            if word.startswith('[') and not re.match(oknoise, word):
                continue
            word=word.lower()
            if not word in words:
                print(word)
                word='<unk>'
            text.append(word)
    with open(os.path.join(outdir, 'text'), 'w') as fp:            
        print('{k:s}'.format(k=key),' '.join(text), file=fp)


if __name__ == "__main__":
    #
    # execute only if run as a script
    #
    print(sys.argv)
    [script, audiofile, stmfile, wordsfile, outdir]=sys.argv
    with open(stmfile, 'r') as fp:
        stm = [x for x in fp.read().split('\n') if not x.startswith(';')][:-1]
    with open(wordsfile, 'r') as fp:
        words = [x.split(' ')[0] for x in fp.read().split('\n')][:-1]
    try:
        os.makedirs(outdir)
    except:
        pass

    main(audiofile, stm, words, outdir)

# python presidio.py /project/hsr/presidio_10k/DataSet1/131104/131104.mp3 /project/hsr/fmetze/s5-presidio-v5-train_all/stm/131104.stm data/lang_test/words.txt X
