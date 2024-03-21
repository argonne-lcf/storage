# DAOS storage benchmarks 

Disable cachine during launch dfuse --disable-caching and --disable-wb-cache. 

Disable caching in ior -C -e


## Major parameters that influence the DAOS FS I/O performance

1. CPU NIC binding https://docs.alcf.anl.gov/aurora/running-jobs-aurora/#binding-mpi-ranks-and-threads-to-cores 
2. Payload -t and -b size
3. Enough cpu ranks to drive data to nic. How many I/O threads are driving the I/O. 
4. stone wall time - need to run atleast 60 seconds
5. variability - running many iterations at different days


## Different ways of binding has a huge impact on the I/O performance

0. example

    Run 32 copies of <application> with 8 processes per node, binding each process to 4 CPUs. This is useful when running applications where each rank spawns multiple threads.
    mpiexec -n 32 --ppn 8 -d 4 --cpu-bind depth <application>

    Run 4 copies of <application> with 2 processes per node, binding the first rank on each node to CPUs 0 and 32, and the second rank on each node to CPUs 1 and 33.
    mpiexec -n 4 --ppn 2 --cpu-bind list:0,32:1,33 <application>


1. Simple 

    rpn=8
    threads=1
    mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind list:0:1:2:3:52:53:54:55


2. For rpn scaling from 1,2,4,8,..104 with binding 2 cpus per process

    mpiexec -np $((rpn*nnodes)) -ppn $rpn -d 2 -cc depth 


3. For a specific rpn=16, trying to use all CPUs in the node 16 X 13 = 208 

    mpiexec -np $((rpn*nnodes)) -ppn $rpn -d 13 --cpu-bind=depth 


4. starting with CPU 4, giving the OS the first four ( 104 ppn )

    threads=1
    mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind list:4:56:5:57:6:58:7:59:8:60:9:61:10:62:11:63:12:64:13:65:14:66:15:67:16:68:17:69:18:70:19:71:20:72:21:73:22:74:23:75:24:76:25:77:26:78:27:79:28:80:29:81:30:82:31:83:32:84:33:85:34:86:35:87:36:88:37:89:38:90:39:91:40:92:41:93:42:94:43:95:44:96:45:97:46:98:47:99:48:100:49:101:50:102:51:103:0:52:1:53:2:54:3:55"


5. To use hypethreads (208 ppn)

    threads=1
    mpiexec -np $((rpn*nnodes)) -ppn $rpn -d $threads --cpu-bind 0:52:104:156:1:53:105:157:2:54:106:158:3:55:107:159:4:56:108:160:5:57:109:161:6:58:110:162:7:59:111:163:8:60:112:164:9:61:113:165:10:62:114:166:11:63:115:167:12:64:116:168:13:65:117:169:14:66:118:170:15:67:119:171:16:68:120:172:17:69:121:173:18:70:122:174:19:71:123:175:20:72:124:176:21:73:125:177:22:74:126:178:23:75:127:179:24:76:128:180:25:77:129:181:26:78:130:182:27:79:131:183:28:80:132:184:29:81:133:185:30:82:134:186:31:83:135:187:32:84:136:188:33:85:137:189:34:86:138:190:35:87:139:191:36:88:140:192:37:89:141:193:38:90:142:194:39:91:143:195:40:92:144:196:41:93:145:197:42:94:146:198:43:95:147:199:44:96:148:200:45:97:149:201:46:98:150:202:47:99:151:203:48:100:152:204:49:101:153:205:50:102:154:206:51:103:155:207


## Notes when running ior

rerun your ppn scaling test of ranks per node and make sure your ior iteration runs for at least 60 seconds then replot
you can use a very high block size and add a stone wall of 60 seconds

From https://ior.readthedocs.io/en/latest/userDoc/options.html 
Add -d 
deadlineForStonewalling - seconds before stopping write or read phase. Used for measuring the amount of data moved in a fixed time. After the barrier, each task starts its own timer, begins moving data, and the stops moving data at a pre-arranged time. Instead of measuring the amount of time to move a fixed amount of data, this option measures the amount of data moved in a fixed amount of time. The objective is to prevent straggling tasks slow from skewing the performance. This option is incompatible with read-check and write-check modes. Value of zero unsets this option. (default: 0)



## libpil4dfs IL improves the metadata performance only for posix interface. 

Pass the interception library as ld preloads or --env after mpiexec
    LD_PRELOAD=$DAOS_PRELOAD mpiexec 
    --env LD_PRELOAD=/usr/lib64/libpil4dfs.so 

pil4dfs is interception for all libc calls, not just read/write for ioil
for pil4dfs the initial connection time happen on file open which is not necessarily included in the bw.
for ioil it's on the first write, so that's why you see that effect


## Large scale runs may need

    mpiexec 
    --env FI_CXI_DEFAULT_CQ_SIZE=16384  
    --env FI_CXI_OVFLOW_BUF_SIZE=8388608 
    --env FI_CXI_CQ_FILL_PERCENT=20 

    --env  MPIR_CVAR_BCAST_POSIX_INTRA_ALGORITHM=mpir
    --env  MPIR_CVAR_ALLREDUCE_POSIX_INTRA_ALGORITHM=mpir
    --env  MPIR_CVAR_BARRIER_POSIX_INTRA_ALGORITHM=mpir
    --env  MPIR_CVAR_REDUCE_POSIX_INTRA_ALGORITHM=mpir

    -np $((rpn*nnodes))


## For logs

    --env D_LOG_MASK=INFO  
    --env D_LOG_STDERR_IN_LOG=1
    --env D_LOG_FILE="$PBS_O_WORKDIR/ior-p.log" 
    --env D_IL_REPORT=1 # Logs for IL

## To create different container types

    daos container create --type POSIX --dir-oclass=S1 --file-oclass=S1 		${DAOS_POOL} ${DAOS_CONT}
    daos container create --type POSIX --dir-oclass=S1 --file-oclass=S16 		${DAOS_POOL} ${DAOS_CONT}
    daos container create --type POSIX --dir-oclass=S1 --file-oclass=EC_16P2GX 	${DAOS_POOL} ${DAOS_CONT}
    daos container create --type POSIX --dir-oclass=S1 --file-oclass=SX 		${DAOS_POOL} ${DAOS_CONT}

## For DFS runs 

DFS chunk settings
    
    Try with --dfs.chunk_size=1m or --dfs.chunk_size=$((128*1024)) currently using default 1mb

HDF5 chunk settings
    
    H5Pset_chunk (hid_t plist_id, int ndims, const hsize_t dim[]) 
