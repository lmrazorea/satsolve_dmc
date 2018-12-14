/*-----------------------------------------------------------------
  This software solves SAT or MaxSAT using a diffusion Monte Carlo
  algorithm  that mimics stoquastic adiabatic dynamics. It was 
  written by Stephen Jordan in 2016 as part of a collaboration with
  Michael Jarret and Brad Lackey. This version subtracts the 
  minimum potential and is therefore invariant under shifts, just
  as the quantum adiabatic algorithm is. It also uses adaptive
  timesteps, whose size is computed on the fly. The difference
  between sweepsat and threadsat/dmcsat is that it replenishes
  the population by sweeping through for more samples rather
  than by teleportation.
  -----------------------------------------------------------------*/

//On machines with very old versions of glibc (e.g. the Raritan cluster)
//we need to define gnu_source in order to avoid warnings about implicit
//declaration of getline() and round().
//#define _GNU_SOURCE

#include <stdio.h>
#include <malloc.h> //omit on mac
#include <time.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include "bitstrings.h"
#include "sat.h"
#include "walk.h"

double vscale; //the scaling of the potential

//W is the number of walkers, duration is the physical time, and 
//instance a structure containing the SAT instance.
void walk(int W, double duration, instance *sat) {
  walker *walkers1;
  walker *walkers2;
  walker *cur;          //the current locations of walkers
  walker *pro;          //the locations in progress
  walker *tmp;          //temporary holder for pointer swapping
  int w;                //w indexes walker
  double s;             //current value of s
  double phop;          //probability of hopping to a neighboring vertex
  double ptel;          //probability of teleporting to another walker's location
  int action;           //0 = hop, 1 = teleport, 2 = sit
  int umin, umax;       //the min&max number of unsatisfied clauses amongst occupied locations
  int winners;          //number of times a walker hits zero potential
  double dt;            //the adjustable timestep
  double time;          //the total time evolution elapsed
  int dest;             //destination walker
  int coprime;          //for a "poor-man's LCG"
  int stepcount;
  walkers1 = (walker *)malloc(W*sizeof(walker));
  walkers2 = (walker *)malloc(W*sizeof(walker));
  if(walkers1 == NULL || walkers2 == NULL) {
    printf("Unable to allocate memory for walkers.\n");
    return;
  }
  for(w = 0; w < W; w++) {
    init_bits(walkers1[w].bs, sat->B);
    init_bits(walkers2[w].bs, sat->B);
  }
  //initialize the walkers to the uniform distribution
  cur = walkers1;
  pro = walkers2;
  randomize(cur, W, sat);
  //do the time evolution
  winners = 0;
  time = 0;
  stepcount = 0;
  do {
    s = time/duration;
    //calculate the minimum potential amongst currently occupied locations
    umin = cur[0].unsat;
    umax = umin;
    for(w = 0; w < W; w++) {
      if(cur[w].unsat < umin) umin = cur[w].unsat;
      if(cur[w].unsat > umax) umax = cur[w].unsat;
    }
    dt = 0.99/(1.0-s+s*vscale*(double)(umax-umin)); //this ensures we have no negative probabilities
    w = randint(W);
    coprime = 2*randint(64)+1;
    phop = (1.0-s)*dt;
    dest = 0;
    do {
      //subtracting umin yields invariance under uniform potential change
      ptel = dt*s*vscale*(double)(cur[w].unsat-umin); //here we subtract the offset
      action = tern(phop, ptel);
      if(action == 2) { //sit
        sit(&cur[w], &pro[dest], sat->B);
        dest++;
      }
      //if(action == 1) walker dies, do nothing
      if(action == 0) { //hop
        hop(&cur[w], &pro[dest], sat);
        dest++;
      }
      w = (w+coprime)%W;
    }while(dest < W);
    //swap pro with cur
    tmp = pro;
    pro = cur;
    cur = tmp;
    stepcount++;
    for(w = 0; w < W; w++) if(cur[w].unsat == 0) winners++;
    time += dt;
  }while(time < duration && winners == 0);
  if(winners > 0) {
    //if(winners == 1) printf("Found 1 solution:\n");
    //else printf("Found %i solutions:\n", winners);
    printf("Best solutions found have 0 unsatisfied clauses.\n");
    for(w = 0; w < W; w++) if(cur[w].unsat == 0) print_bits(cur[w].bs, sat->B);
  }
  //if no satisfying assignments were found, print the best ones------------------
  else {
    umin = cur[0].unsat;
    umax = umin;
    for(w = 0; w < W; w++) {
      if(cur[w].unsat < umin) umin = cur[w].unsat;
      if(cur[w].unsat > umax) umax = cur[w].unsat;
    }
    printf("Best solutions found have %i unsatisfied clauses.\n", umin);
    for(w = 0; w < W; w++) if(cur[w].unsat == umin) print_bits(cur[w].bs, sat->B);
  }
  //-------------------------------------------------------------------------------
  free(walkers1);
  free(walkers2);
  printf("stepcount: %i\n", stepcount);
}

//load a SAT or MaxSAT instance and try to solve it using our Monte Carlo process
int main(int argc, char *argv[]) {
  int W;             //number of walkers
  unsigned int seed; //seed for rng
  double duration;   //the duration of 
  instance sat;      //the SAT instance
  int success;       //to flag successful loading of the SAT instance from the input
  int trial;         //we run multiple trials since the algorithm is probabilistic
  clock_t beg, end;  //for code timing
  double time_spent; //for code timing
  beg = clock();
  if(argc != 4) {
    fprintf(stderr, "Usage: loadsat filename.cnf duration trial-count\n");
    return 1;
  }
  success = loadsat(argv[1], &sat);
  if(!success) return 0;
  duration = atof(argv[2]);
  int trial_count = atoi(argv[3]);
  //otherwise:
  printf("%i clauses, %i variables\n", sat.numclauses, sat.B);
  seed = time(NULL); //choose rng seed
  //seed = 1;        //for testing
  srand(seed);       //initialize rng
  //The following tuned parameters were obtained by trial and error.
  //They are tuned for random 3SAT at the sat/unsat phase transition.
  //duration = 120.0*exp(0.053*(double)sat.B);
  //the following W and vscale are copied from Brad's code
  W = 128;
  vscale = 1.0;
  //if(sat.B == 150) duration = 10000;
  //vscale = 75.0/(double)sat.B;
  //default from teleportation version
  //if(sat.B == 75) duration = 2000;
  //if(sat.B == 150) duration = 2E5;
  printf("seed = %d\n", seed); //for reproducibility
  printf("bits = %i\n", sat.B);
  printf("walkers = %i\n", W);
  printf("duration = %f\n", duration);
  printf("trial_count = %d\n", trial_count);
  printf("vscale = %e\n", vscale);
  for(trial = 0; trial < trial_count; trial++) {
    printf("trial %i\n", trial);
    walk(W, duration, &sat);
  }
  freesat(&sat);
  end = clock();
  time_spent = (double)(end - beg)/CLOCKS_PER_SEC;

  printf("instance-execution: ");
  for (int i = 0; i < argc; i++) {
    printf("%s ", argv[i]);
  }
  printf("; runtime: %f seconds\n", time_spent);
  return 0;
}

//This is for testing:
/*
int main(int argc, char *argv[]) {
  instance sat;      //the SAT instance
  int success;       //to flag successful loading of the SAT instance from the input
  if(argc != 2) {
    printf("Usage: loadsat filename.cnf\n");
    return 0;
  }
  success = loadsat(argv[1], &sat);
  if(!success) return 0;
  //otherwise:
  printsat(&sat);
  freesat(&sat);
  return 0;
}
*/
