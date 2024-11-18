#!/usr/bin/python
# -*- coding: utf-8 -*-
##
## petscii2x is a companion tool for PETSCIIs designed with Marq's PETSCII editor
##
## Code by Wil
##
## petscii2x takes a saved PETSCII (filetype .c) as input and converts it depending on the -f format option:
##
## BASIC          a BASIC program containing PRINT commands (see options for linenumber and increment)
## BASICSLIDES    a BASIC program that waits for a key press after each screen
## DATA           a BASIC program with data lines containing the PETSCII string by string
## LIST           a BASIC program with hidden REM lines that displays the PETSCII when listed 
##                (see option -s for adding a SYS line that jumps right after the REMs)
## ESCAPEDSTRING  PETSCII as a sequence of control commands in ca65 format that can be sent to $FFD2
## SEQ            sequence of control commands to produce the PETSCII in a BBS. 
## ASM            a simple RLE-compressed form of the PETSCII that can be reproduced with the Assembler
##                routine displayPETSCII.s. Decompression is very fast. Compression depends on 
##                the complexity of the image and is 50 to 75%
## BIN            convert each frame to a file with 1000 byte char data and 1000 byte color data
##
## Except for BIN, the program detects and leaves out unnecessary color switches or whitespace trailing a line.
##
## from Version 2.5 on, petscii2x replaces the previously published PETSCII2BASIC tool

from __future__ import print_function
import argparse
import sys
import os
import struct

VERSIONINFO="petscii2x by Wil, Version 2.7 July 2024"

''' 
Changelist:
2.7
added frameblend function
2.611
fixed typo in generated label "numer_of_imgages"
2.61
updated usage message
2.6
-d OPtion now add number of pics in first byte
2.51+2.52
When no outfile is specified, a generic outfile with the proper file extension is used
2.5
integrated ASM and BASIC exports into a single tool
LISTSYS replaed by an option for LIST
fixed coverage bug in LIST with SYS option
2.42
new export SEQ
better handling of empty parts in the pic
2.41
fixed error when writing out unknown filename
added simulation of repetition count slicing
added code to escape characters from marker block
2.4
added version and "newer" option, removed basic option
2.3
option to add a directory with pointers at the start of the file
2.2
reduce maximum repetition to 15
add rep,00 as endcode
2.1
added support for reduced pic height (-y option)
2.11 
new export types ESCAPEDSTRING, PRG
improvement considering the already set color from previous row
2.0
LISTART support
1.0 first release as PETSCII2BASIC tool
'''

basic_prg = []
codelines = []
basic_start = 0x801
lastptr = -1

CHR_QUOTE = 0x22
CHR_UP = 0x91
CHR_DOWN = 0x11
CHR_LEFT = 0x9d
CHR_RIGHT = 0x1d
CHR_DELETE = 0x14
CHR_RETURN = 0x0d
CHR_LOWERCASE = 0x0e
CHR_SHIFTRETURN = 0x8d
CHR_COMMA = 0x2c
CHR_SPACE = 0x20
CHR_COLORCODES = [
    0x90, #BLK
    0x05, #WHT
    0x1c, #RED
    0x9f, #CYN
    0x9c, #PUR
    0x1e, #GRN
    0x1f, #BLU
    0x9e, #YEL
    0x81, #ORANGE
    0x95, #BROWN
    0x96, #LRED
    0x97, #DGRAY
    0x98, #MGRAY
    0x99, #LGRN
    0x9a, #LBLU
    0x9b, #LGRAY
    ]
CHR_RVSON = 0x12
CHR_RVSOFF = 0x92
CHR_CLRSCR = 147

TOKEN_PRINT = 0x99
TOKEN_POKE = 0x97
TOKEN_CHR = 0xc7
TOKEN_DATA = 0x83
TOKEN_PLUS = 0xAA
TOKEN_EQ = 0xB2
TOKEN_AND = 0xAF
TOKEN_OR = 0xB0
TOKEN_GET = 0xA1
TOKEN_IF = 0x8B
TOKEN_THEN = 0xA7
TOKEN_SYS = 0x9e
TOKEN_REM = 0x8f

