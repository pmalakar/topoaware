import sys

nodes=int(sys.argv[1])
ppn=int(sys.argv[2])
ratio=int(sys.argv[3])

slimit_per_node=ppn-ppn/(ratio+1)
alimit_per_node=ppn-slimit_per_node

simLB=0
anaLB=nodes*slimit_per_node

for node in range(0, nodes):

#print partition 1 ranks
	#for rank in range(simLB, simLB+slimit_per_node):
	for rank in range(simLB+slimit_per_node, simLB, -1):
		print rank-1
	simLB += slimit_per_node

#print partition 2 ranks
	for rank in range(anaLB, anaLB+alimit_per_node):
		print rank
	anaLB += alimit_per_node

