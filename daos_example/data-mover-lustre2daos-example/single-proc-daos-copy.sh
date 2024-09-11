#!/bin/bash -x

source_posix_dir=
dest_daos_dir=
daos filesystem copy --src $source_posix_dir --dst  daos://$DAOS_POOL/$DAOS_CONT/$dest_daos_dir

daos filesystem copy --src /soft/datascience/aurora_nre_models_frameworks-2024.0/__pycache__/ --dst daos://0477964f-3d74-4053-ba42-ac0c0f9feb95/c9732308-758e-42a8-9316-cf4ec875f494/test3/
daos filesystem copy --ignore-unsupported --src /soft/datascience/aurora_nre_models_frameworks-2024.0/__pycache__/ --dst daos://0477964f-3d74-4053-ba42-ac0c0f9feb95/c9732308-758e-42a8-9316-cf4ec875f494/test3/

daos filesystem copy --src /soft/datascience/aurora_nre_models_frameworks-2024.0/__pycache__/ --dst daos://0477964f-3d74-4053-ba42-ac0c0f9feb95/c9732308-758e-42a8-9316-cf4ec875f494/test3/ --ignore-unsupported 
daos filesystem --ignore-unsupported copy --src /soft/datascience/aurora_nre_models_frameworks-2024.0/__pycache__/ --dst daos://0477964f-3d74-4053-ba42-ac0c0f9feb95/c9732308-758e-42a8-9316-cf4ec875f494/test3/