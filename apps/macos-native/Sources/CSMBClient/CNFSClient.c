#include "CSMBClient.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include <nfsc/libnfs.h>
#include <nfsc/libnfs-raw-mount.h>
#include <nfsc/libnfs-raw-nfs.h>
#include <nfsc/libnfs-raw-nfs4.h>

static void cnfs_set_error(char **out_error_message, const char *msg) {
    if (!out_error_message) {
        return;
    }
    *out_error_message = strdup(msg && msg[0] ? msg : "NFS operation failed");
}

static csmb_error_code_t cnfs_classify_error(struct nfs_context *nfs, int rc) {
    int err = rc < 0 ? -rc : rc;
    const char *msg = nfs ? nfs_get_error(nfs) : NULL;

    if (err == EACCES || err == EPERM ||
        (msg && (strstr(msg, "NFS3ERR_ACCES") != NULL ||
                 strstr(msg, "NFS3ERR_PERM") != NULL ||
                 strstr(msg, "NFS4ERR_ACCESS") != NULL ||
                 strstr(msg, "NFS4ERR_PERM") != NULL ||
                 strstr(msg, "MNT3ERR_ACCES") != NULL ||
                 strstr(msg, "MNT3ERR_PERM") != NULL ||
                 strstr(msg, "Permission denied") != NULL))) {
        return CSMB_ERR_AUTH;
    }
    if (err == ENOENT ||
        (msg && (strstr(msg, "NFS3ERR_NOENT") != NULL ||
                 strstr(msg, "NFS4ERR_NOENT") != NULL ||
                 strstr(msg, "MNT3ERR_NOENT") != NULL ||
                 strstr(msg, "No such file") != NULL))) {
        return CSMB_ERR_NOT_FOUND;
    }
    if (err == ENOTDIR ||
        (msg && (strstr(msg, "NFS3ERR_NOTDIR") != NULL ||
                 strstr(msg, "NFS4ERR_NOTDIR") != NULL ||
                 strstr(msg, "MNT3ERR_NOTDIR") != NULL ||
                 strstr(msg, "Not a directory") != NULL))) {
        return CSMB_ERR_NOT_DIR;
    }
    if (err == EEXIST ||
        (msg && (strstr(msg, "NFS3ERR_EXIST") != NULL ||
                 strstr(msg, "NFS4ERR_EXIST") != NULL))) {
        return CSMB_ERR_EXISTS;
    }
    return CSMB_ERR_CONNECTION;
}

static char *cnfs_normalize_abs_path(const char *rel_path) {
    const char *p = rel_path ? rel_path : "";
    while (*p == '/') {
        p++;
    }
    size_t len = strlen(p);
    while (len > 0 && p[len - 1] == '/') {
        len--;
    }
    char *abs_path = (char *)malloc(len + 2);
    if (!abs_path) {
        return strdup("/");
    }
    abs_path[0] = '/';
    if (len > 0) {
        memcpy(abs_path + 1, p, len);
    }
    abs_path[len + 1] = '\0';
    return abs_path;
}

static struct nfs_context *cnfs_create_context(int version) {
    struct nfs_context *nfs = nfs_init_context();
    if (!nfs) {
        return NULL;
    }
    nfs_set_version(nfs, version);
    nfs_set_timeout(nfs, 10000);
    nfs_set_uid(nfs, (int)getuid());
    nfs_set_gid(nfs, (int)getgid());
    return nfs;
}

