#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=00:30:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q alcf_daos_cn
#PBS -k doe
# qsub -l select=1 -l walltime=06:00:00 -A Aurora_deployment -q alcf_daos_cn -l daos=default ./mdtest_2.sh  or - I 
# Takes ~60 mins for single node. 

# from https://github.com/hpc/ior/blob/main/doc/mdtest.1

# Passing  "-S" Shared file access (file only, no directories).
# Not passing -S

# Add stone walling 

# "-W" seconds Specify the stonewall time in seconds.  When the stonewall timer has elapsed, the rank with the highest number of creates sets
# "-x" filename Filename to use for stonewall synchronization between processes.


date
echo cat $PBS_NODEFILE
nnodes=$(cat $PBS_NODEFILE | wc -l)
cd $PBS_O_WORKDIR
module use /soft/modulefiles # Needed for ior
module load  oneapi/eng-compiler/2022.12.30.003  #for libimf
export LD_LIBRARY_PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/lib:$LD_LIBRARY_PATH
export PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/bin/:$PATH

threads=1
rpn=16


module use /soft/modulefiles
module load daos/base
module load mpich/51.2/icc-all-pmix-gpu 
module list
env|grep DRPC
export DAOS_POOL=datascience
export DAOS_CONT=kaus-mdtest1-$nnodes
daos container create --type POSIX --dir-oclass=S1 --file-oclass=S1 ${DAOS_POOL} ${DAOS_CONT}

# daos container create --type POSIX --dir-oclass=S1 --file-oclass=S16 ${DAOS_POOL} ${DAOS_CONT}
# daos container create --type POSIX --dir-oclass=S1 --file-oclass=EC_16P2GX ${DAOS_POOL} ${DAOS_CONT}
# daos container create --type POSIX --dir-oclass=S1 --file-oclass=SX ${DAOS_POOL} ${DAOS_CONT}



daos container get-prop ${DAOS_POOL} ${DAOS_CONT}
daos cont      query    ${DAOS_POOL} ${DAOS_CONT}
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse


# export D_LOG_MASK=INFO  
# export D_LOG_STDERR_IN_LOG=1
# export D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
# export D_IL_REPORT=1 # Logs for IL
# LD_PRELOAD=$DAOS_PRELOAD mpiexec 




mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni  mdtest -d $PBS_O_WORKDIR/ -a POSIX -z 0 -F -i 5 -v -n 1                        > "lustre_mdtest_1node_posix_local${rpn}_small.txt"
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni  mdtest -d $PBS_O_WORKDIR/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "lustre_mdtest_1node_posix_local${rpn}_big.txt"
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni  mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 1                     > "lustre_mdtest_1node_posix_local${rpn}_small_S.txt"
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni  mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "lustre_mdtest_1node_posix_local${rpn}_big_S.txt"


rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/*
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 1                           > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_old_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 


mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 1                           > "daos_new_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096        > "daos_new_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_new_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_new_iol_mdtest_1node__posix_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 


mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -z 0 -F -i 5 -v -n 1                        > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_small.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_big.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 1                     > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_small_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 
mpiexec -np $rpn -ppn $rpn -d 13 --cpu-bind=depth  -genvall --no-vni mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "daos_mdtest_1node__dfs_${DAOS_CONT}_${nnodes}_${rpn}_big_S.txt"
rm -rf /tmp/${DAOS_POOL}/${DAOS_CONT}/* 


clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
