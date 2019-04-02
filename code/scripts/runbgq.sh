#!/bin/bash -x
#COBALT --disable_preboot

#export L1P_POLICY=std
#export BG_THREADLAYOUT=1   # 1 - default next core first; 2 - my core first

function cleanup {

	DIR=$1
	mkdir $DIR
	mv mpi_profile.* $DIR/
	mv hpm_* $DIR/
	mv pattern* $DIR/

}

#Free bootable blocks
boot-block --reboot

NODES=$1
start=$2
end=$(($start+1))

#p1=1; p2=1
p1_x=1; p1_y=1; p1_z=1
p2_x=1; p2_y=1; p2_z=1

for PROG in lmp_bgq
do
	for iter in `seq $start $end`
	do
		for ppn in 16  
		do
			for RATIO in 3  
			do
				for repl_dim in 8
				do 
					#for PROB in hcl hcl.rerun.rdf hcl.rerun.msd hcl.rerun.msd.bin1d hcl.rerun.msd.bin2d hcl.rerun.vacf
					for PROB in hcl #rhodo rhodo.rerun
					do


						RANKS=`echo "$NODES*$ppn"|bc`
						p2=`echo "$RANKS/($RATIO+1)"|bc`
						p1=`echo "$RANKS-$p2"|bc`

						echo "$RANKS: P1:$p1 P2:$p2 Ratio: $RATIO" 

						if [ $RATIO -eq 1 ]; then

							if [ $RANKS -eq 256 ]; then
								p1_x=8; p1_y=4; p1_z=4
								p2_x=8; p2_y=4; p2_z=4
							elif [ $RANKS -eq 320 ]; then
								p1_x=8; p1_y=5; p1_z=4
								p2_x=8; p2_y=5; p2_z=4
							elif [ $RANKS -eq 352 ]; then
								p1_x=11; p1_y=8; p1_z=4
								p2_x=11; p2_y=8; p2_z=4
							elif [ $RANKS -eq 448 ]; then
								p1_x=8; p1_y=8; p1_z=7
								p2_x=8; p2_y=8; p2_z=7
							elif [ $RANKS -eq 512 ]; then
								p1_x=8; p1_y=8; p1_z=4
								p2_x=8; p2_y=8; p2_z=4
							elif [ $RANKS -eq 1024 ]; then
								p1_x=8; p1_y=8; p1_z=8
								p2_x=8; p2_y=8; p2_z=8
							elif [[ $RANKS -eq 2048 && $decomp -eq 1 ]]; then
								p1_x=16; p1_y=8; p1_z=8
								p2_x=16; p2_y=8; p2_z=8
								echo "for $decomp $RANKS "
							elif [[ $RANKS -eq 2048 && $decomp -eq 2 ]]; then
								p1_x=8; p1_y=16; p1_z=8
								p2_x=8; p2_y=16; p2_z=8
								echo "for $decomp $RANKS "
							elif [[ $RANKS -eq 2048 && $decomp -eq 3 ]]; then
								p1_x=8; p1_y=64; p1_z=2
								p2_x=8; p2_y=64; p2_z=2
								echo "for $decomp $RANKS "
							elif [ $RANKS -eq 4096 ]; then
								p1_x=16; p1_y=16; p1_z=8
								p2_x=16; p2_y=16; p2_z=8
							elif [ $RANKS -eq 6144 ]; then
								p1_x=16; p1_y=16; p1_z=12
								p2_x=16; p2_y=16; p2_z=12
							elif [ $RANKS -eq 8192 ]; then
								p1_x=16; p1_y=16; p1_z=16
								p2_x=16; p2_y=16; p2_z=16
							elif [ $RANKS -eq 16384 ]; then
								p1_x=32; p1_y=16; p1_z=16
								p2_x=32; p2_y=16; p2_z=16
							elif [ $RANKS -eq 32768 ]; then
								p1_x=32; p1_y=32; p1_z=16
								p2_x=32; p2_y=32; p2_z=16
							elif [ $RANKS -eq 65536 ]; then
								p1_x=32; p1_y=32; p1_z=32
								p2_x=32; p2_y=32; p2_z=32
							fi

						elif [ $RATIO -eq 3 ]; then

							if [ $RANKS -eq 256 ]; then
								p1_x=8; p1_y=4; p1_z=6
								p2_x=8; p2_y=4; p2_z=2
							elif [ $RANKS -eq 512 ]; then
								p1_x=8; p1_y=8; p1_z=6
								p2_x=8; p2_y=8; p2_z=2
							elif [ $RANKS -eq 1024 ]; then
								p1_x=8; p1_y=8; p1_z=12
								p2_x=8; p2_y=8; p2_z=4
							elif [ $RANKS -eq 2048 ]; then
								p1_x=16; p1_y=8; p1_z=12
								p2_x=16; p2_y=8; p2_z=4
							elif [ $RANKS -eq 4096 ]; then
								p1_x=16; p1_y=16; p1_z=12
								p2_x=16; p2_y=16; p2_z=4
							elif [ $RANKS -eq 8192 ]; then
								p1_x=16; p1_y=16; p1_z=24
								p2_x=16; p2_y=16; p2_z=8
							elif [ $RANKS -eq 11520 ]; then
								p1_x=24; p1_y=16; p1_z=20		#7680
								p2_x=24; p2_y=16; p2_z=10		#3840
							elif [ $RANKS -eq 16384 ]; then
								p1_x=32; p1_y=16; p1_z=24
								p2_x=32; p2_y=16; p2_z=8
							elif [ $RANKS -eq 32768 ]; then
								p1_x=32; p1_y=32; p1_z=24
								p2_x=32; p2_y=32; p2_z=8
							elif [ $RANKS -eq 65536 ]; then
								p1_x=32; p1_y=32; p1_z=48
								p2_x=32; p2_y=32; p2_z=16
							fi

						elif [ $RATIO -eq 7 ]; then

							if [ $RANKS -eq 256 ]; then
								p1_x=4; p1_y=4; p1_z=14
								p2_x=4; p2_y=4; p2_z=2
							elif [ $RANKS -eq 512 ]; then
								p1_x=8; p1_y=4; p1_z=14
								p2_x=8; p2_y=4; p2_z=2
							elif [ $RANKS -eq 1024 ]; then
								p1_x=8; p1_y=8; p1_z=14
								p2_x=8; p2_y=8; p2_z=2
							elif [ $RANKS -eq 2048 ]; then
								p1_x=16; p1_y=8; p1_z=14
								p2_x=16; p2_y=8; p2_z=2
							elif [ $RANKS -eq 4096 ]; then
								p1_x=16; p1_y=16; p1_z=14
								p2_x=16; p2_y=16; p2_z=2
							elif [ $RANKS -eq 8192 ]; then
								p1_x=16; p1_y=16; p1_z=28
								p2_x=16; p2_y=16; p2_z=4
							elif [ $RANKS -eq 16384 ]; then
								p1_x=32; p1_y=16; p1_z=28
								p2_x=32; p2_y=16; p2_z=4
							elif [ $RANKS -eq 32768 ]; then
								p1_x=32; p1_y=32; p1_z=28
								p2_x=32; p2_y=32; p2_z=4
							elif [ $RANKS -eq 65536 ]; then
								p1_x=64; p1_y=32; p1_z=28
								p2_x=64; p2_y=32; p2_z=4
							fi

						elif [ $RATIO -eq 15 ]; then		#leaving out few procs to make it divisible

							if [ $RANKS -eq 512 ]; then	
								p1_x=4; p1_y=4; p1_z=30		# 20 12 2
								p2_x=4; p2_y=4; p2_z=2		# 4  4  2
							elif [ $RANKS -eq 1024 ]; then	
								p1_x=4; p1_y=12; p1_z=20	
								p2_x=4; p2_y=4; p2_z=4	
							elif [ $RANKS -eq 1536 ]; then						#192 * R8
								p1_x=12; p1_y=12; p1_z=10
								p2_x=12; p2_y=4; p2_z=2	   #96
							elif [ $RANKS -eq 2048 ]; then	
								p1_x=16; p1_y=12; p1_z=10		#1920
								p2_x=16; p2_y=4; p2_z=2			#128
							elif [ $RANKS -eq 2560 ]; then				#320 * R8	
								p1_x=16; p1_y=15; p1_z=10		#2400
								p2_x=16; p2_y=5; p2_z=2			#160
							elif [ $RANKS -eq 2816 ]; then				#352 * R8	
								p1_x=16; p1_y=16; p1_z=10		#2560
								p2_x=16; p2_y=8; p2_z=2			#256
							elif [ $RANKS -eq 3584 ]; then						#448 * R8
								p1_x=28; p1_y=20; p1_z=12		#3360
								p2_x=14; p2_y=4; p2_z=4 		#224
							elif [ $RANKS -eq 4096 ]; then
								p1_x=16; p1_y=24; p1_z=10		#3840
								p2_x=16; p2_y=8; p2_z=2   	#256	
							elif [ $RANKS -eq 5120 ]; then
								p1_x=20; p1_y=20; p1_z=12	  #4800
								p2_x=20; p2_y=4; p2_z=4  	#320
							elif [ $RANKS -eq 5632 ]; then
								p1_x=20; p1_y=12; p1_z=22	  #5280
								p2_x=4; p2_y=4; p2_z=22   	#352
							elif [ $RANKS -eq 6144 ]; then
								p1_x=24; p1_y=20; p1_z=12		#3840
								p2_x=24; p2_y=4; p2_z=4  	  #256	
							elif [ $RANKS -eq 7168 ]; then
								p1_x=28; p1_y=20; p1_z=24		#6720
								p2_x=14; p2_y=4; p2_z=8  	  #448
							elif [ $RANKS -eq 8192 ]; then
								p1_x=16; p1_y=24; p1_z=20		#7680
								p2_x=16; p2_y=8; p2_z=4			#512
							elif [ $RANKS -eq 16384 ]; then
								p1_x=32; p1_y=32; p1_z=15
								p2_x=8; p2_y=8; p2_z=15
							fi

						elif [ $RATIO -eq 31 ]; then		#leaving out few procs to make it divisible

							if [ $RANKS -eq 8192 ]; then
								p1_x=16; p1_y=15; p1_z=32
								p2_x=2; p2_y=15; p2_z=8
								#	p1_x=16; p1_y=16; p1_z=31
								#	p2_x=4; p2_y=2; p2_z=31
							elif [ $RANKS -eq 16384 ]; then
								p1_x=32; p1_y=16; p1_z=31
								p2_x=4; p2_y=4; p2_z=31
							elif [ $RANKS -eq 32768 ]; then
								p1_x=32; p1_y=32; p1_z=31
								p2_x=8; p2_y=4; p2_z=31
							elif [ $RANKS -eq 65536 ]; then
								p1_x=64; p1_y=32; p1_z=31
								p2_x=8; p2_y=8; p2_z=31
							fi

						elif [ $RATIO -eq 63 ]; then		#leaving out few procs to make it divisible

							if [ $RANKS -eq 4096 ]; then
								p1_x=16; p1_y=21; p1_z=12		#4032
								p2_x=4; p2_y=7; p2_z=2			#56
							elif [ $RANKS -eq 8192 ]; then
								p1_x=32; p1_y=21; p1_z=12
								p2_x=8; p2_y=7; p2_z=2
							elif [ $RANKS -eq 65536 ]; then
								p1_x=32; p1_y=32; p1_z=63
								p2_x=4; p2_y=4; p2_z=63
							elif [ $RANKS -eq 131072 ]; then
								p1_x=64; p1_y=32; p1_z=63
								p2_x=8; p2_y=4; p2_z=63
							fi

						fi

						check1=`echo "$p1_x*$p1_y*$p1_z"|bc`
						check2=`echo "$p2_x*$p2_y*$p2_z"|bc`
						check=`echo "$p1+$p2"|bc`

						if [ "$check" -gt "$RANKS" ]; then
							echo "Error: $check gt $RANKS"		
							exit
						fi
						if [ "$check1" -ne "$p1" ]; then
							echo "Error: $check1 ne $p1"		
							#exit
						fi
						if [ "$check2" -ne "$p2" ]; then
							echo "Error: $check2 ne $p2"		
							#exit
						fi

						p1=`echo "$p1_x*$p1_y*$p1_z"|bc`
						p2=`echo "$p2_x*$p2_y*$p2_z"|bc`
						RANKS=`echo "$p1+$p2"|bc`


						echo "Test: $p1 = $p1_x . $p1_y . $p1_z, $p2 = $p2_x . $p2_y . $p2_z, $RANKS=$p1+$p2"


						#ENVS="--envs PAMID_COLLECTIVES_MEMORY_OPTIMIZED=1 --envs PAMID_RZV_LOCAL=4M --envs OMP_NUM_THREADS=4 --envs PAMID_STATISTICS=1 --envs PAMID_VERBOSE=1"
						#ENVS="--envs PAMID_COLLECTIVES_MEMORY_OPTIMIZED=1 MUSPI_NUMINJFIFOS=2 MUSPI_NUMRECFIFOS=2 OMP_NUM_THREADS=4 PAMID_STATISTICS=1 PAMID_VERBOSE=1"
						#ENVS="--envs PAMID_COLLECTIVES_MEMORY_OPTIMIZED=1 OMP_NUM_THREADS=4 PAMID_STATISTICS=1 PAMID_VERBOSE=1 TRACE_ALL_RANKS=yes OUTPUT_ALL_RANKS=yes SAVE_ALL_TASKS=yes TRACE_SEND_PATTERN=yes"


						threads=4
						ENVS="--envs MUSPI_INJFIFOSIZE=2097152  PAMID_RZV_LOCAL=2M MUSPI_NUMINJFIFOS=2 MUSPI_NUMRECFIFOS=2 PAMID_COLLECTIVES_MEMORY_OPTIMIZED=1 OMP_NUM_THREADS=${threads} PAMID_STATISTICS=1 PAMID_VERBOSE=2 TRACE_ALL_RANKS=yes OUTPUT_ALL_RANKS=yes SAVE_ALL_TASKS=yes TRACE_SEND_PATTERN=yes"

						#ENVS="PAMID_VERBOSE=1 PAMID_COLLECTIVES_MEMORY_OPTIMIZED=1 BGMPIO_TUNEBLOCKING=0 BGMPIO_NAGG_PSET=${NAGG}"

						echo 
						echo "* * * * *"
						echo 
						#ARG="-in lmp.$PROB.in -var repl_dim $repl_dim -log lmp.log"
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_coanalysis_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						echo "Starting $OUTPUT with $ARG"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} : ${PROG} ${ARG} > ${OUTPUT} 
						#runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO --envs ${ENVS} : ${PROG} ${ARG} #> ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 ${COBALT_JOBID}.hpm_process_summary.0.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


						echo 
						echo "* * * * *"
						echo 
						nth=$(($RATIO+1))
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_reorder_firstlast_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						mapfile=firstlast_N${NODES}R${ppn}_$RATIO
						echo "Starting $OUTPUT with $ARG with $mapfile"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} --envs RUNJOB_MAPPING=$mapfile : ${PROG} ${ARG} > ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


						echo 
						echo "* * * * *"
						echo 
						nth=$(($RATIO+1))
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_reorder_core_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						mapfile=N${NODES}R${ppn}_$RATIO
						echo "Starting $OUTPUT with $ARG with $mapfile"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} --envs RUNJOB_MAPPING=$mapfile : ${PROG} ${ARG} > ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 

						echo 
						echo "* * * * *"
						echo 
						nth=$(($RATIO+1))
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_reorder_midcore_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						mapfile=mid_N${NODES}R${ppn}_$RATIO
						echo "Starting $OUTPUT with $ARG with $mapfile"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} --envs RUNJOB_MAPPING=$mapfile : ${PROG} ${ARG} > ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 

						echo 
						echo "* * * * *"
						echo 
						nth=$(($RATIO+1))
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_reorder_bgqcore_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						mapfile=bgq_N${NODES}R${ppn}_$RATIO
						echo "Starting $OUTPUT with $ARG with $mapfile"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} --envs RUNJOB_MAPPING=$mapfile : ${PROG} ${ARG} > ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


						echo 
						echo "* * * * *"
						echo 
						nth=$(($RATIO+1))
						ARG="-in lmp.${PROB}.replica.in -var repl_dim $repl_dim -reorder nth ${nth} -var p1_x ${p1_x} -var p1_y ${p1_y} -var p1_z ${p1_z} -var p2_x ${p2_x} -var p2_y ${p2_y} -var p2_z ${p2_z} -log lmp.log -p $p1 $p2" 
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_reorder_nth_${nth}_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						echo "Starting $OUTPUT with $ARG"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} : ${PROG} ${ARG} > ${OUTPUT} 
						#runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO --envs ${ENVS} : ${PROG} ${ARG} #> ${OUTPUT} 
						mv lmp.log.0 ${COBALT_JOBID}_lmp.log.0.${OUTPUT}
						mv lmp.log.1 ${COBALT_JOBID}_lmp.log.1.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


						echo 
						echo "* * * * *"
						echo 
						ARG="-in lmp.${PROB}.insitu.in -var repl_dim $repl_dim -log lmp.log"
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_insitu_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						echo "Starting $OUTPUT with $ARG"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} : ${PROG} ${ARG} > ${OUTPUT} 
						#runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO --envs ${ENVS} : ${PROG} ${ARG} #> ${OUTPUT} 
						mv lmp.log ${COBALT_JOBID}_lmp.log.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


						echo 
						echo "* * * * *"
						echo 
						ARG="-in lmp.$PROB.in -var repl_dim $repl_dim -log lmp.log"
						OUTPUT=${PROG}_${NODES}_R${ppn}.${RATIO}_${decomp}_sim_repl${repl_dim}_${iter}_${p1}_${p2}_${COBALT_JOBID}
						echo "Starting $OUTPUT with $ARG"
						runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO ${ENVS} : ${PROG} ${ARG} > ${OUTPUT} 
						#runjob --np $RANKS -p $ppn --block $COBALT_PARTNAME --verbose=INFO --envs ${ENVS} : ${PROG} ${ARG} #> ${OUTPUT} 
						mv lmp.log ${COBALT_JOBID}_lmp.log.${OUTPUT}
						mv mpi_profile.*.0 ${COBALT_JOBID}_mpi_profile.0.${OUTPUT}
						mv hpm_process_summary.${COBALT_JOBID}.0 hpm_process_summary.${COBALT_JOBID}.0.${OUTPUT}
						mv vacf.ion.dat vacf.ion.dat.${OUTPUT} 
						mv msd.bin1d.dat msd.bin1d.dat.${OUTPUT}
						mv msd.bin2d.dat msd.bin2d.dat.${OUTPUT}
						DIR=d$OUTPUT
						cleanup $DIR
						echo 
						echo "* * * * *"
						echo 


					done
				done
			done
		done
	done
done

exit

