#!/usr/bin/python

import os
import sys
import wave


#dirtodat.py:
#
#Convert the first 15 WAV files in a folder into a .dat
#file compatible with FPDJ. Files must be 16 bit, mono, 44.1 khz.
#
#Calling: dirtodat.py [datfile name] [wav folder path]
#Loading dat onto SD card: sudo dd if=[datfile] of=[sd device]

path = sys.argv[1]

newFile = open(path, 'wb')
writeBytes = bytearray()

fileCount = 0

#iterate through folder
for root, _, files in os.walk(sys.argv[2]):
    for f in files:
        fullpath = os.path.join(root, f)
        
        #only load the first 15
        if (fullpath.lower().endswith(".wav") and fileCount < 15):
        
            #DEADBEEF signifies file start
            writeBytes += bytearray(b"\xDE\xAD\xBE\xEF")
            
            #print filename of file being written to dat
            print f
            
            wavfile = wave.open(fullpath)
            
            #only write audio samples (skip header)
            writeBytes += wavfile.readframes(wavfile.getnframes())
            
            #CAFED00D signifies file end
            writeBytes += bytearray(b"\xCA\xFE\xD0\x0D")
            
            fileCount = fileCount + 1
            
#write FEELDEAD at end of binary blob
writeBytes += bytearray(b"\xFE\xE1\xDE\xAD")
newFile.write(writeBytes)