ASM_INDENT = '        '

QUOTESTR = [TOKEN_CHR, ord('('), ord('3'), ord('4'), ord(')'), TOKEN_PLUS, TOKEN_CHR, ord('('), ord('2'), ord('0'), ord(')'), TOKEN_PLUS,
            TOKEN_CHR, ord('('), ord('3'), ord('4'), ord(')')]

SPACES = [chr(32),chr(96)]

QUOTELST = [CHR_QUOTE,CHR_QUOTE,CHR_DELETE]

def load_petscii_c(filename):
    frames = []
    with open(filename) as fp:
        while True:
            tmp = fp.readline()
            if tmp[:7] == '// META':
                break

            # parse border and background color

            (bordercol, bgcol) = [int(x) for x in
                                  fp.readline().strip().rstrip(','
                                  ).split(',')]

            # parse character values

            tmp = ''
            for x in range(25):
                tmp = tmp + fp.readline().strip()
            chars = [int(x) for x in tmp.rstrip(',').split(',')]

            # parse color values

            tmp = ''
            for x in range(25):
                tmp = tmp + fp.readline().strip()
            cols = [int(x) for x in tmp.rstrip(',').split(',')]
            tmp = fp.readline()
            petscii = [bordercol, bgcol, chars, cols]
            frames.append(petscii)
    return frames


def savePrg(filename):
    outfile = open(filename, 'wb')

    # write startaddress
    outfile.write(struct.pack('<H', 0x801))
    for b in basic_prg:
        outfile.write(struct.pack('B', b))
        
def saveBin(filename):
    outfile = open(filename, 'wb')
    # bin has no startaddress
    for b in basic_prg:
        outfile.write(struct.pack('B', b))        


def closeLine():
    global lastptr, basic_prg
    if lastptr >= 0:
        addr = len(basic_prg) + 0x801 + 1
        basic_prg[lastptr] = addr & 0xFF
        basic_prg[lastptr + 1] = addr >> 8
        lastptr = -1
        basic_prg += [0]


def closePrg():
    global basic_prg
    closeLine()
    basic_prg += [0, 0]


def addLine():
    global linenr, basic_prg, lastptr
    closeLine()
    lastptr = len(basic_prg)
    basic_prg += [0, 0]
    basic_prg += [linenr & 0xFF]
    basic_prg += [linenr >> 8]
    oldlinenr = linenr
    linenr += lineInc
    return oldlinenr


def addDATA():
    global basic_prg
    basic_prg += [TOKEN_DATA]

def addREM():
    global basic_prg
    basic_prg += [TOKEN_REM]

def addHackedREM():
    global basic_prg
    addREM()
    basic_prg += [CHR_QUOTE,CHR_SHIFTRETURN,CHR_UP]

def addPRINT():
    global basic_prg
    basic_prg += [TOKEN_PRINT]


def addPOKE(a, b):
    global basic_prg
    basic_prg += [TOKEN_POKE]
    addNumber(a)
    addChars(',')
    addNumber(b)

def addSYS(a):
    global basic_prg
    basic_prg += [TOKEN_SYS]
    addNumber(a)

def addNumber(n):
    addChars(str(n))


def addQuotedString(str):
    global basic_prg
    basic_prg += [CHR_QUOTE]
    basic_prg += str
    basic_prg += [CHR_QUOTE]


def addString(str):
    global basic_prg
    basic_prg += str


def addChars(s):
    global basic_prg
    for ch in s:
        basic_prg += [ord(ch)]


def addByte(b):
    global basic_prg
    basic_prg += [b]


def dollarHex(n):
    return '$' + hex(n)[2:]


def removeByte():
    global basic_prg
    last_byte = basic_prg[-1]
    del basic_prg[-1]
    return last_byte


