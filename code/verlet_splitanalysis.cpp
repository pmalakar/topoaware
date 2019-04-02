/* ----------------------------------------------------------------------
   LAMMPS - Large-scale Atomic/Molecular Massively Parallel Simulator
   http://lammps.sandia.gov, Sandia National Laboratories
   Steve Plimpton, sjplimp@sandia.gov

   Copyright (2003) Sandia Corporation.  Under the terms of Contract
   DE-AC04-94AL85000 with Sandia Corporation, the U.S. Government retains
   certain rights in this software.  This software is distributed under
   the GNU General Public License.

   See the README file in the top-level LAMMPS directory.
------------------------------------------------------------------------- */

/* ----------------------------------------------------------------------
   Contributing authors: Chris Knight and Preeti Malakar (Argonne National Laboratory) 
------------------------------------------------------------------------- */

#include <string.h>
#include "verlet_splitanalysis.h"
#include "universe.h"
#include "neighbor.h"
#include "domain.h"
#include "comm.h"
#include "atom.h"
#include "atom_vec.h"
#include "force.h"
#include "pair.h"
#include "bond.h"
#include "angle.h"
#include "dihedral.h"
#include "improper.h"
#include "kspace.h"
#include "output.h"
#include "update.h"
#include "fix.h"
#include "modify.h"
#include "timer.h"
#include "memory.h"
#include "error.h"
#include "stdlib.h"

#define _BUFFER_PAD 100
#define _DEBUG 0

using namespace LAMMPS_NS;

MPI_Request request_x, request_v, request_tag;
MPI_Status status_x, status_v, status_tag;

/* ---------------------------------------------------------------------- */

