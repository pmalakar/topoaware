/* -*- c++ -*- -------------------------------------------------------------
   LAMMPS - Large-scale Atomic/Molecular Massively Parallel Simulator
   http://lammps.sandia.gov, Sandia National Laboratories
   Steve Plimpton, sjplimp@sandia.gov

   Copyright (2003) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under
   the GNU General Public License.

   See the README file in the top-level LAMMPS directory.
------------------------------------------------------------------------- */

#ifdef INTEGRATE_CLASS

IntegrateStyle(verlet/splitanalysis,VerletSplitAnalysis)

#else

#ifndef LMP_VERLET_SPLITANALYSIS_H
#define LMP_VERLET_SPLITANALYSIS_H

#include "verlet.h"

namespace LAMMPS_NS {

class VerletSplitAnalysis : public Verlet {
 public:
  VerletSplitAnalysis(class LAMMPS *, int, char **);
  ~VerletSplitAnalysis();
  void init();
  void setup();
  void setup_minimal(int);
  void run(int);
  bigint memory_usage();

 private:
  int master;                        // 1 if an Sim proc, 0 if Analysis
  int me_block;                      // proc ID within Sim/Analysis block
  int ratio;                         // ratio of Sim procs to Analysis procs
  int *qsize,*qdisp,*xsize,*xdisp;   // MPI gather/scatter params for block comm
  MPI_Comm block;                    // communicator within one block
  int tip4p_flag;                    // 1 if PPPM/tip4p so do extra comm

  int maxatom;

  void sa_setup();
  void s2a_comm(bigint);

  int tmp_size;
  double * xtmp;
  double * vtmp;
  tagint * tagtmp;

  int neigh_sync_freq;
};

}

#endif
#endif

/* ERROR/WARNING messages:

E: Verlet/splitanalysis requires 2 partitions

See the -partition command-line switch.

E: Verlet/splitanalysis requires Sim partition size be multiple of 
Analysis partition size

This is so there is an equal number of Sim processors for every
Analysis processor.

E: Verlet/split can only currently be used with comm_style brick

This is a current restriction in LAMMPS.

E: Verlet/split requires Sim partition layout be multiple of 
Analysis partition layout in each dim

This is controlled by the processors command.

E: Verlet/splitanalysis does not yet support TIP4P

This is a current limitation.

*/
