#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=03:30:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q alcf_daos_cn
#PBS -k doe

# qsub -l select=1 -l walltime=03:30:00 -A Aurora_deployment -q alcf_daos_cn -l daos=default ./ior.sh  or - I 
export TZ='/usr/share/zoneinfo/US/Central'

date
threads=1
NRANKS=16
echo cat $PBS_NODEFILE
nnodes=$(cat $PBS_NODEFILE | wc -l)
NTOTRANKS=$(( nnodes * NRANKS ))
cd $PBS_O_WORKDIR 

module use /soft/modulefiles
module load daos/base
module load mpich/51.2/icc-all-pmix-gpu 
module list
env|grep DRPC
export DAOS_POOL=CSC250STDM10_CNDA
export DAOS_CONT=kaus-h5bench-mpiio-adio-daos-$nnodes
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
daos container create --type POSIX --dir-oclass=S1 --file-oclass=SX ${DAOS_POOL} ${DAOS_CONT}
daos container get-prop ${DAOS_POOL} ${DAOS_CONT}
daos cont      query  ${DAOS_POOL} ${DAOS_CONT}
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
WCOLL=${PBS_NODEFILE} pdsh 'mount|grep dfuse'
mount | grep daos
export TZ='/usr/share/zoneinfo/US/Central'

# export D_LOG_MASK=INFO  
# export D_LOG_STDERR_IN_LOG=1
# export D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
# export D_IL_REPORT=1 # Logs for IL
# LD_PRELOAD=$DAOS_PRELOAD mpiexec 

export HDF5_HOME=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5
export HDF5_DIR=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5/lib:/usr/lib64/
export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5/bin
export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-h5bench-daos-prefix/bin # always use this for mpio-adio
# export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-h5bench-original/bin # always use this for vol
export D_IL_REPORT=1 # Logs for IL
unset HDF5_PLUGIN_PATH
unset HDF5_VOL_CONNECTOR 

TAG=`date +"%Y-%m-%d-%H-%M-%S"$PBS_JOBID`
echo $TAG
mkdir -p ${TAG}
config_path=/gecko/CSC250STDM10_CNDA/kaushik/daos-workspace/experiments/4_h5bench/h5bench-configs/full/
cp -r $config_path/* ${TAG}/



export ROMIO_PRINT_HINTS=1
echo "cb_config_list *:4" >> romio_hints
echo "romio_cb_read enable" >> romio_hints
echo "romio_cb_write enable" >> romio_hints
echo "cb_nodes 4" >> romio_hints
export ROMIO_HINTS=./romio_hints 
 

ENV_EXTRAS=" --env ROMIO\_HINTS=${PBS_O_WORKDIR}\/romio\_hints  "
# FULL_STORAGE_DIR=storage
FULL_STORAGE_DIR="/tmp/"$DAOS_POOL"/"$DAOS_CONT"/storage" # always use this for mpio-adio - do not add extra daos:/ # always use this for DAOS VOL - do not add extra daos:/  I used daos:/ from install-h5bench-daos-prefix
echo $FULL_STORAGE_DIR

run_h5bench_func(){

sed -i "s/<NTOTRANKS>/$NTOTRANKS/g" ${TAG}/$1
sed -i "s/<ENV_EXTRAS>/$ENV_EXTRAS/g" ${TAG}/$1
sed -i "s|<FULL_STORAGE_DIR>|${FULL_STORAGE_DIR}|g" ${TAG}/$1


h5bench -d ${TAG}/$1
rsync -av '--exclude=*.h5' '--exclude=core*' /tmp/${DAOS_POOL}/${DAOS_CONT}/*  ${TAG}/
rm /tmp/$DAOS_POOL/$DAOS_CONT/*
}

date 

run_h5bench_func "1_large_indep.json" 
run_h5bench_func "2_small_indep.json"
run_h5bench_func "3_large_coll.json"
run_h5bench_func "4_small_coll.json"

date

clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
daos container destroy  ${DAOS_POOL} ${DAOS_CONT} 
date

exit 0
