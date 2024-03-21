#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=05:30:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q alcf_daos_cn
#PBS -k doe

# qsub -l select=1 -l walltime=05:30:00 -A Aurora_deployment -q alcf_daos_cn -l daos=default ./ior.sh  or - I 

# repeat the experiment with 
# -F	filePerProc – file-per-process - Currently in single shared file 
# -c	collective – collective I/O  - Currently in independent 
# -C	reorderTasksConstant – changes task ordering to n+1 ordering for readback
# -e	fsync – perform fsync upon POSIX write close

# From https://ior.readthedocs.io/en/latest/userDoc/options.html 
# Add -d deadlineForStonewalling - seconds before stopping write or read phase.


date
threads=1
echo cat $PBS_NODEFILE
nnodes=$(cat $PBS_NODEFILE | wc -l)
cd $PBS_O_WORKDIR
rm ./io.dat
module use /soft/modulefiles # Needed for ior
module load  oneapi/eng-compiler/2022.12.30.003  #for libimf
export LD_LIBRARY_PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/lib:$LD_LIBRARY_PATH
export PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/bin/:$PATH

binding="list:4:56:5:57:6:58:7:59:8:60:9:61:10:62:11:63:12:64:13:65:14:66:15:67:16:68:17:69:18:70:19:71:20:72:21:73:22:74:23:75:24:76:25:77:26:78:27:79:28:80:29:81:30:82:31:83:32:84:33:85:34:86:35:87:36:88:37:89:38:90:39:91:40:92:41:93:42:94:43:95:44:96:45:97:46:98:47:99:48:100:49:101:50:102:51:103:0:52:1:53:2:54:3:55"

for rpn in 1 2 4 8 16 32 52 78 104; 
do

    # With Lustre Posix with default stripe settings
    echo -e "\n With Lustre Posix \n"
    lfs getstripe .
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding}    -envall --no-vni ior -a posix -b 2G -t 16M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
    lfs getstripe ./io.dat
    rm ./io.dat
done

for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With Lustre Posix with perfect stripe settings
    echo -e "\n With Lustre Posix \n"
    lfs setstripe -S 16M -c 32 $PBS_O_WORKDIR
    lfs getstripe .
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding}    -envall --no-vni ior -a posix -b 2G -t 16M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
    lfs getstripe ./io.dat
    rm ./io.dat
done

for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With Lustre MPIO  with default stripe settings
    echo -e "\n With Lustre MPIO \n"
    lfs getstripe .
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding}    -envall --no-vni ior -a mpiio -b 2G -t 16M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
    lfs getstripe ./io.dat
    rm ./io.dat
done


for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With Lustre MPIO with perfect stripe settings
    echo -e "\n With Lustre MPIO \n"
    lfs setstripe -S 16M -c 32 $PBS_O_WORKDIR
    lfs getstripe .
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding}    -envall --no-vni ior -a mpiio -b 2G -t 16M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
    lfs getstripe ./io.dat
    rm ./io.dat
done




module use /soft/modulefiles
module load daos/base
module load mpich/51.2/icc-all-pmix-gpu 
module list
env|grep DRPC
export DAOS_POOL=datascience
export DAOS_CONT=kaus-ior-test3-$nnodes
daos container create --type POSIX --dir-oclass=S1 --file-oclass=SX ${DAOS_POOL} ${DAOS_CONT}
daos container get-prop ${DAOS_POOL} ${DAOS_CONT}
daos cont      query  ${DAOS_POOL} ${DAOS_CONT}
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse


# export D_LOG_MASK=INFO  
# export D_LOG_STDERR_IN_LOG=1
# export D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
# export D_IL_REPORT=1 # Logs for IL
# LD_PRELOAD=$DAOS_PRELOAD mpiexec 

for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With DAOS Posix Container POSIX without any IL
    echo -e "\n With DAOS Posix Container POSIX  \n"
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding} -genvall --no-vni ior -a posix -b 2G -t 16M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done


export D_IL_REPORT=1 # Logs for IL
for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With DAOS Posix Container POSIX with libiol
    echo -e "\n With DAOS Posix Container POSIX  \n"
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding} -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD ior -a posix -b 2G -t 16M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done


for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With DAOS Posix Container POSIX with libpil4dfs
    echo -e "\n With DAOS Posix Container POSIX  \n"
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding} -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so ior -a posix -b 2G -t 16M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done

for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With DAOS Posix Container MPIO
    echo -e "\n With DAOS Posix Container MPIO \n"
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding} -genvall --no-vni ior -a mpiio -b 2G -t 16M -w -r -i 5 -v -C -e -o daos:/tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done

for rpn in 1 2 4 8 16 32 52 78 104; 
do
    # With DAOS Posix Container DFS 
    echo -e "\n With DAOS Posix Container DFS \n"
    mpiexec -np $((rpn*nnodes)) -ppn $rpn --cpu-bind verbose,${binding} -genvall --no-vni ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((128*1024)) -b 2G -t 16M -w -r -i 5 -v -C -e -o /io.dat
    rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done 


clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
