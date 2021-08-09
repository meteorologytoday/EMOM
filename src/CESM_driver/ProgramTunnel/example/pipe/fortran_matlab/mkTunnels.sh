#!/bin/bash

for direct in X2Y Y2X
do
    for dattype in bin txt
    do
        for i in 1 2
        do
            mkfifo _${direct}_${dattype}_${i}.fifo
        done
    done
done
