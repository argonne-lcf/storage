#!/bin/bash -x
#PBS -l select=512
#PBS -l walltime=01:00:00
#PBS -A Aurora_deployment
#PBS -q lustre_scaling
#PBS -k doe
#PBS -ldaos=default

# qsub -l select=512:ncpus=208 -l walltime=01:00:00 -A Aurora_deployment -l filesystems=flare -q lustre_scaling  -ldaos=default  ./pbs_script.sh or - I 

export TZ='/usr/share/zoneinfo/US/Central'
date
module use /soft/modulefiles
module load daos
env | grep DRPC                                     #optional
ps -ef|grep daos                                    #optional
clush --hostfile ${PBS_NODEFILE}  'ps -ef|grep agent|grep -v grep'  | dshbak -c  #optional
DAOS_POOL=datascience
DAOS_CONT=mdtest_1
daos pool query ${DAOS_POOL}                        #optional
daos cont list ${DAOS_POOL}                         #optional
daos container destroy   ${DAOS_POOL}  ${DAOS_CONT} #optional
daos container create --type POSIX ${DAOS_POOL}  ${DAOS_CONT} --properties rd_fac:1 
daos container query     ${DAOS_POOL}  ${DAOS_CONT} #optional
daos container get-prop  ${DAOS_POOL}  ${DAOS_CONT} #optional
daos container list      ${DAOS_POOL}  #optional
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse                                    #optional
ls /tmp/${DAOS_POOL}/${DAOS_CONT}                   #optional

cd $PBS_O_WORKDIR
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=16          # Number of MPI ranks per node
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:30:35:56:61:66:71:72:77:82:87

export LD_LIBRARY_PATH=/lus/../daos/ior_mdtest/ior-bin/lib:$LD_LIBRARY_PATH
export PATH=/lus/../daos/ior_mdtest/ior-bin/bin:$PATH


mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -z 0 -F -i 5 -v -n 1                        > "lustre_mdtest_1node_posix_local${rpn}_small.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "lustre_mdtest_1node_posix_local${rpn}_big.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 1                     > "lustre_mdtest_1node_posix_local${rpn}_small_S.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "lustre_mdtest_1node_posix_local${rpn}_big_S.txt"

LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 1                           > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"
 
LD_PRELOAD=/usr/lib64/libdaos.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 1                           > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
LD_PRELOAD=/usr/lib64/libdaos.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
LD_PRELOAD=/usr/lib64/libdaos.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
LD_PRELOAD=/usr/lib64/libdaos.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"

mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -z 0 -F -i 5 -v -n 1                        > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 1                     > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"


clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