VerletSplitAnalysis::VerletSplitAnalysis(LAMMPS *lmp, int narg, char **arg) :
  Verlet(lmp, narg, arg)
{
  neigh_sync_freq = -1;
  if(narg == 1) neigh_sync_freq = atoi(arg[0]);

  // error checks on partitions

  if (universe->nworlds != 2)
    error->universe_all(FLERR,"Verlet/splitanalysis requires 2 partitions");
  if (universe->procs_per_world[0] % universe->procs_per_world[1])
    error->universe_all(FLERR,"Verlet/splitanalysis requires Sim partition "
                        "size be multiple of Analysis partition size");
  if (comm->style != 0)
    error->universe_all(FLERR,"Verlet/splitanalysis can only currently be used with "
                        "comm_style brick");

  // master = 1 for Sim processes, 0 for Analysis processes

  if (universe->iworld == 0) master = 1;
  else master = 0;

  // ratio of Sim to Analysis processes
  
  ratio = universe->procs_per_world[0] / universe->procs_per_world[1];

  // Analysis root proc broadcasts info about Analysis proc layout to Sim procs

  int analysis_procgrid[3];

  if (universe->me == universe->root_proc[1]) {
    analysis_procgrid[0] = comm->procgrid[0];
    analysis_procgrid[1] = comm->procgrid[1];
    analysis_procgrid[2] = comm->procgrid[2];
  }
  MPI_Bcast(analysis_procgrid,3,MPI_INT,universe->root_proc[1],universe->uworld);

  int ***analysis_grid2proc;
  memory->create(analysis_grid2proc,analysis_procgrid[0],
                 analysis_procgrid[1],analysis_procgrid[2],
                 "verlet/splitanalysis:analysis_grid2proc");

  if (universe->me == universe->root_proc[1]) {
    for (int i = 0; i < comm->procgrid[0]; i++)
      for (int j = 0; j < comm->procgrid[1]; j++)
        for (int k = 0; k < comm->procgrid[2]; k++)
          analysis_grid2proc[i][j][k] = comm->grid2proc[i][j][k];
  }
  MPI_Bcast(&analysis_grid2proc[0][0][0],
            analysis_procgrid[0]*analysis_procgrid[1]*analysis_procgrid[2],MPI_INT,
            universe->root_proc[1],universe->uworld);

  // Sim partition must be multiple of Analysis partition in each dim
  // so atoms of one Analysis proc coincide with atoms of several Sim procs

  if (master) {
    int flag = 0;
    if (comm->procgrid[0] % analysis_procgrid[0]) flag = 1;
    if (comm->procgrid[1] % analysis_procgrid[1]) flag = 1;
    if (comm->procgrid[2] % analysis_procgrid[2]) flag = 1;

    if (flag)
      error->one(FLERR,
                 "Verlet/splitanalysis requires Sim partition layout be "
                 "multiple of Analysis partition layout in each dim");

  }

  // block = 1 Analysis proc with set of Sim procs it overlays
  // me_block = 0 for Analysis proc
  // me_block = 1 to ratio for Sim procs
  // block = MPI communicator for that set of procs

  int iblock,key;

  if (!master) {
    iblock = comm->me;
    key = 0;
  } else {
    int kpx = comm->myloc[0] / (comm->procgrid[0]/analysis_procgrid[0]);
    int kpy = comm->myloc[1] / (comm->procgrid[1]/analysis_procgrid[1]);
    int kpz = comm->myloc[2] / (comm->procgrid[2]/analysis_procgrid[2]);
    iblock = analysis_grid2proc[kpx][kpy][kpz];
    key = 1;
  }

  MPI_Comm_split(universe->uworld,iblock,key,&block);
  MPI_Comm_rank(block,&me_block);

  // output block groupings to universe screen/logfile
  // bmap is ordered by block and then by proc within block

  int *bmap = new int[universe->nprocs];
  for (int i = 0; i < universe->nprocs; i++) bmap[i] = -1;
  bmap[iblock*(ratio+1)+me_block] = universe->me;

  int *bmapall = new int[universe->nprocs];
  MPI_Allreduce(bmap,bmapall,universe->nprocs,MPI_INT,MPI_MAX,universe->uworld);

  if (universe->me == 0) {
    if (universe->uscreen) { 
      fprintf(universe->uscreen,"neigh_sync_freq= %i\n",neigh_sync_freq);
      fprintf(universe->uscreen,
              "Per-block Sim/Analysis proc IDs (original proc IDs):\n");
      int m = 0;
      for (int i = 0; i < universe->nprocs/(ratio+1); i++) {
        fprintf(universe->uscreen,"  block %d:",i);
        int analysis_proc = bmapall[m];
        for (int j = 1; j <= ratio; j++)
          fprintf(universe->uscreen," %d",bmapall[m+j]);
        fprintf(universe->uscreen," %d",analysis_proc);
        analysis_proc = bmapall[m];
        for (int j = 1; j <= ratio; j++) {
          if (j == 1) fprintf(universe->uscreen," (");
          else fprintf(universe->uscreen," ");
          fprintf(universe->uscreen,"%d",
                  universe->uni2orig[bmapall[m+j]]);
        }
        fprintf(universe->uscreen," %d)\n",universe->uni2orig[analysis_proc]);
        m += ratio + 1;
      }
    }
    if (universe->ulogfile) {
      fprintf(universe->ulogfile,"neigh_sync_freq= %i\n",neigh_sync_freq);
      fprintf(universe->ulogfile,
              "Per-block Sim/Aspace proc IDs (original proc IDs):\n");
      int m = 0;
      for (int i = 0; i < universe->nprocs/(ratio+1); i++) {
        fprintf(universe->ulogfile,"  block %d:",i);
        int analysis_proc = bmapall[m];
        for (int j = 1; j <= ratio; j++)
          fprintf(universe->ulogfile," %d",bmapall[m+j]);

        fprintf(universe->ulogfile," %d",analysis_proc);
        analysis_proc = bmapall[m];
        for (int j = 1; j <= ratio; j++) {
          if (j == 1) fprintf(universe->ulogfile," (");
          else fprintf(universe->ulogfile," ");
          fprintf(universe->ulogfile,"%d",
                  universe->uni2orig[bmapall[m+j]]);
        }
        fprintf(universe->ulogfile," %d)\n",universe->uni2orig[analysis_proc]);
        m += ratio + 1;
      }
    }
  }

  memory->destroy(analysis_grid2proc);
  delete [] bmap;
  delete [] bmapall;

  // size/disp = vectors for MPI gather/scatter within block

  qsize = new int[ratio+1];
  qdisp = new int[ratio+1];
  xsize = new int[ratio+1];
  xdisp = new int[ratio+1];

  maxatom = 0;

  tmp_size = 0;
  xtmp = NULL;
  vtmp = NULL;
  tagtmp = NULL;
}

