#!/bin/bash -x
#PBS -l select=256
#PBS -l walltime=04:00:00
#PBS -A Aurora_deployment
#PBS -q lustre_scaling
#PBS -k doe
#PBS -ldaos=default

# qsub -l select=256:ncpus=208 -l walltime=04:00:00 -A Aurora_deployment -l filesystems=flare -q lustre_scaling  -ldaos=default  ./pbs_script.sh or - I 

export TZ='/usr/share/zoneinfo/US/Central'
date
module use /soft/modulefiles
module load daos
env | grep DRPC  
ps -ef|grep daos
clush --hostfile ${PBS_NODEFILE}  'ps -ef|grep agent|grep -v grep'  | dshbak -c 
DAOS_POOL=datascience
DAOS_CONT=io500_2
daos pool query ${DAOS_POOL}   
daos cont list ${DAOS_POOL} 
daos container destroy   ${DAOS_POOL}  ${DAOS_CONT}
daos container create --type POSIX  ${DAOS_POOL}  ${DAOS_CONT} --properties rd_fac:1 
daos container query     ${DAOS_POOL}  ${DAOS_CONT} 
daos container get-prop  ${DAOS_POOL}  ${DAOS_CONT} 
daos container list      ${DAOS_POOL}  ${DAOS_CONT} 

launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse

cd $PBS_O_WORKDIR
rm -rf results/ datafiles/
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=16
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:30:35:56:61:66:71:72:77:82:87

 
date 
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1}  --no-vni -genvall   --env DAOS_POOL=datascience --env DAOS_CONT=io500_2 ./io500 config-full-isc22-daos-small.ini
date


daos container destroy   ${DAOS_POOL}  ${DAOS_CONT}
clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