def decodeLine(f, y):
    global lowercase,current_color
    lastlinehack = False
    if y < 0:
        y = -y
        lastlinehack = True
        firstlinepart = []
    rev = False
    full = True
    if lowercase:
        c = [CHR_LOWERCASE]
        lowercase=False
    else:
        c = []
    empty = True
    for x in range(40):
        char = f[2][x + y * 40]
        col = f[3][x + y * 40]
        if rev or (char not in [32,96]):
            empty = False
            if col != current_color:
                if lastlinehack and x == 39:
                    ext1 += [CHR_COLORCODES[col]]
                else:
                    c += [CHR_COLORCODES[col]]
                current_color = col
        v = char > 0x7F
        c2 = char
        char = char & 0x7F
        char = char - 32 + (char & 96) + (char < 32) * 96
        if rev - v:
            if lastlinehack and x == 39:
                if v:
                    ext1 += [CHR_RVSON]
                else:
                    ext1 += [CHR_RVSOFF]
            else:
                if v:
                    c += [CHR_RVSON]
                else:
                    c += [CHR_RVSOFF]
            rev = v
        if char == 0x22:
            if targetformat == 'data':
                c += [39]  # in data lines we need to replace double quotes with single quotes, sorry
            else:
                c += [0x22, ord('Q'), ord('$'), 0x22]
        else:
            c += [char]
        if lastlinehack:
            if x == 37:
                firstlinepart = c
                c = []
            if x == 38:
                ext1 = c
                c = []
    if rev:
        c += [CHR_RVSOFF]
    elif not lastlinehack:
        while len(c) > 0 and (c[-1] in [32,96,160,224]):
            del c[-1]
            #print(c)
            full = False
    if lastlinehack:
        return (firstlinepart, ext1, c)
    if empty:
        return ([], False)
    else:
        return (c, full)

def getLastLineNotEmpty(f):
    global current_color
    current_color = -1      
    for lastline in range(24,-1,-1):
        (c, full) = decodeLine(f, lastline)
        if not c == []:
            current_color = -1
            return lastline
        #if not all(c in SPACES for c in enteredpass1):
        #    return lastline
    current_color = -1          
    return -1

def convertPETSCII2DATA(frames):
    global linenr, lineInc,current_color
    for f in frames:
        current_color = -1
        for y in range(25):
            (c, full) = decodeLine(f, y)
            addLine()
            addDATA()
            addQuotedString(c)
            closeLine()
    closePrg()

def convertPETSCII2LIST(frames,sysflag):
    global linenr, lineInc, basic_prg,current_color
    if sysflag:
        toadd = [chr(TOKEN_SYS),'1','2','3','4',':']
    else:
        toadd= []
    prevlineno=linenr    
    for f in frames:
        current_color = -1        
        lastline = getLastLineNotEmpty(f)
        if lastline == -1:
            continue
        
        for y in range(lastline+1):
            (c, full) = decodeLine(f, y)
            addLine()
            addChars(toadd)
            addHackedREM()
            toCover=4+len(str(linenr))
            if toadd!=[]:
                toCover+=10
            toadd=[]
            addString(c)
            if (len(c)<toCover):
                addString([CHR_SPACE]*(toCover-len(c)))
            if y==lastline:
                addByte(CHR_COLORCODES[14])
            closeLine()
    closePrg()
    if sysflag:
      basic_prg[5:9]=[ord(x) for x in str(0x801+len(basic_prg))]

def petscii_to_char(c):
    if c>=65 and c<91:
        c=c+32
    elif c>=97 and c<123:
        c=c-32
    if c>=32 and c<127:
        return chr(c)
    return "%"+hex(256+c)[3:]

def convertPETSCII2ESCAPEDSTRING(frames):
    global linenr, lineInc, basic_prg, current_color
    toadd= []
    prevlineno=linenr    
    for f in frames:        
        lastline = getLastLineNotEmpty(f)      
        if lastline == -1:
            continue
        for y in range(lastline+1):
            (c, full) = decodeLine(f, y)
            #print()
            #print(y,full)
            for ch in c:
                #print("("+str(ch)+")",end="")
                print(petscii_to_char(ch),end="")
            if y<lastline and full==False:
                print(petscii_to_char(10),end="")
            closeLine()
    closePrg()
    
