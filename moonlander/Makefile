# Define variables
CC = cl65
PYTHON = python
PETSII2X = petscii2x.py
TARGET = moonlander.prg
OBJECTFILES = simpleUpdateSpriteAttributes.s
LIB = LAMAlib.lib
CFG = c64-basicfriendly-asm.cfg
LABELS = labels.txt

# List source files
C_SOURCES = $(wildcard *.c)
ASM_SOURCES = $(C_SOURCES:.c=.asm)

# Default target
all: $(TARGET)

# Rule to convert .c to .asm
%.asm: %.c
	$(PYTHON) $(PETSII2X) -n -d -f asm $<

# Rule to build the final program
$(TARGET): game.s $(ASM_SOURCES) $(OBJECTFILES)
	$(CC) -t c64 -g game.s $(OBJECTFILES) -lib $(LIB) -Ln $(LABELS) -C $(CFG) -o $(TARGET)

# Clean build artifacts
clean:
	rm -f *.asm $(TARGET) $(LABELS)
