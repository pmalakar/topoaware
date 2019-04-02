import os
import time
from subprocess import *

nodes = [1024] #, 512, 256, 128]

def runcmd (node, iter):

	script = './run.sh ' + str(node) + ' ' + str(iter) #+ ' ' + pgm
	if node == 1024 and iter%2 == 0:
		GEOMETRY="--geometry 4x4x4x8x2"
	elif node == 1024 and iter%2 == 1:
		GEOMETRY="--geometry 4x4x8x4x2"

	cmd = 'qsub -A Performance -t 01:00:00 -n ' + str(node) + '  ' + GEOMETRY + ' --mode script ' + script
	print 'Executing ' + cmd
	jobid = Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
	print 'Jobid : ' + jobid
	
	while True:
		cmd = 'qstat ' + jobid.strip() + ' | grep preeti | awk \'{print $1}\''
		jobrun = Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		if jobrun == '':
			break
		time.sleep(60)

	return jobid.strip()

for iter in range (1, 3):
 for node in nodes:
  #for analysis in analyses:

		print '\nStarting on ' + str(node) + ' nodes ' #for ' + analysis  
		jobid = runcmd(node, iter)

		filename = 'lammps_'+str(node)+'_'+str(iter)
		print filename + ' ' + jobid

		cmd = 'mv ' + jobid.strip() + '.output ' + filename + '.output'
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		cmd = 'mv ' + jobid.strip() + '.error ' + filename + '.error'
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		cmd = 'mv ' + jobid.strip() + '.cobaltlog ' + filename + '.cobaltlog'
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]

		cmd = 'ls -t mpi_profile*.0 | head \-1'
		fname = Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		cmd = 'cp ' + fname.strip() + ' ' + filename + '.' + fname
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]

		cmd = 'ls -t hpm_process*.0 | head \-1'
		fname = Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		cmd = 'cp ' + fname.strip() + ' ' + filename + '.' + fname
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]

		continue

		cmd = 'ls -t gmon.out.0 | head \-1'
		fname = Popen(cmd, shell=True, stdout=PIPE).communicate()[0]
		cmd = 'cp ' + fname.strip() + ' ' + filename + '.' + fname
		Popen(cmd, shell=True, stdout=PIPE).communicate()[0]