def convertPETSCII2SEQ(frames, filename):
    global linenr, lineInc, basic_prg, current_color
    toadd = []
    prevlineno = linenr

    with open(filename, 'wb') as output_file:
        output_file.write(bytes([142])) #uppercase/gfx mode
        for f in frames:
            lastline = getLastLineNotEmpty(f)
            if lastline == -1:
                continue
            for y in range(lastline + 1):
                (c, full) = decodeLine(f, y)
                for ch in c:
                    if 96 <= ch <= 127:
                        ch += 96
                    elif 160 <= ch <= 190:
                        ch += 64                    
                    output_file.write(bytes([ch]))
                if y < lastline and not full:
                    output_file.write(bytes([13]))
                closeLine()
    closePrg()
    
def convertPETSCII2BIN(frames):
    for f in frames: 
        for y in range(25):
            for x in range(40):
                char = f[2][x + y * 40]
                addByte(char)
        for y in range(25):
            for x in range(40):
                col = f[3][x + y * 40]
                addByte(col)

def convertPETSCII2PRINT(frames, slidemode):
    global linenr, lineInc, current_color
    bordercol = -1
    bgcol = -1
    prevlineno=linenr
    for f in frames:
        current_color = -1
        currentlineno=linenr
        if f[0] != bordercol or f[1] != bgcol or slidemode:
            bordercol = f[0]
            bgcol = f[1]
            addLine()
            addPOKE(53280, bordercol)
            addChars(':')
            addPOKE(53281, bgcol)
            if 0x22 in f[2] or 128 + 0x22 in f[2]:
                addChars(':Q$')
                addString([TOKEN_EQ])
                addString(QUOTESTR)
            closeLine()
        toadd = [CHR_CLRSCR]
        lastlinehack = False
        for y in range(25):
            (c, full) = decodeLine(f, y)
            if c == []:
                toadd += [0x11]  # crsr down
                continue
            addLine()
            addPRINT()
            if slidemode and y == 24 and full:
                # we need to introduce a hack to avoid screen scrolling
                # flip last two characters and colors
                (f[2][38 + y * 40], f[2][39 + y * 40]) = (f[2][39 + y
                        * 40], f[2][38 + y * 40])
                (f[3][38 + y * 40], f[3][39 + y * 40]) = (f[3][39 + y
                        * 40], f[3][38 + y * 40])
                (c, ext1, ext2) = decodeLine(f, -y)
                lastlinehack = True
            addQuotedString(toadd + c)
            toadd = []
            if lastlinehack:
                addChars(';')
                closeLine()
                addLine()
                addPRINT()
                addQuotedString(toadd + ext1 + [CHR_LEFT])
                addByte(TOKEN_CHR)
                addChars('(148)')
                addQuotedString(ext2)
                addChars(';')
            elif full or y == 24:
                addChars(';')
            closeLine()
        if slidemode:
            currentline = addLine()
            addByte(TOKEN_GET)
            addChars('A$:')
            addByte(TOKEN_IF)
            addChars('A$')
            addByte(TOKEN_EQ)
            addChars('""')
            addByte(TOKEN_THEN)
            addChars(str(currentline))
            closeLine()
            if len(frames)>1:
                #add code for flipping back
                addLine()
                addByte(TOKEN_IF)
                addChars('A$')
                addByte(TOKEN_EQ)
                addQuotedString([CHR_LEFT])
                addByte(TOKEN_OR)
                addChars('A$')
                addByte(TOKEN_EQ)
                addQuotedString([CHR_UP])
                addByte(TOKEN_THEN)
                if prevlineno<currentlineno:
                    addChars(str(prevlineno))
                else:
                    addChars(str(currentline))                
                closeLine()            
        prevlineno=currentlineno
    closePrg()

