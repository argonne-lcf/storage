#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=03:30:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q alcf_daos_cn
#PBS -k doe

# qsub -l select=1 -l walltime=03:30:00 -A Aurora_deployment -q alcf_daos_cn -l daos=default ./ior.sh  or - I 

date
threads=1
NRANKS=16
echo cat $PBS_NODEFILE
nnodes=$(cat $PBS_NODEFILE | wc -l)
NTOTRANKS=$(( nnodes * NRANKS ))
cd $PBS_O_WORKDIR 
    
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
