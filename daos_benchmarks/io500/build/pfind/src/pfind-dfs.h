
void pfind_init_daos(MPI_Comm comm);
void pfind_fini_daos(MPI_Comm comm);
DIR* pfind_dfs_opendir(const char* dir, int *nr);
int pfind_dfs_closedir(DIR* _dirp);
struct dirent* pfind_dfs_readdir(DIR* _dirp);
int pfind_dfs_lstat(const char* path, struct stat* buf);
