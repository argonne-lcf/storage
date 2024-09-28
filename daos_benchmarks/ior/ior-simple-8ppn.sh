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

export LD_LIBRARY_PATH=/lus/../daos/ior_mdtest/ior-bin/lib:$LD_LIBRARY_PATH
export PATH=/lus/../daos/ior_mdtest/ior-bin/bin:$PATH



# With Lustre Posix
echo -e "\n With Lustre Posix \n"
lfs getstripe .
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
lfs getstripe ./io.dat
rm ./io.dat

# With Lustre MPIO
echo -e "\n With Lustre MPIO \n"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a mpiio -b 10G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
lfs getstripe ./io.dat
rm ./io.dat
 
# With Lustre Posix
echo -e "\n With Lustre Posix \n"
lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
lfs getstripe .
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
lfs getstripe ./io.dat
rm ./io.dat

# With Lustre MPIO
echo -e "\n With Lustre MPIO \n"
lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
lfs getstripe .
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a mpiio -b 10G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
lfs getstripe ./io.dat
rm ./io.dat


# export D_LOG_MASK=INFO  
# export D_LOG_STDERR_IN_LOG=1
# export D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
# export D_IL_REPORT=1 # Logs for IL

# With DAOS Posix Container POSIX 
echo -e "\n With DAOS Posix Container POSIX  \n"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10G -t 1M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
rm /tmp/$DAOS_POOL/$DAOS_CONT/*

echo -e "\n With DAOS Posix Container POSIX  \n"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10G -t 1M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
rm /tmp/$DAOS_POOL/$DAOS_CONT/*

echo -e "\n With DAOS Posix Container POSIX  \n"
LD_PRELOAD=/usr/lib64/libdaos.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10G -t 1M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
rm /tmp/$DAOS_POOL/$DAOS_CONT/*



# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a mpiio -b 10G -t 1M -w -r -i 5 -v -C -e -o daos:/tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
rm /tmp/$DAOS_POOL/$DAOS_CONT/*
 

# With DAOS Posix Container DFS 
echo -e "\n With DAOS Posix Container DFS \n"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((128*1024)) -b 10G -t 1M -w -r -i 5 -v -C -e -o /io.dat
rm /tmp/$DAOS_POOL/$DAOS_CONT/*
# try with --dfs.chunk_size=1m or --dfs.chunk_size=$((128*1024)) trying default 1mb


clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} 
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
