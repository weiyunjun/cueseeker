#ifndef CUESEEKER_CSMBCLIENT_H
#define CUESEEKER_CSMBCLIENT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    CSMB_OK = 0,
    CSMB_ERR_AUTH = 1,
    CSMB_ERR_NOT_FOUND = 2,
    CSMB_ERR_NOT_DIR = 3,
    CSMB_ERR_EXISTS = 4,
    CSMB_ERR_CONNECTION = 5
} csmb_error_code_t;

typedef struct csmb_session csmb_session_t;
typedef struct csmb_file csmb_file_t;

typedef struct {
    char *name;
    int is_directory;
    uint64_t size_bytes;
    int64_t modified_at_epoch;
} csmb_dir_entry_t;

typedef struct {
    csmb_dir_entry_t *entries;
    size_t count;
} csmb_dir_list_t;

typedef struct {
    char **names;
    size_t count;
} csmb_share_list_t;

csmb_error_code_t csmb_list_shares(
    const char *host,
    int port,
    const char *username,
    const char *password,
    csmb_share_list_t *out_shares,
    char **out_error_message
);

void csmb_free_share_list(csmb_share_list_t *list);

csmb_error_code_t csmb_session_connect(
    const char *host,
    int port,
    const char *share,
    const char *username,
    const char *password,
    csmb_session_t **out_session,
    char **out_error_message
);

void csmb_session_disconnect(csmb_session_t *session);

csmb_error_code_t csmb_session_list_directory(
    csmb_session_t *session,
    const char *rel_path,
    csmb_dir_list_t *out_list,
    char **out_error_message
);

void csmb_free_dir_list(csmb_dir_list_t *list);

csmb_error_code_t csmb_session_stat(
    csmb_session_t *session,
    const char *rel_path,
    int *out_is_directory,
    uint64_t *out_size_bytes,
    int64_t *out_modified_at_epoch,
    char **out_error_message
);

csmb_error_code_t csmb_session_read_file_range(
    csmb_session_t *session,
    const char *rel_path,
    uint64_t offset,
    uint64_t max_length,
    uint8_t **out_buffer,
    size_t *out_bytes_read,
    uint64_t *out_total_size,
    char **out_error_message
);

csmb_error_code_t csmb_file_open(
    csmb_session_t *session,
    const char *rel_path,
    csmb_file_t **out_file,
    uint64_t *out_total_size,
    uint32_t *out_max_read_size,
    char **out_error_message
);

csmb_error_code_t csmb_file_pread(
    csmb_file_t *file,
    uint64_t offset,
    uint8_t *buffer,
    uint32_t count,
    size_t *out_bytes_read,
    char **out_error_message
);

void csmb_file_close(csmb_file_t *file);

csmb_error_code_t csmb_session_rename(
    csmb_session_t *session,
    const char *old_rel_path,
    const char *new_rel_path,
    char **out_error_message
);

void csmb_free_buffer(void *ptr);

#ifdef __cplusplus
}
#endif

#endif /* CUESEEKER_CSMBCLIENT_H */