csmb_error_code_t cnfs_list_exports(
    const char *host,
    csmb_share_list_t *out_exports,
    char **out_error_message
) {
    if (!out_exports) {
        return CSMB_ERR_CONNECTION;
    }
    out_exports->names = NULL;
    out_exports->count = 0;

    struct exportnode *exports = mount_getexports_timeout(host, 6000);
    if (exports) {
        size_t cap = 16;
        size_t count = 0;
        char **names = (char **)calloc(cap, sizeof(char *));
        for (struct exportnode *cur = exports; cur != NULL; cur = cur->ex_next) {
            if (!cur->ex_dir || cur->ex_dir[0] == '\0') {
                continue;
            }
            char *norm = cnfs_normalize_abs_path(cur->ex_dir);
            int dup = 0;
            for (size_t i = 0; i < count; i++) {
                if (strcmp(names[i], norm) == 0) {
                    dup = 1;
                    break;
                }
            }
            if (dup) {
                free(norm);
                continue;
            }
            if (count == cap) {
                cap *= 2;
                names = (char **)realloc(names, cap * sizeof(char *));
            }
            names[count++] = norm;
        }
        mount_free_export_list(exports);
        if (count > 0) {
            out_exports->names = names;
            out_exports->count = count;
            return CSMB_OK;
        }
        free(names);
    }

    /* Fallback to NFSv4 pseudo-root "/" */
    struct nfs_context *nfs = cnfs_create_context(NFS_V4);
    if (!nfs) {
        cnfs_set_error(out_error_message, "Failed to initialize NFS context");
        return CSMB_ERR_CONNECTION;
    }
    int rc = nfs_mount(nfs, host, "/");
    if (rc < 0) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        nfs_destroy_context(nfs);
        return code;
    }
    struct nfsdir *dir = NULL;
    rc = nfs_opendir(nfs, "/", &dir);
    if (rc < 0 || !dir) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return code;
    }

    size_t cap = 16;
    size_t count = 0;
    char **names = (char **)calloc(cap, sizeof(char *));
    struct nfsdirent *ent = NULL;
    while ((ent = nfs_readdir(nfs, dir)) != NULL) {
        if (!ent->name || ent->name[0] == '.' || ent->type != NF3DIR) {
            continue;
        }
        if (count == cap) {
            cap *= 2;
            names = (char **)realloc(names, cap * sizeof(char *));
        }
        size_t nlen = strlen(ent->name) + 2;
        char *export_path = (char *)malloc(nlen);
        snprintf(export_path, nlen, "/%s", ent->name);
        names[count++] = export_path;
    }
    nfs_closedir(nfs, dir);
    nfs_umount(nfs);
    nfs_destroy_context(nfs);

    out_exports->names = names;
    out_exports->count = count;
    return CSMB_OK;
}

static csmb_error_code_t cnfs_mount_for_abs_path(
    const char *host,
    const char *abs_path,
    struct nfs_context **out_nfs,
    char **out_subpath,
    char **out_error_message
) {
    *out_nfs = NULL;
    *out_subpath = NULL;

    char *best_export = NULL;
    struct exportnode *exports = mount_getexports_timeout(host, 5000);
    for (struct exportnode *cur = exports; cur != NULL; cur = cur->ex_next) {
        if (!cur->ex_dir || cur->ex_dir[0] == '\0') {
            continue;
        }
        char *exp = cnfs_normalize_abs_path(cur->ex_dir);
        size_t exp_len = strlen(exp);
        int matches = 0;
        if (strcmp(exp, "/") == 0) {
            matches = 1;
        } else if (strcmp(abs_path, exp) == 0) {
            matches = 1;
        } else if (strncmp(abs_path, exp, exp_len) == 0 && abs_path[exp_len] == '/') {
            matches = 1;
        }
        if (matches && (!best_export || exp_len > strlen(best_export))) {
            free(best_export);
            best_export = exp;
        } else {
            free(exp);
        }
    }
    if (exports) {
        mount_free_export_list(exports);
    }

    const char *mount_export = best_export ? best_export : abs_path;
    const char *sub = "/";
    if (best_export) {
        if (strcmp(best_export, "/") == 0) {
            sub = abs_path;
        } else {
            const char *rem = abs_path + strlen(best_export);
            sub = (*rem == '\0') ? "/" : rem;
        }
    }

    /* 1. Try NFSv3 on matched export */
    struct nfs_context *nfs3 = cnfs_create_context(NFS_V3);
    if (nfs3) {
        int rc3 = nfs_mount(nfs3, host, mount_export);
        if (rc3 == 0) {
            *out_nfs = nfs3;
            *out_subpath = strdup(sub);
            free(best_export);
            return CSMB_OK;
        }
        csmb_error_code_t err3 = cnfs_classify_error(nfs3, rc3);
        char *msg3 = strdup(nfs_get_error(nfs3) ? nfs_get_error(nfs3) : "NFS mount failed");
        nfs_destroy_context(nfs3);

        /* 2. Fallback to NFSv4 pseudo-root "/" */
        struct nfs_context *nfs4 = cnfs_create_context(NFS_V4);
        if (nfs4) {
            if (nfs_mount(nfs4, host, "/") == 0) {
                *out_nfs = nfs4;
                *out_subpath = strdup(abs_path);
                free(best_export);
                free(msg3);
                return CSMB_OK;
            }
            nfs_destroy_context(nfs4);
        }

        free(best_export);
        cnfs_set_error(out_error_message, msg3);
        free(msg3);
        return err3;
    }

    free(best_export);
    cnfs_set_error(out_error_message, "Failed to initialize NFS context");
    return CSMB_ERR_CONNECTION;
}

