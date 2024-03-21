#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=03:30:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q alcf_daos_cn
#PBS -k doe

# qsub -l select=1 -l walltime=03:30:00 -A Aurora_deployment -q alcf_daos_cn -l daos=default ./ior.sh  or - I 

# repeat the experiment with 
# -F	filePerProc – file-per-process - Currently in single shared file 
# -c	collective – collective I/O  - Currently in independent 
# -C	reorderTasksConstant – changes task ordering to n+1 ordering for readback
# -e	fsync – perform fsync upon POSIX write close

# For large 4 million particles use -b 640M -t 16M
# For small 64 particles use -b 100K -t 1K

# From https://ior.readthedocs.io/en/latest/userDoc/options.html 
# Add -d deadlineForStonewalling - seconds before stopping write or read phase.


date
threads=1
echo cat $PBS_NODEFILE
nnodes=$(cat $PBS_NODEFILE | wc -l)
cd $PBS_O_WORKDIR
rm  ./io-small.dat
module use /soft/modulefiles # Needed for ior
module load  oneapi/eng-compiler/2022.12.30.003  #for libimf
export LD_LIBRARY_PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/lib:$LD_LIBRARY_PATH
export PATH=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-ior/bin/:$PATH
binding[8]="list:4:56:5:57:6:58:7:59:8:60:9:61:10:62:11:63:12:64:13:65:14:66:15:67:16:68:17:69:18:70:19:71:20:72:21:73:22:74:23:75:24:76:25:77:26:78:27:79:28:80:29:81:30:82:31:83:32:84:33:85:34:86:35:87:36:88:37:89:38:90:39:91:40:92:41:93:42:94:43:95:44:96:45:97:46:98:47:99:48:100:49:101:50:102:51:103:0:52:1:53:2:54:3:55"
i=8
rpn=$i

 

module use /soft/modulefiles
module load daos/base
module load mpich/51.2/icc-all-pmix-gpu 
module list
env|grep DRPC
export DAOS_POOL=CSC250STDM10_CNDA
export DAOS_CONT=kaus-iorh5bench-dfssmall2-test-$nnodes
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
  

export D_IL_REPORT=1 # Logs for IL
 
# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
mpiexec -np $((rpn*nnodes)) -ppn $rpn    --cpu-bind verbose,${binding[$i]} -genvall --no-vni  ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((1*1024)) -b 100K -t 1K -w -r -C -e -i 5 -v -o /io.dat 

 
# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
mpiexec -np $((rpn*nnodes)) -ppn $rpn    --cpu-bind verbose,${binding[$i]} -genvall --no-vni  ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((1*1024)) -b 100K -t 1K -w -r -c -C -e -i 5 -v -o /io.dat 


 
# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
mpiexec -np $((rpn*nnodes)) -ppn $rpn    --cpu-bind verbose,${binding[$i]} -genvall --no-vni  ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((1*1024)) -b 100K -t 1K -w -r -F -C -e -i 5 -v -o /io.dat 


 
# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
mpiexec -np $((rpn*nnodes)) -ppn $rpn    --cpu-bind verbose,${binding[$i]} -genvall --no-vni  ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((1*1024)) -b 100K -t 1K -w -r -c -F -C -e -i 5 -v -o /io.dat 



clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
 