def convertPETSCII2ASM(frames):
   global codelines,pic_height,add_dir
   
   if add_dir:
      codelines.append("number_of_images: .byte "+str(len(frames)))               
      imgno=0
      petscii_dir="        .word "
      sep=""
      for f in frames:
         petscii_dir += sep + "petsciiimg"+str(imgno)
         sep=","
         imgno+=1   
      codelines.append("petscii_dir:   ;list of pointers to compressed PETSCII images")         
      codelines.append(petscii_dir) 
      codelines.append("")
   
   imgno=0
   for f in frames:
      codelines.append("petsciiimg"+str(imgno)+":")
      imgno+=1
      

      #find out which 32 byte block is the least used
      ttblocks=[0]*8
      lastch=-1
      lastcol=-1
      count=0
      for i in range(pic_height*40):
          if f[2][i]==lastch and f[3][i]==lastcol:
              count+=1
              continue
          #simulate write out of sequence
          while(count>1):
              n=min(count,15)
              count-=n              
          if count==1:
              ttblocks[int(lastch/32)]+=1
          lastch=f[2][i]
          lastcol=f[3][i]
          count=1
      #select the least used block as marker
      marker=ttblocks.index(min(ttblocks))
      lastch=-1
      lastcol=-1
      count=0
      databytes=[]
      for i in range(pic_height*40):
          if f[2][i]==lastch and f[3][i]==lastcol:
              count+=1
              continue
          #write out last char or char sequence
          while(count>1):
              n=min(count,15)
              databytes.append(dollarHex(marker*32+n))
              databytes.append(dollarHex(lastch))
              count-=n
          if count==1:
              if int(lastch/32)==marker:
                #escape character from marker block
                databytes.append(dollarHex(marker*32+1))
                databytes.append(dollarHex(lastch))                
              else:
                #write out databyte normally
                databytes.append(dollarHex(lastch))
          #if color changed, write out new color
          if f[3][i]!=lastcol: 
              databytes.append(dollarHex(marker*32+16+f[3][i]))
          lastch=f[2][i]
          lastcol=f[3][i]
          count=1
      #write out last char or char sequence
      while(count>1):
          n=min(count,15)
          databytes.append(dollarHex(marker*32+n))
          databytes.append(dollarHex(lastch))
          count-=n
      if count==1:
          databytes.append(dollarHex(lastch))
          
      #add end code
      databytes.append(dollarHex(marker*32))
      
      #assembler databytes into lines
      imagesize=2+len(databytes)
      compressionrate=int(100*(2+len(databytes)) / (2+2*pic_height*40))
      codelines[-1]+="         ;compressed image size "+str(imagesize)+" bytes, compressed to "+str(compressionrate)+"%"
      currentline=ASM_INDENT+".byte "+dollarHex(f[0])+","+dollarHex(marker*32+f[1])+" ;border and bg color"
      for i in range(len(databytes)):
          if i % 32==0:
              codelines.append(currentline)
              currentline=ASM_INDENT+".byte "
              sep=""
          currentline+=sep+databytes[i]
          sep=","
      codelines.append(currentline)
      codelines.append("")

