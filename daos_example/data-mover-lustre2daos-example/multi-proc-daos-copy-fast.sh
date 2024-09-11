#!/bin/bash -x
#PBS -l select=1
#PBS -l walltime=01:00:00
#PBS -l daos=default
#PBS -A Aurora_deployment
#PBS -q lustre_scaling
#PBS -k doe
# qsub -l select=1 -l walltime=01:00:00 -A Aurora_deployment -q lustre_scaling -l daos=default ./multi-proc-daos-copy-fast.sh  or - I 

rpn=1
threads=1
nnodes=$(cat $PBS_NODEFILE | wc -l)

export DAOS_POOL=datascience
export DAOS_CONT=datascience-softwares

module use /soft/modulefiles
module load daos/base
env|grep DRPC
module list
clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
launch-dfuse.sh ${DAOS_POOL}:${DAOS_CONT}
mount|grep dfuse
cd $PBS_O_WORKDIR

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/soft/daos/tools/install-20230818-mpich-drop52.2/mpifileutils/lib
export PATH=$PATH:/soft/daos/mpifileutils/bin

source_posix_dir=/lus/flare/project/ai-ml/resnet-dataset/
dest_daos_dir=mycopy
mkdir -p /tmp/$DAOS_POOL/$DAOS_CONT/$dest_daos_dir

daos pool query $DAOS_POOL # before size
rpn=16
mpiexec -np $((rpn*nnodes)) -ppn $rpn -d 13 --cpu-bind=depth -genvall --no-vni /soft/daos/mpifileutils/bin/dcp -G -U --bufsize 64MB --chunksize 128MB $source_posix_dir daos://$DAOS_POOL/$DAOS_CONT/$dest_daos_dir

daos pool query $DAOS_POOL # after size
 
clean-dfuse.sh ${DAOS_POOL}:${DAOS_CONT} # cleanup dfuse mounts