csmb_error_code_t cnfs_stat(
    const char *host,
    const char *rel_path,
    int *out_is_directory,
    uint64_t *out_size_bytes,
    int64_t *out_modified_at_epoch,
    char **out_error_message
) {
    if (out_is_directory) *out_is_directory = 0;
    if (out_size_bytes) *out_size_bytes = 0;
    if (out_modified_at_epoch) *out_modified_at_epoch = 0;

    char *abs_path = cnfs_normalize_abs_path(rel_path);
    if (strcmp(abs_path, "/") == 0) {
        free(abs_path);
        if (out_is_directory) *out_is_directory = 1;
        return CSMB_OK;
    }

    /* Check if abs_path is a virtual parent prefix of an exported path */
    struct exportnode *exports = mount_getexports_timeout(host, 4000);
    size_t abs_len = strlen(abs_path);
    int is_virtual_prefix = 0;
    for (struct exportnode *cur = exports; cur != NULL; cur = cur->ex_next) {
        if (!cur->ex_dir) continue;
        char *exp = cnfs_normalize_abs_path(cur->ex_dir);
        if (strncmp(exp, abs_path, abs_len) == 0 && exp[abs_len] == '/') {
            is_virtual_prefix = 1;
        }
        free(exp);
        if (is_virtual_prefix) break;
    }
    if (exports) {
        mount_free_export_list(exports);
    }

    struct nfs_context *nfs = NULL;
    char *subpath = NULL;
    csmb_error_code_t mcode = cnfs_mount_for_abs_path(host, abs_path, &nfs, &subpath, out_error_message);
    free(abs_path);
    if (mcode != CSMB_OK) {
        if (is_virtual_prefix) {
            if (out_error_message && *out_error_message) {
                free(*out_error_message);
                *out_error_message = NULL;
            }
            if (out_is_directory) *out_is_directory = 1;
            return CSMB_OK;
        }
        return mcode;
    }

    struct nfs_stat_64 st;
    memset(&st, 0, sizeof(st));
    int rc = nfs_stat64(nfs, subpath, &st);
    if (rc < 0) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return code;
    }

    if (out_is_directory) *out_is_directory = S_ISDIR(st.nfs_mode) ? 1 : 0;
    if (out_size_bytes) *out_size_bytes = st.nfs_size;
    if (out_modified_at_epoch) *out_modified_at_epoch = (int64_t)st.nfs_mtime;

    free(subpath);
    nfs_umount(nfs);
    nfs_destroy_context(nfs);
    return CSMB_OK;
}

