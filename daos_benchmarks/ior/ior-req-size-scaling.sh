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
DAOS_CONT=ior_1
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

export LD_LIBRARY_PATH=/lus/../daos/ior_mdtest/ior-bin/lib:$LD_LIBRARY_PATH
export PATH=/lus/../daos/ior_mdtest/ior-bin/bin:$PATH

cd $PBS_O_WORKDIR
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=16          # Number of MPI ranks per node
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:30:35:56:61:66:71:72:77:82:87


declare -a bsz
bsz[4]=2
bsz[32]=10
bsz[64]=15
bsz[128]=50
bsz[256]=50
bsz[512]=50
bsz[1024]=50
bsz[2048]=50
bsz[4096]=50 

 
# With Lustre Posix
echo -e "\n With Lustre Posix \n"
lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
lfs getstripe .
for i in 4 32 64 128 256 512 1024 2048 4096;
do
    mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b ${bsz[$i]}G -t ${i}k  -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
    lfs getstripe ./io.dat
    rm ./io.dat
done 

# With DAOS Posix Container POSIX 
echo -e "\n With DAOS Posix Container POSIX  \n"
for i in 4 32 64 128 256 512 1024 2048 4096;
    LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  ior -a posix -b ${bsz[$i]}G -t ${i}k -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done 

# With DAOS Posix Container MPIO
for i in 4 32 64 128 256 512 1024 2048 4096;
do
    echo -e "\n With DAOS Posix Container MPIO \n"
    LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a mpiio -b ${bsz[$i]}G -t ${i}k -w -r -i 5 -v -C -e -o daos:/tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done


# With DAOS Posix Container DFS 
echo -e "\n With DAOS Posix Container DFS \n"
for i in 4 32 64 128 256 512 1024 2048 4096;
    mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((128*1024)) -b ${bsz[$i]}G -t ${i}k -w -r -i 5 -v -C -e -o /io.dat
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done 


clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date
exit 0
