#!/bin/bash -x
#PBS -l select=512
#PBS -l walltime=01:00:00
#PBS -A Aurora_deployment
#PBS -q lustre_scaling
#PBS -k doe
#PBS -ldaos=default

# qsub -l select=512:ncpus=208 -l walltime=01:00:00 -A Aurora_deployment -l filesystems=flare -q lustre_scaling  -ldaos=default  ./pbs_script.sh or - I 
module use /soft/modulefiles
module load daos
env | grep DRPC  
ps -ef|grep daos
DAOS_POOL=datascience
DAOS_CONT=hacc_1
daos pool query ${DAOS_POOL} #To confirm if you have access to your pool
# daos container create --type POSIX --dir-oclass=S1 --file-oclass=SX  ${DAOS_POOL}  ${DAOS_CONT} #This is required for 1 time only
# Note there is no data recovery on crash on this oclass mode. 

launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse


cd $PBS_O_WORKDIR
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
export TZ='/usr/share/zoneinfo/US/Central'
date
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=12          # Number of MPI ranks per node
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:56:61:66:71:74:79
EXT_ENV1="--env FI_CXI_DEFAULT_CQ_SIZE=1048576 --env GENERICIO_PARTITIONS_USE_NAME=0 --env GENERICIO_RANK_PARTITIONS=4"
EXT_ENV2="--env FI_CXI_DEFAULT_CQ_SIZE=1048576 --env GENERICIO_PARTITIONS_USE_NAME=0 --env GENERICIO_RANK_PARTITIONS=4 --env GENERICIO_USE_MPIIO=1" #note GENERICIO_USE_MPIIO is used only for mpiio 

GenericIOBenchmarkWrite=/lus/flare/projects/Aurora_deployment/kaushik/daos/hacc/genric-io/genericio/mpi/GenericIOBenchmarkWrite 
GenericIOBenchmarkRead=/lus/flare/projects/Aurora_deployment/kaushik/daos/hacc/genric-io/genericio/mpi/GenericIOBenchmarkRead 

rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/*

#/tmp/${DAOS_POOL}/${DAOS_CONT}/ - This is the location where daos is mounted and your app data should be stored

date 
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec ${EXT_ENV1} -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1}  --no-vni -genvall  ${GenericIOBenchmarkWrite} /tmp/${DAOS_POOL}/${DAOS_CONT}/daos_pos_test_kaus_1_ 4000 5
date
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec ${EXT_ENV1} -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1}  --no-vni -genvall  ${GenericIOBenchmarkRead}  /tmp/${DAOS_POOL}/${DAOS_CONT}/daos_pos_test_kaus_1_ 
date
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec ${EXT_ENV2} -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1}  --no-vni -genvall  ${GenericIOBenchmarkWrite} -a /tmp/${DAOS_POOL}/${DAOS_CONT}/daos_pos_test_kaus_2_ 4000 5
date
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec ${EXT_ENV2} -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1}  --no-vni -genvall  ${GenericIOBenchmarkRead}  -a /tmp/${DAOS_POOL}/${DAOS_CONT}/daos_pos_test_kaus_2_  
date


# check if LD_PRELOAD=/usr/lib64/libioil.so gives a better performance than libpil4dfs.so

clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}

# daos container query     ${DAOS_POOL}  ${DAOS_CONT} 
# daos container get-prop  ${DAOS_POOL}  ${DAOS_CONT} 
# daos container list      ${DAOS_POOL}  ${DAOS_CONT} 
# daos pool      autotest  ${DAOS_POOL} 
# daos container destroy   ${DAOS_POOL}  ${DAOS_CONT} 