csmb_error_code_t cnfs_list_directory(
    const char *host,
    const char *rel_path,
    csmb_dir_list_t *out_list,
    char **out_error_message
) {
    if (!out_list) {
        return CSMB_ERR_CONNECTION;
    }
    out_list->entries = NULL;
    out_list->count = 0;

    char *abs_path = cnfs_normalize_abs_path(rel_path);

    /* Synthesize virtual intermediate directories above deeper exports if not directly inside an export */
    struct exportnode *exports = mount_getexports_timeout(host, 4000);
    if (exports) {
        int inside_export = 0;
        for (struct exportnode *cur = exports; cur != NULL; cur = cur->ex_next) {
            if (!cur->ex_dir) continue;
            char *exp = cnfs_normalize_abs_path(cur->ex_dir);
            size_t elen = strlen(exp);
            if (strcmp(exp, "/") == 0 || strcmp(abs_path, exp) == 0 ||
                (strncmp(abs_path, exp, elen) == 0 && abs_path[elen] == '/')) {
                inside_export = 1;
            }
            free(exp);
            if (inside_export) break;
        }
        if (!inside_export) {
            size_t abs_len = strlen(abs_path);
            size_t cap = 16;
            size_t count = 0;
            csmb_dir_entry_t *entries = (csmb_dir_entry_t *)calloc(cap, sizeof(csmb_dir_entry_t));
            for (struct exportnode *cur = exports; cur != NULL; cur = cur->ex_next) {
                if (!cur->ex_dir) continue;
                char *exp = cnfs_normalize_abs_path(cur->ex_dir);
                const char *rem = NULL;
                if (strcmp(abs_path, "/") == 0 && exp[0] == '/' && exp[1] != '\0') {
                    rem = exp + 1;
                } else if (strncmp(exp, abs_path, abs_len) == 0 && exp[abs_len] == '/') {
                    rem = exp + abs_len + 1;
                }
                if (rem && *rem) {
                    const char *slash = strchr(rem, '/');
                    size_t seg_len = slash ? (size_t)(slash - rem) : strlen(rem);
                    char *seg = strndup(rem, seg_len);
                    int dup = 0;
                    for (size_t i = 0; i < count; i++) {
                        if (strcmp(entries[i].name, seg) == 0) {
                            dup = 1;
                            break;
                        }
                    }
                    if (!dup) {
                        if (count == cap) {
                            cap *= 2;
                            entries = (csmb_dir_entry_t *)realloc(entries, cap * sizeof(csmb_dir_entry_t));
                        }
                        entries[count].name = seg;
                        entries[count].is_directory = 1;
                        entries[count].size_bytes = 0;
                        entries[count].modified_at_epoch = 0;
                        count++;
                    } else {
                        free(seg);
                    }
                }
                free(exp);
            }
            mount_free_export_list(exports);
            if (count > 0) {
                free(abs_path);
                out_list->entries = entries;
                out_list->count = count;
                return CSMB_OK;
            }
            free(entries);
        } else {
            mount_free_export_list(exports);
        }
    }

    struct nfs_context *nfs = NULL;
    char *subpath = NULL;
    csmb_error_code_t mcode = cnfs_mount_for_abs_path(host, abs_path, &nfs, &subpath, out_error_message);
    free(abs_path);
    if (mcode != CSMB_OK) {
        return mcode;
    }

    if (strcmp(subpath, "/") != 0) {
        struct nfs_stat_64 st;
        memset(&st, 0, sizeof(st));
        int st_rc = nfs_stat64(nfs, subpath, &st);
        if (st_rc < 0) {
            csmb_error_code_t code = cnfs_classify_error(nfs, st_rc);
            cnfs_set_error(out_error_message, nfs_get_error(nfs));
            free(subpath);
            nfs_umount(nfs);
            nfs_destroy_context(nfs);
            return code;
        }
        if (!S_ISDIR(st.nfs_mode)) {
            cnfs_set_error(out_error_message, "Target NFS path is not a directory");
            free(subpath);
            nfs_umount(nfs);
            nfs_destroy_context(nfs);
            return CSMB_ERR_NOT_DIR;
        }
    }

    struct nfsdir *dir = NULL;
    int rc = nfs_opendir(nfs, subpath, &dir);
    if (rc < 0 || !dir) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return code;
    }

    size_t cap = 32;
    size_t count = 0;
    csmb_dir_entry_t *entries = (csmb_dir_entry_t *)calloc(cap, sizeof(csmb_dir_entry_t));
    struct nfsdirent *ent = NULL;
    while ((ent = nfs_readdir(nfs, dir)) != NULL) {
        if (!ent->name || strcmp(ent->name, ".") == 0 || strcmp(ent->name, "..") == 0) {
            continue;
        }
        if (count == cap) {
            cap *= 2;
            entries = (csmb_dir_entry_t *)realloc(entries, cap * sizeof(csmb_dir_entry_t));
        }
        entries[count].name = strdup(ent->name);
        entries[count].is_directory = (ent->type == NF3DIR || S_ISDIR(ent->mode)) ? 1 : 0;
        entries[count].size_bytes = ent->size;
        entries[count].modified_at_epoch = (int64_t)ent->mtime.tv_sec;
        count++;
    }

    nfs_closedir(nfs, dir);
    free(subpath);
    nfs_umount(nfs);
    nfs_destroy_context(nfs);

    out_list->entries = entries;
    out_list->count = count;
    return CSMB_OK;
}

