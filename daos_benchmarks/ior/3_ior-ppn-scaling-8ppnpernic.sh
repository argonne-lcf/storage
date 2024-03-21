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

declare -a binding
binding[1]="list:0"
binding[2]="list:0:1"
binding[3]="list:0:1:2"
binding[4]="list:0:1:2:3"
binding[5]="list:0:1:2:3:52"
binding[6]="list:0:1:2:3:52:53"
binding[7]="list:0:1:2:3:52:53:54"
binding[8]="list:0:1:2:3:52:53:54:55"


# With Lustre Posix
echo -e "\n With Lustre Posix \n"
for i in 1 2 3 4 5 6 7 8;
do
	rpn=$i
	lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
	lfs getstripe .
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni ior -a posix -b 1G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
	lfs getstripe ./io.dat
	rm ./io.dat
done

# With Lustre MPIO
echo -e "\n With Lustre MPIO \n"
for i in 1 2 3 4 5 6 7 8;
	do
	rpn=$i
	lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
	lfs getstripe .
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni ior -a mpiio -b 1G -t 1M -w -r -i 5 -v -C -e -o ./io.dat # Note the dot - Lustre
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

# With DAOS Posix Container POSIX  libiol
echo -e "\n With DAOS Posix Container POSIX  \n"
for i in 1 2 3 4 5 6 7 8;
do
	rpn=$i
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni --env LD_PRELOAD=$DAOS_PRELOAD ior -a posix -b 1G -t 1M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
	rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done

export D_IL_REPORT=1 # Logs for IL

# With DAOS Posix Container POSIX  libpil4dfs
echo -e "\n With DAOS Posix Container POSIX  \n"
for i in 1 2 3 4 5 6 7 8;
do
	rpn=$i
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni --env LD_PRELOAD=/usr/lib64/libpil4dfs.so ior -a posix -b 1G -t 1M -w -r -i 5 -v -C -e -o /tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
	rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done


# With DAOS Posix Container MPIO
echo -e "\n With DAOS Posix Container MPIO \n"
for i in 1 2 3 4 5 6 7 8;
do
	rpn=$i
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni  ior -a mpiio -b 1G -t 1M -w -r -i 5 -v -C -e -o daos:/tmp/$DAOS_POOL/$DAOS_CONT/io.dat 
	rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done



# With DAOS Posix Container DFS 
echo -e "\n With DAOS Posix Container DFS \n"

for i in 1 2 3 4 5 6 7 8;
do
	rpn=$i
	mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind ${binding[$i]} -genvall --no-vni  ior -a DFS --dfs.pool=$DAOS_POOL --dfs.cont=$DAOS_CONT --dfs.dir_oclass=S1 --dfs.oclass=SX --dfs.chunk_size=$((128*1024)) -b 1G -t 1M -w -r -i 5 -v -C -e -o /io.dat
	rm /tmp/$DAOS_POOL/$DAOS_CONT/*
done
# try with --dfs.chunk_size=1m

clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