/* ---------------------------------------------------------------------- */

VerletSplitAnalysis::~VerletSplitAnalysis()
{
  delete [] qsize;
  delete [] qdisp;
  delete [] xsize;
  delete [] xdisp;
  MPI_Comm_free(&block);

  memory->destroy(xtmp);
  memory->destroy(vtmp);
  memory->destroy(tagtmp);
}

/* ----------------------------------------------------------------------
   initialization before run
------------------------------------------------------------------------- */

void VerletSplitAnalysis::init()
{
  // This comm restriction might not be necessary
  if (comm->style != 0)
    error->universe_all(FLERR,"Verlet/splitanalysis can only currently be used with "
                        "comm_style brick");
// Analysis partition shouldn't be affected by tip4p model, but leave commented until tested
//  if (force->kspace_match("tip4p",0)) tip4p_flag = 1;
//  else tip4p_flag = 0;

  // currently TIP4P does not work with verlet/splitanalysis, so generate error
  // see Axel email on this, also other TIP4P notes below

  // if (tip4p_flag) error->all(FLERR,"Verlet/splitanalysis does not yet support TIP4P");

  Verlet::init();
}

/* ----------------------------------------------------------------------
   setup before run
------------------------------------------------------------------------- */

void VerletSplitAnalysis::setup()
{
  if (comm->me == 0 && screen)
    fprintf(screen,"Setting up Verlet/splitanalysis run ...\n");

  Verlet::setup();

  if(!master && atom->nlocal > tmp_size) {
    tmp_size = atom->nlocal + _BUFFER_PAD;
    memory->grow(xtmp,   tmp_size*3, "xtmp");
    memory->grow(vtmp,   tmp_size*3, "vtmp");
    memory->grow(tagtmp, tmp_size,   "tagtmp");
  }
}

/* ----------------------------------------------------------------------
   setup without output
   flag = 0 = just force calculation
   flag = 1 = reneighbor and force calculation
------------------------------------------------------------------------- */

void VerletSplitAnalysis::setup_minimal(int flag)
{
  Verlet::setup_minimal(flag);
}

/* ----------------------------------------------------------------------
   run for N steps
   master partition does everything but Analysis
   servant partition does just Analysis
   communicate back and forth every step:
     atom coords from master -> servant
     also box bounds from master -> servant if necessary
------------------------------------------------------------------------- */

