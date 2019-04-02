/*
	Determine decomposition of P1 and P2 into xyz
*/

/* number of processes for simulation */
param kappa >= 0, := 1;
param P_simulation, integer, > 0;

/* number of processes for analysis */
param P_analysis, integer, > 0;

param NumFactors, integer > 0;
set I := 1..NumFactors;

param Factors{i in I}, integer, > 0;
param Mult_simulation{i in I}, integer, > 0;
param Mult_analysis{i in I}, integer, >= 0;

var k_simulation_1 {i in I}, integer, >= 0;
var k_simulation_2 {i in I}, integer, >= 0;
var k_simulation_3 {i in I}, integer, >= 0;
var k_analysis_1 {i in I}, integer, >= 0;
var k_analysis_2 {i in I}, integer, >= 0;
var k_analysis_3 {i in I}, integer, >= 0;
var k_analysis_max {i in I}, integer, >= 0;

/* Maximize the number of analysis */
minimize obj: sum {i in I} (log(Factors[i])*(kappa*(2*k_simulation_1[i]-k_simulation_2[i]-k_simulation_3[i])+3*k_analysis_max[i]-k_analysis_1[i]-k_analysis_2[i]-k_analysis_3[i])); 

/* Add up x y z dimension processes to total number for simulation/analysis processes */
s.t. product_of_sim_procs {i in I}:  k_simulation_1[i] + k_simulation_2[i] + k_simulation_3[i] = Mult_simulation[i];
s.t. product_of_analysis_procs {i in I}: k_analysis_1[i] + k_analysis_2[i] + k_analysis_3[i] = Mult_analysis[i];

s.t. bnd1a: sum {i in I} log(Factors[i])*k_simulation_2[i] <= sum {i in I} log(Factors[i])*k_simulation_1[i];
s.t. bnd1b: sum {i in I} log(Factors[i])*k_simulation_3[i] <= sum {i in I} log(Factors[i])*k_simulation_2[i];

s.t. bnd2a: sum {i in I} log(Factors[i])*k_analysis_1[i] <= sum {i in I} log(Factors[i])*k_analysis_max[i];
s.t. bnd2b: sum {i in I} log(Factors[i])*k_analysis_2[i] <= sum {i in I} log(Factors[i])*k_analysis_max[i];
s.t. bnd2c: sum {i in I} log(Factors[i])*k_analysis_3[i] <= sum {i in I} log(Factors[i])*k_analysis_max[i];

s.t. sos1: sum{i in I} k_simulation_1[i] >= 1;
s.t. sos2: sum{i in I} k_simulation_2[i] >= 1;
s.t. sos3: sum{i in I} k_simulation_3[i] >= 1;

s.t. soa1: sum{i in I} k_analysis_1[i] >= 1;
s.t. soa2: sum{i in I} k_analysis_2[i] >= 1;
s.t. soa3: sum{i in I} k_analysis_3[i] >= 1;

/* To ensure divisibility */

s.t. bnd1{i in I}: k_analysis_1[i] <= k_simulation_1[i];
s.t. bnd2{i in I}: k_analysis_2[i] <= k_simulation_2[i];
s.t. bnd3{i in I}: k_analysis_3[i] <= k_simulation_3[i];

end;