csmb_error_code_t cnfs_read_file_range(
    const char *host,
    const char *rel_path,
    uint64_t offset,
    uint64_t max_length,
    uint8_t **out_buffer,
    size_t *out_bytes_read,
    uint64_t *out_total_size,
    char **out_error_message
) {
    if (out_buffer) *out_buffer = NULL;
    if (out_bytes_read) *out_bytes_read = 0;
    if (out_total_size) *out_total_size = 0;

    char *abs_path = cnfs_normalize_abs_path(rel_path);
    struct nfs_context *nfs = NULL;
    char *subpath = NULL;
    csmb_error_code_t mcode = cnfs_mount_for_abs_path(host, abs_path, &nfs, &subpath, out_error_message);
    free(abs_path);
    if (mcode != CSMB_OK) {
        return mcode;
    }

    struct nfsfh *fh = NULL;
    int rc = nfs_open(nfs, subpath, O_RDONLY, &fh);
    if (rc < 0 || !fh) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return code;
    }

    struct nfs_stat_64 st;
    memset(&st, 0, sizeof(st));
    rc = nfs_fstat64(nfs, fh, &st);
    if (rc < 0) {
        csmb_error_code_t code = cnfs_classify_error(nfs, rc);
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
        nfs_close(nfs, fh);
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return code;
    }

    uint64_t total_size = st.nfs_size;
    if (out_total_size) {
        *out_total_size = total_size;
    }

    if (max_length == 0 || offset >= total_size || !out_buffer) {
        nfs_close(nfs, fh);
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        return CSMB_OK;
    }

    uint64_t available = total_size - offset;
    uint64_t to_read = (max_length < available) ? max_length : available;
    uint8_t *buffer = (uint8_t *)malloc((size_t)to_read);
    if (!buffer) {
        nfs_close(nfs, fh);
        free(subpath);
        nfs_umount(nfs);
        nfs_destroy_context(nfs);
        cnfs_set_error(out_error_message, "Out of memory");
        return CSMB_ERR_CONNECTION;
    }

    size_t max_chunk = nfs_get_readmax(nfs);
    if (max_chunk == 0 || max_chunk > 524288) {
        max_chunk = 262144;
    }

    size_t total_read = 0;
    while (total_read < (size_t)to_read) {
        size_t remaining = (size_t)to_read - total_read;
        size_t chunk = (remaining < max_chunk) ? remaining : max_chunk;
        int n = nfs_pread(nfs, fh, buffer + total_read, chunk, offset + (uint64_t)total_read);
        if (n < 0) {
            csmb_error_code_t code = cnfs_classify_error(nfs, n);
            cnfs_set_error(out_error_message, nfs_get_error(nfs));
            free(buffer);
            nfs_close(nfs, fh);
            free(subpath);
            nfs_umount(nfs);
            nfs_destroy_context(nfs);
            return code;
        }
        if (n == 0) {
            break;
        }
        total_read += (size_t)n;
    }

    nfs_close(nfs, fh);
    free(subpath);
    nfs_umount(nfs);
    nfs_destroy_context(nfs);

    *out_buffer = buffer;
    if (out_bytes_read) {
        *out_bytes_read = total_read;
    }
    return CSMB_OK;
}

csmb_error_code_t cnfs_rename(
    const char *host,
    const char *old_rel_path,
    const char *new_rel_path,
    char **out_error_message
) {
    char *old_abs = cnfs_normalize_abs_path(old_rel_path);
    char *new_abs = cnfs_normalize_abs_path(new_rel_path);

    struct nfs_context *nfs = NULL;
    char *old_sub = NULL;
    csmb_error_code_t mcode = cnfs_mount_for_abs_path(host, old_abs, &nfs, &old_sub, out_error_message);
    if (mcode != CSMB_OK) {
        free(old_abs);
        free(new_abs);
        return mcode;
    }

    size_t export_prefix_len = strlen(old_abs) - (strcmp(old_sub, "/") == 0 ? 0 : strlen(old_sub));
    const char *new_sub = new_abs;
    if (export_prefix_len > 0 && strncmp(old_abs, new_abs, export_prefix_len) == 0) {
        new_sub = new_abs + export_prefix_len;
        if (*new_sub == '\0') new_sub = "/";
    }

    int rc = nfs_rename(nfs, old_sub, new_sub);
    csmb_error_code_t code = (rc == 0) ? CSMB_OK : cnfs_classify_error(nfs, rc);
    if (rc < 0) {
        cnfs_set_error(out_error_message, nfs_get_error(nfs));
    }

    free(old_sub);
    free(old_abs);
    free(new_abs);
    nfs_umount(nfs);
    nfs_destroy_context(nfs);
    return code;
}