void VerletSplitAnalysis::run(int n)
{
  bigint ntimestep;
  int nflag,sortflag;

  // sync both partitions before start timer

//  MPI_Barrier(universe->uworld);

  timer->init();
  timer->barrier_start();

  // setup initial Sim <-> Analysis comm params

  sa_setup();

  // check if OpenMP support fix defined

  Fix *fix_omp;
  int ifix = modify->find_fix("package_omp");
  if (ifix < 0) fix_omp = NULL;
  else fix_omp = modify->fix[ifix];

  // flags for timestepping iterations

  int n_post_integrate = modify->n_post_integrate;
  int n_pre_exchange = modify->n_pre_exchange;
  int n_pre_neighbor = modify->n_pre_neighbor;
  int n_pre_force = modify->n_pre_force;
  int n_pre_reverse = modify->n_pre_reverse;
  int n_post_force = modify->n_post_force;
  int n_end_of_step = modify->n_end_of_step;

  if (atom->sortfreq > 0) sortflag = 1;
  else sortflag = 0;

  for (int i = 0; i < n; i++) {

    ntimestep = ++update->ntimestep;
    ev_set(ntimestep);

    // initial time integration

    if (master) {
      timer->stamp();
      modify->initial_integrate(vflag);
      if (n_post_integrate) modify->post_integrate();
      timer->stamp(Timer::MODIFY);
    }

    // regular communication vs. neighbor list rebuild
    // both partitions need to rebuild neighbor lists at same step to keep in sync

    if(neigh_sync_freq > 0) { // forced neighbor list rebuild

      nflag = 0;
			if(ntimestep%neigh_sync_freq == 0) {
							// ideally, the analysis partition is idle by time the simulation partition calls Bcast
							//  otherwise, load-imbalance...
							nflag = 1;
							//MPI_Bcast(&nflag,1,MPI_INT,1,block);
			}
      
			if (master && nflag == 0) { // simulation partition updates ghost particles
							timer->stamp();
							comm->forward_comm();
							timer->stamp(Timer::COMM);
      } 
      else if(nflag) { // both partitions update neighbor lists & ghost particles on same step

							// send current coordinates
							timer->stamp();
							s2a_comm(ntimestep);
							timer->stamp(Timer::COMM);

							timer->stamp();
							if (n_pre_exchange) modify->pre_exchange();
							timer->stamp(Timer::MODIFY);

							if (triclinic) domain->x2lamda(atom->nlocal);
							domain->pbc();
							if (domain->box_change) {
											domain->reset_box();
											comm->setup();
											if (neighbor->style) neighbor->setup_bins();
							}
							timer->stamp();
							comm->exchange();
							if (sortflag && ntimestep >= atom->nextsort) atom->sort();
							comm->borders();
							if (triclinic) domain->lamda2x(atom->nlocal+atom->nghost);
							timer->stamp(Timer::COMM);

							timer->stamp();
							if (n_pre_neighbor) {
											modify->pre_neighbor();
											timer->stamp(Timer::MODIFY);
							}
							sa_setup();

							neighbor->build();
							timer->stamp(Timer::NEIGH);

			}

		} else { // default neighbor list frequency

#if 1
						// new code
						// remain synced at each simulation step

   if (master) nflag = neighbor->decide();
   MPI_Bcast(&nflag,1,MPI_INT,1,block);

#if _DEBUG
   if(master && comm->me == 0) fprintf(stdout,"run::nflag= %i\n",nflag);
#endif
	if (nflag == 0 && master) {
							timer->stamp();
							comm->forward_comm();
							timer->stamp(Timer::COMM);
	} 
 else if(nflag == 1) {
	
	// send current coordinates
	timer->stamp();
	s2a_comm(ntimestep);
	timer->stamp(Timer::COMM);
	
	timer->stamp();
	if (n_pre_exchange) modify->pre_exchange();
	timer->stamp(Timer::MODIFY);
	
	if (triclinic) domain->x2lamda(atom->nlocal);
	domain->pbc();
	if (domain->box_change) {
	  domain->reset_box();
	  comm->setup();
	  if (neighbor->style) neighbor->setup_bins();
	}
	timer->stamp();
	comm->exchange();
	if (sortflag && ntimestep >= atom->nextsort) atom->sort();
	comm->borders();
	if (triclinic) domain->lamda2x(atom->nlocal+atom->nghost);
	timer->stamp(Timer::COMM);
	
	timer->stamp();
	if (n_pre_neighbor) {
	  modify->pre_neighbor();
	  timer->stamp(Timer::MODIFY);
	}
	neighbor->build();
	timer->stamp(Timer::NEIGH);

	sa_setup();
      }
  
      //      if(nflag) sa_setup();
#else
      // original code
      // remain synced at each simulation step

      if (master) nflag = neighbor->decide();
      MPI_Bcast(&nflag,1,MPI_INT,1,block);

      if(master) {
	if(comm->me == 0) fprintf(stdout,"run::nflag= %i\n",nflag);
	if (nflag == 0) {
	  timer->stamp();
	  comm->forward_comm();
	  timer->stamp(Timer::COMM);
	} 
	else {
	  timer->stamp();
	  if (n_pre_exchange) modify->pre_exchange();
	  timer->stamp(Timer::MODIFY);
	  
	  if (triclinic) domain->x2lamda(atom->nlocal);
	  domain->pbc();
	  if (domain->box_change) {
	    domain->reset_box();
	    comm->setup();
	    if (neighbor->style) neighbor->setup_bins();
	  }
	  timer->stamp();
	  comm->exchange();
	  if (sortflag && ntimestep >= atom->nextsort) atom->sort();
	  comm->borders();
	  if (triclinic) domain->lamda2x(atom->nlocal+atom->nghost);
	  timer->stamp(Timer::COMM);
	  
	  if (n_pre_neighbor) {
	    modify->pre_neighbor();
	    timer->stamp(Timer::MODIFY);
	  }
	  neighbor->build();
	  timer->stamp(Timer::NEIGH);
	}
      }

      if(nflag) sa_setup();
#endif
	
    } // if(neigh_sync_freq > 0)
      
    // force computations

    force_clear();

    if (master) {
      timer->stamp();

      if (n_pre_force) {
        modify->pre_force(vflag);
        timer->stamp(Timer::MODIFY);
      }

      if (force->pair) {
        force->pair->compute(eflag,vflag);
        timer->stamp(Timer::PAIR);
      }

      if (atom->molecular) {
        if (force->bond) force->bond->compute(eflag,vflag);
        if (force->angle) force->angle->compute(eflag,vflag);
        if (force->dihedral) force->dihedral->compute(eflag,vflag);
        if (force->improper) force->improper->compute(eflag,vflag);
        timer->stamp(Timer::BOND);
      }

      if (force->kspace) {
        force->kspace->compute(eflag,vflag);
        timer->stamp(Timer::KSPACE);
      }

      if (n_pre_reverse) {
        modify->pre_reverse(eflag,vflag);
        timer->stamp(Timer::MODIFY);
      }

      // reverse communication of forces

      if (force->newton) {
        comm->reverse_comm();
        timer->stamp(Timer::COMM);
      }

    } else {

      // run FixOMP as sole pre_force fix, if defined
      if (fix_omp) fix_omp->pre_force(vflag);

    }

    // force modifications, final time integration, diagnostics
    // all output

    if (master) {
      timer->stamp();
      if (n_post_force) modify->post_force(vflag);
      modify->final_integrate();
      timer->stamp(Timer::MODIFY);
    }


    // Send Analysis partition latest coordinates+velocities to perform analysis on

//for absolute 100% accurate results, uncomment these, commenting the below code gives almost 100% similar results

#if 0
    timer->stamp();
    if(neigh_sync_freq > 0) {
      if(ntimestep%neigh_sync_freq == 0) 
       s2a_comm(ntimestep);
    } else
      s2a_comm(ntimestep);
    timer->stamp(Timer::COMM);
#endif

    timer->stamp();
    if (n_end_of_step) modify->end_of_step();
    timer->stamp(Timer::MODIFY);

    if (master) {
      if (ntimestep == output->next) {
        timer->stamp();
        output->write(ntimestep);
        timer->stamp(Timer::OUTPUT);
      }
    } 


  }
}

