#!/bin/bash -x
#PBS -l select=20
#PBS -l walltime=01:00:00
#PBS -A datascience
#PBS -q prod
#PBS -k doe
#PBS -ldaos=daos_user

# qsub -l select=1:ncpus=208 -l walltime=01:00:00 -A datascience -l filesystems=home:flare:daos_user -ldaos=daos_user -q debug  ./pbs_script.sh or - I 
# qsub -l select=1:ncpus=208:tier0=x4519+1:ncpus=208:tier0=x4601 -l walltime=00:05:00 -A datascience -l filesystems=home:flare:daos_user  -ldaos=daos_user -q debug-scaling -I
# To get free nodes  #  pbsnodes -avSj |  awk '{ if ($2 = "free" ) print $1 "\t" $2 }'

export TZ='/usr/share/zoneinfo/US/Central'
date
module use /soft/modulefiles
module load daos
# env | grep DRPC                                     #optional
# ps -ef|grep daos                                    #optional
# clush --hostfile ${PBS_NODEFILE}  'ps -ef|grep agent|grep -v grep'  | dshbak -c  #optional
DAOS_POOL=datascience
DAOS_CONT=ior_5
# daos pool query ${DAOS_POOL}                        #optional
# daos cont list ${DAOS_POOL}                         #optional
# daos container destroy   ${DAOS_POOL}  ${DAOS_CONT} #optional
daos container create --type POSIX ${DAOS_POOL}  ${DAOS_CONT} --properties rd_fac:1 #  --file-oclass=RP_3G1 --properties=cksum:crc32,srv_cksum:on,rd_fac:2,ec_cell_sz:131072
# daos container create --type POSIX ${DAOS_POOL}  ${DAOS_CONT}  --file-oclass=S1 --properties rd_fac:0 # for metadata and small io/file size say 10k

# daos container query     ${DAOS_POOL}  ${DAOS_CONT} #optional
# daos container get-prop  ${DAOS_POOL}  ${DAOS_CONT} #optional
# daos container list      ${DAOS_POOL}  #optional
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse                                    #optional
ls /tmp/${DAOS_POOL}/${DAOS_CONT}                   #optional

export LD_LIBRARY_PATH=/lus/flare/projects/Aurora_deployment/kaushik/0_sc25_daos/ior_md_test_src/ior_mdtest_install_bin/lib:$LD_LIBRARY_PATH
export PATH=/lus/flare/projects/Aurora_deployment/kaushik/0_sc25_daos/ior_md_test_src/ior_mdtest_install_bin/bin:$PATH

cd $PBS_O_WORKDIR
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=16          # Number of MPI ranks per node
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:30:35:56:61:66:71:72:77:82:87

#readme for IOR
# -F	file-per-process        - No -F is single shared file [This is an I/O Access parameter] 
# -c	collective I/O            [I/O type parameter] with -a mpiio and add daos:/tmp/$DAOS_POOL/$DAOS_CONT/io.dat in -o
# No -c independent I/O           [I/O type parameter] with -a posix and just /tmp/$DAOS_POOL/$DAOS_CONT/io.dat in -o
# -C	reorderTasksConstant    – changes task ordering to n+1 ordering for readback
# -e	fsync                   – perform fsync upon POSIX write close
# -D N	deadlineForStonewalling – seconds before stopping write or read phase
# -b N	blockSize               – contiguous bytes to write per task (e.g.: 8, 4k, 2m, 1g)
# -t N	transferSize            – size of transfer in bytes (e.g.: 8, 4k, 2m, 1g)
# -i N	repetitions             – number of repetitions of test


# For lustre
# lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
# lfs getstripe . # add -k keep file to ior
# lfs getstripe ./io.dat

# DAOS IOR Tests

echo -e "\n With DAOS Posix Container Fuse and interception library  \n"
for i in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 ;
    LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a posix -b 10g -t 1k -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat > ior_10g_${i}k_posix_pil4dfs.txt
done 

