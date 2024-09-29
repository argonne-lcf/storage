#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <limits.h>
#include <sys/stat.h>
#include <mpi.h>
#include <fcntl.h>
#include <unistd.h>
#include <assert.h>
#include <sys/time.h>
#include <libgen.h>

#include <gurt/common.h>
#include <gurt/hash.h>
#include <daos.h>
#include <daos_fs.h>

#include "pfind-dfs.h"

/* For DAOS methods. */
#define DCHECK(rc, format, ...)                                         \
do {                                                                    \
        int _rc = (rc);                                                 \
                                                                        \
        if (_rc != 0) {                                                  \
                fprintf(stderr, "ERROR (%s:%d): %d: %d: "               \
                        format"\n", __FILE__, __LINE__, pfind_rank, _rc, \
                        ##__VA_ARGS__);                                 \
                fflush(stderr);                                         \
                exit(-1);                                       	\
        }                                                               \
} while (0)

enum handleType {
        POOL_HANDLE,
        CONT_HANDLE,
	DFS_HANDLE
};

static daos_handle_t poh;
static daos_handle_t coh;
static dfs_t *pfind_dfs;
static struct d_hash_table *dir_hash;
extern int pfind_rank;

struct pfind_dir_hdl {
        d_list_t	entry;
        dfs_obj_t	*oh;
        char		name[PATH_MAX];
};

#define NUM_DIRENTS 112
struct dfs_pfind_t {
	dfs_obj_t *dir;
	uint32_t num_ents;
	uint32_t num_splits;
	struct dirent ents[NUM_DIRENTS];
	daos_anchor_t anchor;
};

static inline struct pfind_dir_hdl *
hdl_obj(d_list_t *rlink)
{
        return container_of(rlink, struct pfind_dir_hdl, entry);
}

static bool
key_cmp(__attribute__((unused)) struct d_hash_table *htable, d_list_t *rlink, const void *key,
	__attribute__((unused)) unsigned int ksize)
{
        struct pfind_dir_hdl *hdl = hdl_obj(rlink);

        return (strcmp(hdl->name, (const char *)key) == 0);
}

static void
rec_free(__attribute__((unused)) struct d_hash_table *htable, d_list_t *rlink)
{
        struct pfind_dir_hdl *hdl = hdl_obj(rlink);

        dfs_release(hdl->oh);
        free(hdl);
}

static bool
rec_decref(__attribute__((unused)) struct d_hash_table *htable, __attribute__((unused)) d_list_t *rlink)
{
        return true;
}

static uint32_t
rec_hash(__attribute__((unused)) struct d_hash_table *htable, d_list_t *rlink)
{
	struct pfind_dir_hdl *hdl = hdl_obj(rlink);

        return d_hash_string_u32(hdl->name, strlen(hdl->name));
}

static d_hash_table_ops_t hdl_hash_ops = {
        .hop_key_cmp	= key_cmp,
	.hop_rec_decref	= rec_decref,
	.hop_rec_free	= rec_free,
	.hop_rec_hash	= rec_hash
};

/* Distribute process 0's pool or container handle to others. */
static void
HandleDistribute(MPI_Comm comm, enum handleType type)
{
        d_iov_t global;
        int        rc;

        global.iov_buf = NULL;
        global.iov_buf_len = 0;
        global.iov_len = 0;

        assert(type == POOL_HANDLE || type == CONT_HANDLE || type == DFS_HANDLE);
        if (pfind_rank == 0) {
                /* Get the global handle size. */
                if (type == POOL_HANDLE)
                        rc = daos_pool_local2global(poh, &global);
                else if (type == CONT_HANDLE)
                        rc = daos_cont_local2global(coh, &global);
                else
                        rc = dfs_local2global(pfind_dfs, &global);
                DCHECK(rc, "Failed to get global handle size");
        }

        MPI_Bcast(&global.iov_buf_len, 1, MPI_UINT64_T, 0, comm);

	global.iov_len = global.iov_buf_len;
        global.iov_buf = malloc(global.iov_buf_len);
        if (global.iov_buf == NULL)
		MPI_Abort(comm, -1);

        if (pfind_rank == 0) {
                if (type == POOL_HANDLE)
                        rc = daos_pool_local2global(poh, &global);
                else if (type == CONT_HANDLE)
                        rc = daos_cont_local2global(coh, &global);
                else
                        rc = dfs_local2global(pfind_dfs, &global);
                DCHECK(rc, "Failed to create global handle");
        }

        MPI_Bcast(global.iov_buf, global.iov_buf_len, MPI_BYTE, 0, comm);

        if (pfind_rank != 0) {
                if (type == POOL_HANDLE)
                        rc = daos_pool_global2local(global, &poh);
                else if (type == CONT_HANDLE)
                        rc = daos_cont_global2local(poh, global, &coh);
                else
                        rc = dfs_global2local(poh, coh, 0, global, &pfind_dfs);
                DCHECK(rc, "Failed to get local handle");
        }

        free(global.iov_buf);
}

static int
parse_filename(const char *path, char **_obj_name, char **_cont_name)
{
	char *f1 = NULL;
	char *f2 = NULL;
	char *fname = NULL;
	char *cont_name = NULL;
	int rc = 0;

	if (path == NULL || _obj_name == NULL || _cont_name == NULL)
		return -EINVAL;

	f1 = strdup(path);
	if (f1 == NULL) {
                rc = -ENOMEM;
                goto out;
        }

	f2 = strdup(path);
	if (f2 == NULL) {
                rc = -ENOMEM;
                goto out;
        }

	fname = basename(f1);
	cont_name = dirname(f2);

        if (cont_name[0] != '/') {
                char *ptr;
                char buf[PATH_MAX];

                ptr = realpath(cont_name, buf);
                if (ptr == NULL) {
                        rc = errno;
                        goto out;
                }

                cont_name = strdup(ptr);
                if (cont_name == NULL) {
                        rc = ENOMEM;
                        goto out;
                }
                *_cont_name = cont_name;
        } else {
                *_cont_name = strdup(cont_name);
                if (*_cont_name == NULL) {
                        rc = ENOMEM;
                        goto out;
                }
        }

        *_obj_name = strdup(fname);
        if (*_obj_name == NULL) {
                rc = ENOMEM;
                goto out;
        }

out:
	if (f1)
		free(f1);
	if (f2)
		free(f2);
	return rc;
}

#if 0
static int
share_file_handle(dfs_obj_t **file, MPI_Comm comm)
{
        d_iov_t global;
        int        rc;

        global.iov_buf = NULL;
        global.iov_buf_len = 0;
        global.iov_len = 0;

        if (pfind_rank == 0) {
                rc = dfs_obj_local2global(pfind_dfs, *file, &global);
                DCHECK(rc, "Failed to get global handle size");
        }

        MPI_Bcast(&global.iov_buf_len, 1, MPI_UINT64_T, 0, comm);

	global.iov_len = global.iov_buf_len;
        global.iov_buf = malloc(global.iov_buf_len);
        if (global.iov_buf == NULL) {
                fprintf(stderr, "Failed to allocate global handle buffer\n");
		exit(-1);
	}

        if (pfind_rank == 0) {
                rc = dfs_obj_local2global(pfind_dfs, *file, &global);
                DCHECK(rc, "Failed to create global handle");
        }

        MPI_Bcast(global.iov_buf, global.iov_buf_len, MPI_BYTE, 0, comm);

        if (pfind_rank != 0) {
                rc = dfs_obj_global2local(pfind_dfs, 0, global, file);
                DCHECK(rc, "Failed to get local handle");
        }

        if (global.iov_buf)
                free(global.iov_buf);
        return rc;
}
#endif

static dfs_obj_t *
lookup_insert_dir(const char *name, mode_t *mode)
{
        struct pfind_dir_hdl *hdl;
        dfs_obj_t *oh;
        d_list_t *rlink;
        size_t len = strlen(name);
        int rc;

        rlink = d_hash_rec_find(dir_hash, name, len);
        if (rlink != NULL) {
                hdl = hdl_obj(rlink);
                return hdl->oh;
        }

        rc = dfs_lookup(pfind_dfs, name, O_RDWR, &oh, mode, NULL);
        if (rc)
                return NULL;

        if (mode && !S_ISDIR(*mode))
                return oh;

        hdl = calloc(1, sizeof(struct pfind_dir_hdl));
        if (hdl == NULL)
                return NULL;

        strcpy(hdl->name, name);
        hdl->oh = oh;

        rc = d_hash_rec_insert(dir_hash, hdl->name, len, &hdl->entry, false);
        if (rc) {
                fprintf(stderr, "Failed to insert dir handle in hashtable\n");
                dfs_release(hdl->oh);
                free(hdl);
                return NULL;
        }

        return hdl->oh;
}

void
pfind_init_daos(MPI_Comm comm) {
	int rc;

	char *pool_str = getenv("DAOS_POOL");
	if (pool_str == NULL) {
		printf("DAOS_POOL env variable is not set\n");
		MPI_Abort(comm, -1);
	}

	char *cont_str = getenv("DAOS_CONT");
	if (cont_str == NULL) {
		printf("DAOS_CONT env variable is not set\n");
		MPI_Abort(comm, -1);
	}

	rc = daos_init();
	DCHECK(rc, "Failed to initialize daos");

	if (pfind_rank == 0) {
		daos_pool_info_t pool_info;
		daos_cont_info_t co_info;

		rc = daos_pool_connect(pool_str, NULL, DAOS_PC_RW, &poh, &pool_info, NULL);
		DCHECK(rc, "Failed to connect to pool");

		rc = daos_cont_open(poh, cont_str, DAOS_COO_RW, &coh, &co_info, NULL);
		DCHECK(rc, "Failed to open container");

		rc = dfs_mount(poh, coh, O_RDWR, &pfind_dfs);
		DCHECK(rc, "Failed to mount DFS namespace");
	}

	HandleDistribute(comm, POOL_HANDLE);
	HandleDistribute(comm, CONT_HANDLE);
	HandleDistribute(comm, DFS_HANDLE);

	char *dfs_prefix = getenv("DAOS_PREFIX");
	if (dfs_prefix != NULL) {
		rc = dfs_set_prefix(pfind_dfs, dfs_prefix);
		DCHECK(rc, "Failed to set DFS prefix\n");
	}

        rc = d_hash_table_create(D_HASH_FT_EPHEMERAL | D_HASH_FT_NOLOCK | D_HASH_FT_LRU,
                                 4, NULL, &hdl_hash_ops, &dir_hash);
	DCHECK(rc, "Failed to initialize dir hashtable");
}

void
pfind_fini_daos(MPI_Comm comm) {
	int rc;

        while (1) {
                d_list_t *rlink = NULL;

                rlink = d_hash_rec_first(dir_hash);
                if (rlink == NULL)
                        break;
                d_hash_rec_decref(dir_hash, rlink);
        }

        rc = d_hash_table_destroy(dir_hash, false);
        DCHECK(rc, "Failed to destroy DFS hash");

	rc = dfs_umount(pfind_dfs);
	DCHECK(rc, "Failed to umount DFS namespace");
	MPI_Barrier(comm);

	rc = daos_cont_close(coh, NULL);
	DCHECK(rc, "Failed to close container (%d)", rc);
	MPI_Barrier(comm);

	rc = daos_pool_disconnect(poh, NULL);
	DCHECK(rc, "Failed to disconnect from pool");
	MPI_Barrier(comm);

	rc = daos_fini();
	DCHECK(rc, "Failed to finalize DAOS");
}

/* open directory, retry a few times on EINTR or EIO */
DIR* pfind_dfs_opendir(const char* dir, int *nr)
{
    struct dfs_pfind_t *dirp = NULL;
    int rc;

    dirp = calloc(1, sizeof(*dirp));
    if (dirp == NULL)
	    return NULL;

    dirp->dir = lookup_insert_dir(dir, NULL);
    if (dirp->dir == NULL) {
	    fprintf(stderr, "Failed to lookup %s\n", dir);
	    return NULL;
    }

    if (*nr == -1) {
	    dirp->num_splits = 0;
	    rc = dfs_obj_anchor_split(dirp->dir, &dirp->num_splits, NULL);
	    if (rc) {
		    fprintf(stderr, "dfs_obj_anchor_split failed (%d)", rc);
		    dfs_release(dirp->dir);
		    free(dirp);
		    return NULL;
	    }
	    *nr = dirp->num_splits;
	    goto done;
    }

    assert(*nr >= 0);
    rc = dfs_obj_anchor_set(dirp->dir, *nr, &dirp->anchor);
    if (rc) {
	    fprintf(stderr, "dfs_anchor_split failed (%d)", rc);
	    dfs_release(dirp->dir);
	    free(dirp);
	    return NULL;
    }

done:
    return (DIR *)dirp;
}

int pfind_dfs_closedir(DIR* _dirp)
{
    int rc;
    struct dfs_pfind_t *dirp = (struct dfs_pfind_t *)_dirp;

    //rc = dfs_release(dirp->dir);
    //if (rc)
    //return rc;
    rc = 0;
    free(dirp);
    return rc;
}

struct dirent* pfind_dfs_readdir(DIR* _dirp)
{
    int rc;
    struct dfs_pfind_t *dirp = (struct dfs_pfind_t *)_dirp;

    if (dirp->num_ents)
	    goto ret;

    dirp->num_ents = NUM_DIRENTS;

    while (!daos_anchor_is_eof(&dirp->anchor)) {
	    rc = dfs_readdir(pfind_dfs, dirp->dir, &dirp->anchor, &dirp->num_ents,
			     dirp->ents);
	    if (rc)
		    return NULL;

	    if (dirp->num_ents == 0)
		    continue;
	    goto ret;
    }

    assert(daos_anchor_is_eof(&dirp->anchor));
    return NULL;

ret:
    dirp->num_ents--;
    return &dirp->ents[dirp->num_ents];
}

int pfind_dfs_lstat(const char* path, struct stat* buf)
{
    int rc;
    dfs_obj_t *parent = NULL;
    char *name = NULL, *dir_name = NULL;

    parse_filename(path, &name, &dir_name);

    assert(dir_name);

    parent = lookup_insert_dir(dir_name, NULL);
    if (parent == NULL) {
	    fprintf(stderr, "dfs_lookup %s failed \n", dir_name);
	    return ENOENT;
    }

    rc = dfs_stat(pfind_dfs, parent, name, buf);
    if (rc) {
	    fprintf(stderr, "dfs_stat %s failed (%d)\n", name, rc);
	    return rc;
    }

    return 0;
}