/* ----------------------------------------------------------------------
   setup params for Sim <-> Analysis communication
   called initially and after every reneighbor
   also communcicate atom charges from Sim to Analysis since static
------------------------------------------------------------------------- */

void VerletSplitAnalysis::sa_setup()
{
  // qsize = # of atoms owned by each master proc in block

  int n = 0;
  if (master) n = atom->nlocal;

  MPI_Gather(&n,1,MPI_INT,qsize,1,MPI_INT,0,block);

  // setup qdisp, xsize, xdisp based on qsize
  // only needed by Analysis proc
  // set Analysis nlocal to sum of Sim nlocals
  // insure Analysis atom arrays are large enough

  if (!master) {
    qsize[0] = qdisp[0] = xsize[0] = xdisp[0] = 0;
    for (int i = 1; i <= ratio; i++) {
      qdisp[i] = qdisp[i-1]+qsize[i-1];
      xsize[i] = 3*qsize[i];
      xdisp[i] = xdisp[i-1]+xsize[i-1];
    }

  }

}

/* ----------------------------------------------------------------------
   communicate Sim atom coords to Analysis
   also eflag,vflag and box bounds if needed
------------------------------------------------------------------------- */

void VerletSplitAnalysis::s2a_comm(bigint ntimestep)
{
  double t = MPI_Wtime();

  if(!master && atom->nlocal > tmp_size) {
    tmp_size = atom->nlocal + _BUFFER_PAD;
    memory->grow(xtmp,   tmp_size*3, "xtmp");
    memory->grow(vtmp,   tmp_size*3, "vtmp");
    memory->grow(tagtmp, tmp_size,   "tagtmp");
  }

  int n = 0;
  if (master) n = atom->nlocal;

  MPI_Gatherv(atom->x[0],      n*3,MPI_DOUBLE,    xtmp,  xsize,xdisp,MPI_DOUBLE,    0,block);
  MPI_Gatherv(atom->v[0],      n*3,MPI_DOUBLE,    vtmp,  xsize,xdisp,MPI_DOUBLE,    0,block);
  MPI_Gatherv(&(atom->tag[0]), n,  MPI_LMP_TAGINT,tagtmp,qsize,qdisp,MPI_LMP_TAGINT,0,block);
  /*
  MPI_Igatherv(atom->x[0],      n*3,MPI_DOUBLE,    xtmp,  xsize,xdisp,MPI_DOUBLE,    0,block, &request_x);
  MPI_Igatherv(atom->v[0],      n*3,MPI_DOUBLE,    vtmp,  xsize,xdisp,MPI_DOUBLE,    0,block, &request_v);
  MPI_Igatherv(&(atom->tag[0]), n,  MPI_LMP_TAGINT,tagtmp,qsize,qdisp,MPI_LMP_TAGINT,0,block, &request_tag);
 */

  if(!master) {
#if _DEBUG
    if(comm->me == 0) fprintf(universe->uscreen,"s2a_comm::ntimestep= %i\n",ntimestep);
#endif
		int ierr = 0;
		for(int i=0; i<atom->nlocal; ++i) {
						const int ilocal = atom->map(tagtmp[i]);
						if(ilocal == -1) {
										fprintf(stdout,"(%i,%i)  Tags don't match!!  i= %i  tag= %i  tagtmp= %i  map= %i\n",
																		universe->iworld,comm->me,i,atom->tag[i],tagtmp[i],ilocal);
										ierr++;
						} else {
										atom->x[ilocal][0] = xtmp[i*3  ];
										atom->x[ilocal][1] = xtmp[i*3+1];
										atom->x[ilocal][2] = xtmp[i*3+2];

										atom->v[ilocal][0] = vtmp[i*3  ];
										atom->v[ilocal][1] = vtmp[i*3+1];
										atom->v[ilocal][2] = vtmp[i*3+2];
						}
		}
		if(ierr) {
						MPI_Barrier(world);
						error->universe_one(FLERR,"tags out of sync");
    }
  }


  t = MPI_Wtime() - t;
  if(neigh_sync_freq > 0) {
    if(ntimestep%neigh_sync_freq == 0 && comm->me == 0 && ntimestep%100 == 500)
      printf("%d: time to gather on partition %i = %lf\n",ntimestep,universe->iworld,t);
  } else
    if (ntimestep % 100 == 0 && comm->me == 0) 
      printf("%d: time to gather on partition %i = %lf\n",ntimestep,universe->iworld,t);


  // proof-of-concept test (which, of course, causes crash)
  // int imsize[1] = {xsize[0] / 3};
  // int imdisp[1] = {xdisp[0] / 3};
  // MPI_Gatherv(atom->image, n, MPI_LMP_TAGINT, atom->image, imsize, imdisp,
  //       MPI_LMP_TAGINT, 0, block);
  
  // Analysis partition needs to update its ghost atoms; 
  // for time being until confirm ghost atoms actually needed.

  if (!master) comm->forward_comm();
}

/* ----------------------------------------------------------------------
   memory usage of Analysis force array on master procs
------------------------------------------------------------------------- */
//FIXME
  bigint VerletSplitAnalysis::memory_usage()
{
  bigint bytes = maxatom*3 * sizeof(double);
  bytes += atom->nlocal*6*sizeof(double); // xtmp, vtmp
  bytes += atom->nlocal*sizeof(bigint);   // tagtmp
  return bytes;
}
