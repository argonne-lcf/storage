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

cd $PBS_O_WORKDIR
echo Jobid: $PBS_JOBID
echo Running on nodes `cat $PBS_NODEFILE`
NNODES=`wc -l < $PBS_NODEFILE`
RANKS_PER_NODE=16          # Number of MPI ranks per node
NRANKS=$(( NNODES * RANKS_PER_NODE ))
echo "NUM_OF_NODES=${NNODES}  TOTAL_NUM_RANKS=${NRANKS}  RANKS_PER_NODE=${RANKS_PER_NODE}"
CPU_BINDING1=list:4:9:14:19:20:25:30:35:56:61:66:71:72:77:82:87

export HDF5_HOME=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5
export HDF5_DIR=/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5/lib:/usr/lib64/
export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-hdf5/library/install/hdf5/bin
# export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-h5bench-daos-prefix/bin
export PATH=$PATH\:/gecko/CSC250STDM10_CNDA/kaushik/gitrepos/install-h5bench-original/bin

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
FULL_STORAGE_DIR=${PBS_O_WORKDIR}/${TAG}/storage

echo $FULL_STORAGE_DIR

run_h5bench_func(){
    sed -i "s/<NTOTRANKS>/$NTOTRANKS/g" ${TAG}/$1
    sed -i "s/<ENV_EXTRAS>/$ENV_EXTRAS/g" ${TAG}/$1
    sed -i "s|<FULL_STORAGE_DIR>|${FULL_STORAGE_DIR}|g" ${TAG}/$1
    lfs setstripe -S 1M -c 32 $PBS_O_WORKDIR
    h5bench -d ${TAG}/$1
    lfs getstripe .
}

date 
run_h5bench_func "1_large_indep.json" 
run_h5bench_func "2_small_indep.json"
run_h5bench_func "3_large_coll.json"
run_h5bench_func "4_small_coll.json"
date

exit 0
