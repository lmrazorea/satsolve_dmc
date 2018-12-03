#-----------------------------------------------------------------#
# This software implements a diffusion Monte Carlo algorithm for  #
# simulating stoquastic adiabatic dynamics. It was written by     #
# Stephen Jordan in 2015/2016 as part of a collaboration with     #
# Michael Jarret and Brad Lackey.                                 #
#-----------------------------------------------------------------#

CC=gcc
#For normal compilation use:
#CFLAGS=-O2 -Wall
#For competition use:
CFLAGS=-O3 -Wall
#For debugging use:
#CFLAGS=-O2 -g
#For profiling use:
#CFLAGS=-O2 -pg

all: dmcsat sweepsat verify

dmcsat: dmcsat.o bitstrings.o sat.o walk.o
	$(CC) $(CFLAGS) dmcsat.o bitstrings.o sat.o walk.o -o dmcsat -lm

sweepsat: sweepsat.o bitstrings.o sat.o walk.o
	$(CC) $(CFLAGS) sweepsat.o bitstrings.o sat.o walk.o -o sweepsat -lm

verify: verify.c
	$(CC) $(CFLAGS) verify.c -o verify

dmcsat.o: dmcsat.c
	$(CC) $(CFLAGS) -c dmcsat.c

sweepsat.o: sweepsat.c
	$(CC) $(CFLAGS) -c sweepsat.c

bitstrings.o: bitstrings.c
	$(CC) $(CFLAGS) -c bitstrings.c

sat.o: sat.c
	$(CC) $(CFLAGS) -c sat.c

walk.o: walk.c
	$(CC) $(CFLAGS) -c walk.c

clean:
	rm -f *~ dmcsat verify sweepsat *.o

pack: clean
	tar czf algorithm.tar.gz *.c *.h *.sh Makefile