echo -e "\n With DAOS Posix Container DFS without Fuse and without interception library  \n"
for i in 1 2 4 8 16 32 64 128 256 512 1024 2048 4096 8192 16384 32768 65536 131072 262144 524288 1048576 ;
    mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((128*1024)) -b 10G -t ${i}k -w -r -i 5 -v -C -e -o /io.dat
done 

# check echo $DAOS_PRELOAD is /usr/lib64/libdaos.so by default - check echo $LD_PRELOAD


#readme for mdtest 
# -z  tree_depth - The depth of the hierarchical directory tree [default: 0].
# -F Perform test on files only (no directories).
# -i iterations : The number of iterations the test will run [default: 1].
# -v Increase verbosity (each instance of option increments by one).
# -n number_of_items Every process will creat/stat/remove num directories and files [default: 0].
# -S Shared file access (file only, no directories).
# -F Perform test on files only (no directories).
# -e bytes : Set the number of Bytes to read from each file [default: 0].
# -w bytes : Set the number of Bytes to write to each file after it is created [default: 0].
# -W N   "number in seconds; stonewall timer, write as many seconds and ensure all processes did the same number of operations (currently only stops during create phase and files



#Lustre

mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX    -z 0 -F -i 5 -v -n 1                     > "lustre_mdtest_posix_${NNODES}_${NRANKS}_small.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX    -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "lustre_mdtest_posix_${NNODES}_${NRANKS}_big.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 1                     > "lustre_mdtest_posix_${NNODES}_${NRANKS}_small_S.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall   mdtest -d $PBS_O_WORKDIR/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "lustre_mdtest_posix_${NNODES}_${NRANKS}_big_S.txt"

# DAOS Mode 1 : Fuse No interception library

mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 1                        > "daos_no_il_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_no_il_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_no_il_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small_S.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_no_il_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big_S.txt"

# DAOS Mode 2 : Fuse Libioil interception library

LD_PRELOAD=/usr/lib64/libioil.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 1                        > "daos_old_iol_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small.txt"
LD_PRELOAD=/usr/lib64/libioil.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_old_iol_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big.txt"
LD_PRELOAD=/usr/lib64/libioil.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_old_iol_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small_S.txt"
LD_PRELOAD=/usr/lib64/libioil.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_old_iol_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big_S.txt"

# DAOS Mode 3 : Fuse Libpil4dfs interception library

LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 1                        > "daos_new_pil4dfs_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX    -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_new_pil4dfs_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 1                        > "daos_new_pil4dfs_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_small_S.txt"
LD_PRELOAD=/usr/lib64/libpil4dfs.so mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d /tmp/${DAOS_POOL}/${DAOS_CONT}/ -a POSIX -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096     > "daos_new_pil4dfs_mdtest_posix_${DAOS_CONT}_${NNODES}_${NRANKS}_big_S.txt"

# DAOS Mode 4 : Non Fuse - DFS API library

mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m     -z 0 -F -i 5 -v -n 1                     > "daos_mdtest__dfs_${DAOS_CONT}_${NNODES}_${NRANKS}_small.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m     -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "daos_mdtest__dfs_${DAOS_CONT}_${NNODES}_${NRANKS}_big.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 1                     > "daos_mdtest__dfs_${DAOS_CONT}_${NNODES}_${NRANKS}_small_S.txt"
mpiexec -np ${NRANKS} -ppn ${RANKS_PER_NODE} --cpu-bind ${CPU_BINDING1} --no-vni -genvall  mdtest -d / -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT  --dfs.dir_oclass=S1  --dfs.oclass=S1 --dfs.chunk_size=1m  -S -z 0 -F -i 5 -v -n 3334 -e 4096 -w 4096  > "daos_mdtest__dfs_${DAOS_CONT}_${NNODES}_${NRANKS}_big_S.txt"

date

# # export D_LOG_MASK=INFO  
# # export D_LOG_STDERR_IN_LOG=1
# # export D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
# # export D_IL_REPORT=1 # Logs for IL

clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
