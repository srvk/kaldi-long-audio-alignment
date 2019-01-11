#!/usr/bin/env python

# this script will take an STM file and apply the timings
# from the long audio alignment

# 90200 seems to work

from __future__ import print_function

import sys, re, itertools, pdb


def main(stm, timing, silence):
    startTime = stm[0]['begin']
    endTime   = stm[-1]['end']
    wordX     = 0
    noises    = re.compile('\[(INAUDIBLE|cough|laughter)\]')
    silence   = [abs(x-1) for x in silence]

    ok = 0
    sumsq = 0.0
    for line in stm:
        words = line['words']
        times = []
        for word in words:
            #print(word, wordX, timing[wordX])
            if word.startswith('[') and not re.match(noises, word):
                continue
            if word != timing[wordX]['word']:
                raise ValueError('Word mismatch: '+word+' vs '+timing[wordX]['word']+' idx= '+str(wordX))
            if wordX > 0 and timing[wordX]['begin']==-1:
                timing[wordX]['begin']=timing[wordX-1]['end']
            if wordX < len(timing)-1 and timing[wordX]['end']==-1:
                timing[wordX]['end']=timing[wordX+1]['begin']                
            times.append(timing[wordX])
            wordX+=1

        if len(times)==0:
            # This utterance has no relevant words, it seems
            print(';;', line)
            continue
        if times[0]['begin']=="-1" or times[-1]['end']=="-1":
            # This utterance could not be aligned
            print(';;', line['file'], line['channel'], line['speaker'], line['begin'], line['end'], line['tag'], ' '.join(line['words']))
            continue
        if sum(silence[int(100*float(times[0]['begin'])):int(100*float(times[-1]['end']))]) > 5:
            # If we have more than 5 silence frames, we skip
            print(';;', line['file'], line['channel'], line['speaker'], line['begin'], line['end'], line['tag'], ' '.join(line['words']))
            continue

        # now this is ok
        sumsq+=pow(float(line['begin'])-float(times[0]['begin']),2)+pow(float(line['end'])-float(times[-1]['end']),2)
        d=abs(float(line['begin'])-float(times[0]['begin']))
        if abs(float(line['end'])-float(times[-1]['end'])) > d:
            d=abs(float(line['end'])-float(times[-1]['end']))
        #print(d, line['begin'], line['end'], times[0]['begin'], times[-1]['end'], line['words'])
        print(line['file'], line['channel'], line['speaker'], line['begin'], line['end'], line['tag'], ' '.join(line['words']))
        ok+=1

    print (';; Alignment statistics: len=', len(stm), 'ok=', ok, '%=', 100.0*ok/len(stm), 's=', pow(sumsq,0.5)/ok/2, 'dur=', .01*len(silence))

    #pdb.set_trace()


if __name__ == "__main__":
    #
    # execute only if run as a script
    #
    stm_file     = sys.argv[1]
    timing_file  = sys.argv[2]
    silence_file = sys.argv[3]

    stm = []
    for s in [line.rstrip('\n') for line in open(stm_file, 'r')]:
        if s.startswith(';'):
            print(s)
        else:
            stm.append(dict(zip(['file','channel','speaker','begin','end','tag','words'], [a for a in itertools.chain(s.split(' ')[0:6], [s.split(' ')[6:]])])))
    timing  = [dict(zip(['word','begin','end'], line.rstrip('\n').split(' '))) \
               for line in open(timing_file, 'r')]
    for line in open(silence_file, 'r'):
        silence = map(int, line.split(' ')[3:-1])
    main(stm, timing, silence)