def frameblend(frames, f1_idx, f2_idx):
    global codelines      
    char_change_values = []
    col_change_values = []    
    col_change_mapped_values = []
    f1 = frames[f1_idx]
    f2 = frames[f2_idx]    
    
    codelines.append("; Code to blend from frame " + str(f1_idx) + " to frame " + str(f2_idx))  
    codelines.append(".ifndef SCREEN_BASE")
    codelines.append("  SCREEN_BASE=$400")
    codelines.append(".endif")
    codelines.append(".ifndef COLRAM_BASE")
    codelines.append("  COLRAM_BASE=$d800")
    codelines.append(".endif")    
    codelines.append("")
    codelines.append("blend_" + str(f1_idx) + "to" + str(f2_idx) + ":")      
    
    for i in range(25 * 40):
        if f1[2][i] != f2[2][i]:
            char_change_values.append((f2[2][i], i))
        if f2[2][i]!=32 and f2[2][i]!=96:
            if (f1[3][i] != f2[3][i]) or (f1[2][i]==32 or f1[2][i]==96):
                col_change_values.append((f2[3][i], i))    
                
    # Sort by the value (first element of the tuple)
    char_change_values.sort(key=lambda x: x[0])
    col_change_values.sort(key=lambda x: x[0])

    # map colors to char values whenever possible
    for col_val, col_index in col_change_values[:]:
        for char_val, char_index in char_change_values:
            if col_val == (char_val & 0x0F):
                col_change_mapped_values.append((char_val, col_index))
                col_change_values.remove((col_val, col_index))
                break

    col_change_mapped_values.sort(key=lambda x: x[0])    
    print (col_change_values)
    print (col_change_mapped_values)
        
    # Traverse through char_change_values from low to high
    current_x = -999
    for x_val in range(256):                   
        for char_val, index in char_change_values:
            if x_val==char_val:
                if x_val!=current_x:
                    if x_val==current_x+1:
                        codelines.append("        inx")
                    else:
                        codelines.append("        ldx #"+str(x_val))
                    current_x=x_val              
                codelines.append("        stx SCREEN_BASE+"+str(index))
        #check for mapped color values
        for col_val, col_index in col_change_mapped_values: 
            if x_val == col_val:
                codelines.append("        stx COLRAM_BASE+" + str(col_index))
        
        # Check if (current_x & 0x0F) is in col_change_values
        for col_val, col_index in col_change_values:  # Iterate over a copy of the list
            if x_val == col_val: 
                if x_val!=current_x:             
                    if x_val == current_x + 1:
                        codelines.append("        inx")
                    else:
                        codelines.append("        ldx #" + str(x_val))
                    current_x = x_val              
                codelines.append("        stx COLRAM_BASE+" + str(col_index))
                # Remove the entry from col_change_values
                #col_change_values.remove((col_val, col_index))         
    codelines.append("        rts")
          
def saveAsmPrg(filename):
    outfile = open(filename,"w") 
    for l in codelines:
        outfile.write(l+"\n")
    outfile.close()    
    
def saveAsmPrg(filename):
    outfile = open(filename, 'w')
    for l in codelines:
        outfile.write(l + '\n')
    outfile.close()


def loadPETSCII(filename):
    frames = load_petscii_c(filename)
    if args.page and args.page > 0:
        return [frames[args.page - 1]]
    else:
        return frames

class ShowVersionInfo(argparse.Action):
    def __call__(self, parser, namespace, values, option_string):
        print(VERSIONINFO)
        parser.exit() # exits the program with no more arg parsing and checkin


formats_str="BASIC, BASICSLIDES, DATA, LIST, ESCAPEDSTRING, SEQ, ASM, BIN"
formats = [format.strip().lower() for format in formats_str.split(',')]
        
# Parse command-line arguments
parser = \
    argparse.ArgumentParser(description="Convert PETSCII images from Marq's PETSCII Editor to various C64 formats")
parser.add_argument('filename', help='File to be converted.',
                    default='clocktower50.c')
parser.add_argument('-o', '--outfile', help='save converted image' )
parser.add_argument("-n", "--newer", action="store_true", default=False, help="do not convert if a target newer than the source file exists")
parser.add_argument("-d", "--dir", action='store_true', help="for ASM output; add a directory of pointers at the start of the file")
parser.add_argument('-p', '--page', nargs='?', type=int, const=0,
                    help='select a specific page from the PETSCII source, otherwise all pages are converted. Page numbers start at 1')
parser.add_argument("-y", "--yheight", help="image height in lines, default=25", default=25)                    
parser.add_argument('-l', '--linenumber',
                    help='set starting linenumber for BASIC program, default=100',
                    default=100)
parser.add_argument('-i', '--increment',
                    help='set linenumber increment, default=5',
                    default=5)          
parser.add_argument('-s', '--sys', action='store_true', help='Only works with -f LIST. Adds a SYS line to the beginning of the program that jumps after the generated code.')                              
parser.add_argument('-f', '--format',
                    help='set output format:'+formats_str,
                    default='basicslides')
parser.add_argument('--lowercase', action="store_true",
                    help='Enable upper/lowercase charset')
parser.add_argument('--frameblend', nargs=2, metavar=('from_frame', 'to_frame'), type=int,
                    help='Generate code for fast transition between two frames, specifying from_frame and to_frame')

parser.add_argument('-v', '--version', nargs=0, action=ShowVersionInfo,
                    help='display version info')

args = parser.parse_args()

sysflag = False
targetformat=args.format.lower()

if not args.format:
    sys.stderr.write('Please specify the output format.\n')
    sys.exit(1)
if not targetformat in formats:
    sys.stderr.write('Unknown or unsupported format, please specify any of '+formats_str+'.\n')
    sys.exit(1)

lowercase=False
if args.lowercase:
    lowercase=True
if args.outfile:
    outfile = args.outfile
else:
    if args.frameblend:
        outfile = '.'.join(args.filename.split('.')[:-1]) + '_' + str(args.frameblend[0]) + 'to'+ str(args.frameblend[1]) +'.asm'
    else:
        if targetformat == 'seq':
            outfile = 'screen.seq'
        elif targetformat=='asm':
            outfile = '.'.join(args.filename.split('.')[:-1]) + '.asm'
        elif targetformat == 'escapedstring':
            outfile = '.'.join(args.filename.split('.')[:-1]) + '.txt'      
        else:
            outfile = '.'.join(args.filename.split('.')[:-1]) + '.prg'

linenr = int(args.linenumber)
lineInc = int(args.increment)

if not os.path.isfile(args.filename):
    sys.stderr.write("Source file "+args.filename+" not found!\n")
    sys.exit(1)      

pic_height=int(args.yheight)

add_dir=args.dir
    
if args.newer:
    if os.path.isfile(outfile):
        src_time=os.path.getmtime(args.filename)
        trg_time=os.path.getmtime(outfile)
        if trg_time>=src_time:
            sys.exit(0)

if args.sys:
    if targetformat != 'list':
        sys.stderr.write("SYS option can only be used with format LIST!\n")
        sys.exit(1)
      
frames = loadPETSCII(args.filename)


if args.frameblend:
    frameblend(frames,args.frameblend[0],args.frameblend[1])
    saveAsmPrg(outfile)    
    print("File saved as "+outfile)    
elif targetformat == 'basic':
    convertPETSCII2PRINT(frames, slidemode=False)
    savePrg(outfile)    
    print("File saved as "+outfile)    
elif targetformat == 'basicslides':
    convertPETSCII2PRINT(frames, slidemode=True)
    savePrg(outfile)    
    print("File saved as "+outfile)    
elif targetformat == 'bin':
    convertPETSCII2BIN(frames)
    saveBin(outfile)   
    print("File saved as "+outfile)            
elif targetformat == 'data':
    convertPETSCII2DATA(frames)
    savePrg(outfile)
    print("File saved as "+outfile)
elif targetformat == 'list':
    convertPETSCII2LIST(frames,args.sys)
    savePrg(outfile) 
    print("File saved as "+outfile)            
elif targetformat == 'escapedstring':
    if args.outfile:
        with open(outfile, 'w') as file:
            sys.stdout=file
            convertPETSCII2ESCAPEDSTRING(frames)
            # Restore the original stdout after writing to the file
            sys.stdout = sys.__stdout__
            print("File saved as "+outfile)                    
    else:
        convertPETSCII2ESCAPEDSTRING(frames)
elif targetformat == 'seq':
    convertPETSCII2SEQ(frames, outfile)
    print("File saved as "+outfile)        
elif targetformat=='asm':
    convertPETSCII2ASM(frames)
    saveAsmPrg(outfile)    
    print("File saved as "+outfile)