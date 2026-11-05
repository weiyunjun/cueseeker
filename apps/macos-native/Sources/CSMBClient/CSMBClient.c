#include "CSMBClient.h"

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include <smb2/smb2.h>
#include <smb2/libsmb2.h>
#include <smb2/libsmb2-raw.h>
#include <smb2/libsmb2-dcerpc-srvsvc.h>

#define CSMB_SHARE_CACHE_CAP 16
#define CSMB_SHARE_CACHE_TTL 120
#define CSMB_SESSION_POOL_CAP 8
#define CSMB_SESSION_POOL_TTL 120
#define CSMB_ANON_CACHE_CAP 16

typedef struct {
    char *host;
    int port;
    char *username;
    char *password;
    char **names;
    size_t count;
    time_t fetched_at;
} csmb_share_cache_entry_t;

typedef struct {
    char *host;
    int port;
    char *share;
    char *username;
    char *password;
    struct smb2_context *smb2;
    time_t last_used;
} csmb_pooled_session_t;

typedef struct {
    char *host;
    int port;
    int prefer_null_password;
    time_t updated_at;
} csmb_anon_mode_entry_t;

struct csmb_session {
    struct smb2_context *smb2;
    char *host;
    int port;
    char *share;
    char *username;
    char *password;
    int was_reused;
    int tainted;
};

struct csmb_file {
    csmb_session_t *session;
    struct smb2_context *smb2;
    struct smb2fh *fh;
};

static pthread_mutex_t g_csmb_mutex = PTHREAD_MUTEX_INITIALIZER;
static csmb_share_cache_entry_t g_share_cache[CSMB_SHARE_CACHE_CAP];
static csmb_pooled_session_t g_smb_pool[CSMB_SESSION_POOL_CAP];
static csmb_anon_mode_entry_t g_anon_cache[CSMB_ANON_CACHE_CAP];

static char *csmb_strdup(const char *str) {
    if (!str) {
        return strdup("");
    }
    return strdup(str);
}

static void csmb_free_string_array(char **items, size_t count) {
    if (!items) {
        return;
    }
    for (size_t i = 0; i < count; i++) {
        free(items[i]);
    }
    free(items);
}

static char **csmb_copy_string_array(char **items, size_t count) {
    if (!items || count == 0) {
        return NULL;
    }
    char **copy = (char **)calloc(count, sizeof(char *));
    if (!copy) {
        return NULL;
    }
    for (size_t i = 0; i < count; i++) {
        copy[i] = csmb_strdup(items[i]);
    }
    return copy;
}

static int csmb_preferred_anon_mode(const char *host, int port) {
    if (!host || !host[0]) {
        return 0;
    }
    int mode = 0;
    pthread_mutex_lock(&g_csmb_mutex);
    for (size_t i = 0; i < CSMB_ANON_CACHE_CAP; i++) {
        if (g_anon_cache[i].host &&
            g_anon_cache[i].port == port &&
            strcmp(g_anon_cache[i].host, host) == 0) {
            mode = g_anon_cache[i].prefer_null_password;
            break;
        }
    }
    pthread_mutex_unlock(&g_csmb_mutex);
    return mode;
}

static void csmb_record_anon_mode(const char *host, int port, int prefer_null_password) {
    if (!host || !host[0]) {
        return;
    }
    time_t now = time(NULL);
    pthread_mutex_lock(&g_csmb_mutex);
    size_t slot = 0;
    int found = 0;
    for (size_t i = 0; i < CSMB_ANON_CACHE_CAP; i++) {
        if (g_anon_cache[i].host &&
            g_anon_cache[i].port == port &&
            strcmp(g_anon_cache[i].host, host) == 0) {
            slot = i;
            found = 1;
            break;
        }
    }
    if (!found) {
        for (size_t i = 0; i < CSMB_ANON_CACHE_CAP; i++) {
            if (!g_anon_cache[i].host) {
                slot = i;
                found = 1;
                break;
            }
        }
    }
    if (!found) {
        time_t oldest = g_anon_cache[0].updated_at;
        slot = 0;
        for (size_t i = 1; i < CSMB_ANON_CACHE_CAP; i++) {
            if (g_anon_cache[i].updated_at < oldest) {
                oldest = g_anon_cache[i].updated_at;
                slot = i;
            }
        }
    }
    free(g_anon_cache[slot].host);
    g_anon_cache[slot].host = csmb_strdup(host);
    g_anon_cache[slot].port = port;
    g_anon_cache[slot].prefer_null_password = prefer_null_password;
    g_anon_cache[slot].updated_at = now;
    pthread_mutex_unlock(&g_csmb_mutex);
}

static void csmb_set_error(char **out_error_message, const char *msg) {
    if (!out_error_message) {
        return;
    }
    *out_error_message = csmb_strdup(msg ? msg : "Unknown SMB error");
}

static csmb_error_code_t csmb_classify_error(struct smb2_context *smb2, int rc) {
    uint32_t nt = smb2 ? (uint32_t)smb2_get_nterror(smb2) : 0;
    const char *msg = smb2 ? smb2_get_error(smb2) : NULL;
    int err = rc < 0 ? -rc : rc;

    if (nt == SMB2_STATUS_LOGON_FAILURE ||
        nt == SMB2_STATUS_ACCESS_DENIED ||
        nt == SMB2_STATUS_ACCOUNT_RESTRICTION ||
        nt == SMB2_STATUS_INVALID_LOGON_HOURS ||
        nt == SMB2_STATUS_PASSWORD_EXPIRED ||
        nt == SMB2_STATUS_ACCOUNT_DISABLED ||
        nt == SMB2_STATUS_WRONG_PASSWORD ||
        nt == SMB2_STATUS_NO_SUCH_USER ||
        err == EACCES ||
        err == EPERM ||
        (msg && (strstr(msg, "STATUS_LOGON_FAILURE") != NULL ||
                 strstr(msg, "STATUS_ACCESS_DENIED") != NULL ||
                 strstr(msg, "Session setup failed") != NULL))) {
        return CSMB_ERR_AUTH;
    }

    if (nt == SMB2_STATUS_BAD_NETWORK_NAME ||
        nt == SMB2_STATUS_OBJECT_NAME_NOT_FOUND ||
        nt == SMB2_STATUS_OBJECT_PATH_NOT_FOUND ||
        nt == SMB2_STATUS_NO_SUCH_FILE ||
        err == ENOENT ||
        (msg && (strstr(msg, "STATUS_BAD_NETWORK_NAME") != NULL ||
                 strstr(msg, "STATUS_OBJECT_NAME_NOT_FOUND") != NULL ||
                 strstr(msg, "STATUS_OBJECT_PATH_NOT_FOUND") != NULL))) {
        return CSMB_ERR_NOT_FOUND;
    }

    if (nt == SMB2_STATUS_NOT_A_DIRECTORY ||
        err == ENOTDIR ||
        (msg && strstr(msg, "STATUS_NOT_A_DIRECTORY") != NULL)) {
        return CSMB_ERR_NOT_DIR;
    }

    if (nt == SMB2_STATUS_OBJECT_NAME_COLLISION ||
        err == EEXIST ||
        (msg && strstr(msg, "STATUS_OBJECT_NAME_COLLISION") != NULL)) {
        return CSMB_ERR_EXISTS;
    }

    return CSMB_ERR_CONNECTION;
}

static void csmb_format_server(const char *host, int port, char *buf, size_t buf_size) {
    int is_bare_ipv6 = (host != NULL && host[0] != '[' && strchr(host, ':') != NULL);
    if (is_bare_ipv6) {
        if (port > 0 && port != 445) {
            snprintf(buf, buf_size, "[%s]:%d", host, port);
        } else {
            snprintf(buf, buf_size, "[%s]", host);
        }
    } else if (port > 0 && port != 445) {
        snprintf(buf, buf_size, "%s:%d", host, port);
    } else {
        snprintf(buf, buf_size, "%s", host ? host : "");
    }
}

static const char *csmb_normalize_rel_path(const char *rel_path) {
    if (!rel_path) {
        return "";
    }
    while (*rel_path == '/') {
        rel_path++;
    }
    return rel_path;
}

static void csmb_apply_credentials(
    struct smb2_context *smb2,
    const char *username,
    const char *password,
    int anonymous_null_password,
    char **out_effective_user
) {
    int has_user = (username != NULL && username[0] != '\0');
    int has_pass = (password != NULL && password[0] != '\0');

    if (has_user) {
        const char *sep = strchr(username, '\\');
        if (!sep) {
            sep = strchr(username, ';');
        }
        if (sep && sep > username && sep[1] != '\0') {
            size_t dom_len = (size_t)(sep - username);
            char *domain = (char *)malloc(dom_len + 1);
            if (domain) {
                memcpy(domain, username, dom_len);
                domain[dom_len] = '\0';
                smb2_set_domain(smb2, domain);
                free(domain);
            }
            smb2_set_user(smb2, sep + 1);
            *out_effective_user = csmb_strdup(sep + 1);
        } else {
            smb2_set_user(smb2, username);
            *out_effective_user = csmb_strdup(username);
        }
        smb2_set_password(smb2, password ? password : "");
    } else if (has_pass) {
        smb2_set_user(smb2, "guest");
        smb2_set_password(smb2, password);
        *out_effective_user = csmb_strdup("guest");
    } else {
        smb2_set_user(smb2, "guest");
        smb2_set_password(smb2, anonymous_null_password ? NULL : "");
        *out_effective_user = csmb_strdup("guest");
    }
}

static csmb_error_code_t csmb_connect_context(
    const char *host,
    int port,
    const char *share,
    const char *username,
    const char *password,
    struct smb2_context **out_smb2,
    char **out_error_message
) {
    *out_smb2 = NULL;
    char server[512];
    csmb_format_server(host, port, server, sizeof(server));

    int is_anonymous = (username == NULL || username[0] == '\0') &&
                       (password == NULL || password[0] == '\0');
    int max_attempts = is_anonymous ? 2 : 1;
    int preferred_anon_null = is_anonymous ? csmb_preferred_anon_mode(host, port) : 0;
    csmb_error_code_t last_code = CSMB_ERR_CONNECTION;

    for (int attempt = 0; attempt < max_attempts; attempt++) {
        struct smb2_context *smb2 = smb2_init_context();
        if (!smb2) {
            csmb_set_error(out_error_message, "Failed to initialize SMB2 context");
            return CSMB_ERR_CONNECTION;
        }

        smb2_set_security_mode(smb2, SMB2_NEGOTIATE_SIGNING_ENABLED);
        smb2_set_timeout(smb2, 15);

        int use_null_password = (attempt == 0) ? preferred_anon_null : !preferred_anon_null;
        char *effective_user = NULL;
        csmb_apply_credentials(smb2, username, password, use_null_password, &effective_user);

        int rc = smb2_connect_share(smb2, server, share, effective_user);
        free(effective_user);

        if (rc == 0) {
            if (is_anonymous) {
                csmb_record_anon_mode(host, port, use_null_password);
            }
            *out_smb2 = smb2;
            return CSMB_OK;
        }

        last_code = csmb_classify_error(smb2, rc);
        if (attempt + 1 < max_attempts && last_code == CSMB_ERR_AUTH) {
            smb2_destroy_context(smb2);
            continue;
        }

        csmb_set_error(out_error_message, smb2_get_error(smb2));
        smb2_destroy_context(smb2);
        return last_code;
    }

    return last_code;
}

static int csmb_reconnect_reused_session(csmb_session_t *session) {
    if (!session || !session->was_reused) {
        return 0;
    }
    session->was_reused = 0;
    if (session->smb2) {
        smb2_destroy_context(session->smb2);
        session->smb2 = NULL;
    }
    struct smb2_context *fresh = NULL;
    csmb_error_code_t code = csmb_connect_context(
        session->host,
        session->port,
        session->share,
        session->username,
        session->password,
        &fresh,
        NULL
    );
    if (code != CSMB_OK || !fresh) {
        session->tainted = 1;
        return 0;
    }
    session->smb2 = fresh;
    session->tainted = 0;
    return 1;
}

struct csmb_share_enum_state {
    int finished;
    int status;
    csmb_share_list_t list;
};

static void csmb_share_enum_cb(
    struct smb2_context *smb2,
    int status,
    void *command_data,
    void *private_data
) {
    struct csmb_share_enum_state *state = (struct csmb_share_enum_state *)private_data;
    state->status = status;

    if (status == SMB2_STATUS_SUCCESS && command_data != NULL) {
        struct srvsvc_NetrShareEnum_rep *rep =
            (struct srvsvc_NetrShareEnum_rep *)command_data;
        if (rep->ses.ShareInfo.Level == 1 &&
            rep->ses.ShareInfo.Level1.Buffer != NULL &&
            rep->ses.ShareInfo.Level1.EntriesRead > 0) {
            uint32_t total = rep->ses.ShareInfo.Level1.EntriesRead;
            char **names = (char **)calloc(total, sizeof(char *));
            size_t count = 0;
            if (names) {
                for (uint32_t i = 0; i < total; i++) {
                    struct srvsvc_SHARE_INFO_1 *info = &rep->ses.ShareInfo.Level1.Buffer->share_info_1[i];
                    uint32_t base_type = info->type & 3;
                    int is_hidden = (info->type & SHARE_TYPE_HIDDEN) != 0;
                    const char *name = info->netname.utf8;
                    if (!name || name[0] == '\0' || name[0] == '.') {
                        continue;
                    }
                    size_t name_len = strlen(name);
                    if (name[name_len - 1] == '$') {
                        continue;
                    }
                    if (base_type == SHARE_TYPE_DISKTREE && !is_hidden) {
                        names[count++] = csmb_strdup(name);
                    }
                }
                state->list.names = names;
                state->list.count = count;
            }
        }
        smb2_free_data(smb2, rep);
    }

    state->finished = 1;
}

csmb_error_code_t csmb_list_shares(
    const char *host,
    int port,
    const char *username,
    const char *password,
    csmb_share_list_t *out_shares,
    char **out_error_message
) {
    if (!out_shares) {
        return CSMB_ERR_CONNECTION;
    }
    out_shares->names = NULL;
    out_shares->count = 0;

    const char *norm_host = host ? host : "";
    const char *norm_user = username ? username : "";
    const char *norm_pass = password ? password : "";
    time_t now = time(NULL);

    pthread_mutex_lock(&g_csmb_mutex);
    for (size_t i = 0; i < CSMB_SHARE_CACHE_CAP; i++) {
        if (g_share_cache[i].host &&
            g_share_cache[i].port == port &&
            strcmp(g_share_cache[i].host, norm_host) == 0 &&
            strcmp(g_share_cache[i].username, norm_user) == 0 &&
            strcmp(g_share_cache[i].password, norm_pass) == 0 &&
            (now - g_share_cache[i].fetched_at) < CSMB_SHARE_CACHE_TTL &&
            g_share_cache[i].count > 0) {
            char **copied = csmb_copy_string_array(g_share_cache[i].names, g_share_cache[i].count);
            if (copied) {
                out_shares->names = copied;
                out_shares->count = g_share_cache[i].count;
                pthread_mutex_unlock(&g_csmb_mutex);
                return CSMB_OK;
            }
        }
    }
    pthread_mutex_unlock(&g_csmb_mutex);

    struct smb2_context *smb2 = NULL;
    csmb_error_code_t code = csmb_connect_context(
        host,
        port,
        "IPC$",
        username,
        password,
        &smb2,
        out_error_message
    );
    if (code != CSMB_OK) {
        return code;
    }

    struct csmb_share_enum_state state;
    memset(&state, 0, sizeof(state));

    int rc = smb2_share_enum_async(smb2, SHARE_INFO_1, csmb_share_enum_cb, &state);
    if (rc != 0) {
        csmb_error_code_t err_code = csmb_classify_error(smb2, rc);
        csmb_set_error(out_error_message, smb2_get_error(smb2));
        smb2_destroy_context(smb2);
        return err_code;
    }

    while (!state.finished) {
        struct pollfd pfd;
        memset(&pfd, 0, sizeof(pfd));
        pfd.fd = smb2_get_fd(smb2);
        pfd.events = smb2_which_events(smb2);

        int poll_rc = poll(&pfd, 1, 15000);
        if (poll_rc <= 0) {
            csmb_set_error(out_error_message, "Timed out enumerating SMB shares");
            smb2_destroy_context(smb2);
            csmb_free_share_list(&state.list);
            return CSMB_ERR_CONNECTION;
        }
        if (smb2_service(smb2, pfd.revents) < 0) {
            csmb_error_code_t err_code = csmb_classify_error(smb2, -EIO);
            csmb_set_error(out_error_message, smb2_get_error(smb2));
            smb2_destroy_context(smb2);
            csmb_free_share_list(&state.list);
            return err_code;
        }
    }

    if (state.status != SMB2_STATUS_SUCCESS) {
        csmb_error_code_t err_code = csmb_classify_error(smb2, state.status);
        csmb_set_error(out_error_message, smb2_get_error(smb2));
        smb2_destroy_context(smb2);
        csmb_free_share_list(&state.list);
        return err_code;
    }

    smb2_disconnect_share(smb2);
    smb2_destroy_context(smb2);

    if (state.list.count > 0 && norm_host[0] != '\0') {
        pthread_mutex_lock(&g_csmb_mutex);
        size_t slot = 0;
        int found = 0;
        for (size_t i = 0; i < CSMB_SHARE_CACHE_CAP; i++) {
            if (g_share_cache[i].host &&
                g_share_cache[i].port == port &&
                strcmp(g_share_cache[i].host, norm_host) == 0 &&
                strcmp(g_share_cache[i].username, norm_user) == 0 &&
                strcmp(g_share_cache[i].password, norm_pass) == 0) {
                slot = i;
                found = 1;
                break;
            }
        }
        if (!found) {
            for (size_t i = 0; i < CSMB_SHARE_CACHE_CAP; i++) {
                if (!g_share_cache[i].host) {
                    slot = i;
                    found = 1;
                    break;
                }
            }
        }
        if (!found) {
            time_t oldest = g_share_cache[0].fetched_at;
            slot = 0;
            for (size_t i = 1; i < CSMB_SHARE_CACHE_CAP; i++) {
                if (g_share_cache[i].fetched_at < oldest) {
                    oldest = g_share_cache[i].fetched_at;
                    slot = i;
                }
            }
        }
        free(g_share_cache[slot].host);
        free(g_share_cache[slot].username);
        free(g_share_cache[slot].password);
        csmb_free_string_array(g_share_cache[slot].names, g_share_cache[slot].count);
        g_share_cache[slot].host = csmb_strdup(norm_host);
        g_share_cache[slot].port = port;
        g_share_cache[slot].username = csmb_strdup(norm_user);
        g_share_cache[slot].password = csmb_strdup(norm_pass);
        g_share_cache[slot].names = csmb_copy_string_array(state.list.names, state.list.count);
        g_share_cache[slot].count = g_share_cache[slot].names ? state.list.count : 0;
        g_share_cache[slot].fetched_at = time(NULL);
        pthread_mutex_unlock(&g_csmb_mutex);
    }

    *out_shares = state.list;
    return CSMB_OK;
}

void csmb_free_share_list(csmb_share_list_t *list) {
    if (!list || !list->names) {
        return;
    }
    for (size_t i = 0; i < list->count; i++) {
        free(list->names[i]);
    }
    free(list->names);
    list->names = NULL;
    list->count = 0;
}

csmb_error_code_t csmb_session_connect(
    const char *host,
    int port,
    const char *share,
    const char *username,
    const char *password,
    csmb_session_t **out_session,
    char **out_error_message
) {
    if (!out_session) {
        return CSMB_ERR_CONNECTION;
    }
    *out_session = NULL;

    const char *norm_host = host ? host : "";
    const char *norm_share = share ? share : "";
    const char *norm_user = username ? username : "";
    const char *norm_pass = password ? password : "";
    time_t now = time(NULL);

    pthread_mutex_lock(&g_csmb_mutex);
    for (size_t i = 0; i < CSMB_SESSION_POOL_CAP; i++) {
        if (g_smb_pool[i].smb2 &&
            g_smb_pool[i].host && strcmp(g_smb_pool[i].host, norm_host) == 0 &&
            g_smb_pool[i].port == port &&
            g_smb_pool[i].share && strcmp(g_smb_pool[i].share, norm_share) == 0 &&
            g_smb_pool[i].username && strcmp(g_smb_pool[i].username, norm_user) == 0 &&
            g_smb_pool[i].password && strcmp(g_smb_pool[i].password, norm_pass) == 0) {
            if ((now - g_smb_pool[i].last_used) < CSMB_SESSION_POOL_TTL) {
                csmb_session_t *reused = (csmb_session_t *)calloc(1, sizeof(csmb_session_t));
                if (reused) {
                    reused->smb2 = g_smb_pool[i].smb2;
                    reused->host = g_smb_pool[i].host;
                    reused->port = g_smb_pool[i].port;
                    reused->share = g_smb_pool[i].share;
                    reused->username = g_smb_pool[i].username;
                    reused->password = g_smb_pool[i].password;
                    reused->was_reused = 1;
                    reused->tainted = 0;
                    memset(&g_smb_pool[i], 0, sizeof(g_smb_pool[i]));
                    pthread_mutex_unlock(&g_csmb_mutex);
                    *out_session = reused;
                    return CSMB_OK;
                }
            } else {
                struct smb2_context *expired = g_smb_pool[i].smb2;
                free(g_smb_pool[i].host);
                free(g_smb_pool[i].share);
                free(g_smb_pool[i].username);
                free(g_smb_pool[i].password);
                memset(&g_smb_pool[i], 0, sizeof(g_smb_pool[i]));
                pthread_mutex_unlock(&g_csmb_mutex);
                smb2_disconnect_share(expired);
                smb2_destroy_context(expired);
                pthread_mutex_lock(&g_csmb_mutex);
            }
        }
    }
    pthread_mutex_unlock(&g_csmb_mutex);

    struct smb2_context *smb2 = NULL;
    csmb_error_code_t code = csmb_connect_context(
        host,
        port,
        share,
        username,
        password,
        &smb2,
        out_error_message
    );
    if (code != CSMB_OK) {
        return code;
    }

    csmb_session_t *session = (csmb_session_t *)calloc(1, sizeof(csmb_session_t));
    if (!session) {
        smb2_destroy_context(smb2);
        csmb_set_error(out_error_message, "Out of memory");
        return CSMB_ERR_CONNECTION;
    }
    session->smb2 = smb2;
    session->host = csmb_strdup(norm_host);
    session->port = port;
    session->share = csmb_strdup(norm_share);
    session->username = csmb_strdup(norm_user);
    session->password = csmb_strdup(norm_pass);
    session->was_reused = 0;
    session->tainted = 0;
    *out_session = session;
    return CSMB_OK;
}

void csmb_session_disconnect(csmb_session_t *session) {
    if (!session) {
        return;
    }
    if (!session->smb2 || session->tainted) {
        if (session->smb2) {
            smb2_disconnect_share(session->smb2);
            smb2_destroy_context(session->smb2);
            session->smb2 = NULL;
        }
        free(session->host);
        free(session->share);
        free(session->username);
        free(session->password);
        free(session);
        return;
    }

    struct smb2_context *evicted_smb2 = NULL;
    char *evicted_host = NULL;
    char *evicted_share = NULL;
    char *evicted_user = NULL;
    char *evicted_pass = NULL;

    pthread_mutex_lock(&g_csmb_mutex);
    size_t slot = 0;
    int found = 0;
    for (size_t i = 0; i < CSMB_SESSION_POOL_CAP; i++) {
        if (!g_smb_pool[i].smb2) {
            slot = i;
            found = 1;
            break;
        }
    }
    if (!found) {
        time_t oldest = g_smb_pool[0].last_used;
        slot = 0;
        for (size_t i = 1; i < CSMB_SESSION_POOL_CAP; i++) {
            if (g_smb_pool[i].last_used < oldest) {
                oldest = g_smb_pool[i].last_used;
                slot = i;
            }
        }
        evicted_smb2 = g_smb_pool[slot].smb2;
        evicted_host = g_smb_pool[slot].host;
        evicted_share = g_smb_pool[slot].share;
        evicted_user = g_smb_pool[slot].username;
        evicted_pass = g_smb_pool[slot].password;
    }
    g_smb_pool[slot].smb2 = session->smb2;
    g_smb_pool[slot].host = session->host;
    g_smb_pool[slot].port = session->port;
    g_smb_pool[slot].share = session->share;
    g_smb_pool[slot].username = session->username;
    g_smb_pool[slot].password = session->password;
    g_smb_pool[slot].last_used = time(NULL);
    pthread_mutex_unlock(&g_csmb_mutex);

    if (evicted_smb2) {
        smb2_disconnect_share(evicted_smb2);
        smb2_destroy_context(evicted_smb2);
        free(evicted_host);
        free(evicted_share);
        free(evicted_user);
        free(evicted_pass);
    }

    free(session);
}

csmb_error_code_t csmb_session_stat(
    csmb_session_t *session,
    const char *rel_path,
    int *out_is_directory,
    uint64_t *out_size_bytes,
    int64_t *out_modified_at_epoch,
    char **out_error_message
) {
    if (!session || !session->smb2) {
        csmb_set_error(out_error_message, "Invalid SMB session");
        return CSMB_ERR_CONNECTION;
    }

    const char *norm_path = csmb_normalize_rel_path(rel_path);
    struct smb2_stat_64 st;
    memset(&st, 0, sizeof(st));

    int rc = smb2_stat(session->smb2, norm_path, &st);
    if (rc < 0 && session->was_reused && csmb_classify_error(session->smb2, rc) == CSMB_ERR_CONNECTION) {
        if (csmb_reconnect_reused_session(session)) {
            memset(&st, 0, sizeof(st));
            rc = smb2_stat(session->smb2, norm_path, &st);
        } else {
            csmb_set_error(out_error_message, "SMB session reconnect failed");
            return CSMB_ERR_CONNECTION;
        }
    }
    session->was_reused = 0;

    if (rc < 0) {
        if (norm_path[0] == '\0') {
            struct smb2dir *dir = smb2_opendir(session->smb2, "");
            if (dir) {
                smb2_closedir(session->smb2, dir);
                if (out_is_directory) *out_is_directory = 1;
                if (out_size_bytes) *out_size_bytes = 0;
                if (out_modified_at_epoch) *out_modified_at_epoch = 0;
                return CSMB_OK;
            }
        }
        csmb_error_code_t code = csmb_classify_error(session->smb2, rc);
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(session->smb2));
        return code;
    }

    if (out_is_directory) {
        *out_is_directory = (st.smb2_type == SMB2_TYPE_DIRECTORY) ? 1 : 0;
    }
    if (out_size_bytes) {
        *out_size_bytes = st.smb2_size;
    }
    if (out_modified_at_epoch) {
        *out_modified_at_epoch = (int64_t)st.smb2_mtime;
    }
    return CSMB_OK;
}

csmb_error_code_t csmb_session_list_directory(
    csmb_session_t *session,
    const char *rel_path,
    csmb_dir_list_t *out_list,
    char **out_error_message
) {
    if (!session || !session->smb2 || !out_list) {
        csmb_set_error(out_error_message, "Invalid SMB session");
        return CSMB_ERR_CONNECTION;
    }
    out_list->entries = NULL;
    out_list->count = 0;

    const char *norm_path = csmb_normalize_rel_path(rel_path);
    struct smb2dir *dir = smb2_opendir(session->smb2, norm_path);
    if (!dir && session->was_reused && csmb_classify_error(session->smb2, -EIO) == CSMB_ERR_CONNECTION) {
        if (csmb_reconnect_reused_session(session)) {
            dir = smb2_opendir(session->smb2, norm_path);
        } else {
            csmb_set_error(out_error_message, "SMB session reconnect failed");
            return CSMB_ERR_CONNECTION;
        }
    }
    session->was_reused = 0;

    if (!dir) {
        csmb_error_code_t code = csmb_classify_error(session->smb2, -EIO);
        char *open_err = csmb_strdup(smb2_get_error(session->smb2));
        if (norm_path[0] != '\0' && code != CSMB_ERR_AUTH && code != CSMB_ERR_NOT_FOUND) {
            int is_dir = 0;
            csmb_error_code_t stat_code = csmb_session_stat(
                session,
                norm_path,
                &is_dir,
                NULL,
                NULL,
                NULL
            );
            if (stat_code == CSMB_OK && !is_dir) {
                free(open_err);
                csmb_set_error(out_error_message, "Target SMB path is not a directory");
                return CSMB_ERR_NOT_DIR;
            }
            if (stat_code != CSMB_OK && stat_code != CSMB_ERR_CONNECTION) {
                code = stat_code;
            }
        }
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, open_err);
        free(open_err);
        return code;
    }

    size_t capacity = 32;
    size_t count = 0;
    csmb_dir_entry_t *entries = (csmb_dir_entry_t *)calloc(capacity, sizeof(csmb_dir_entry_t));
    if (!entries) {
        smb2_closedir(session->smb2, dir);
        csmb_set_error(out_error_message, "Out of memory");
        return CSMB_ERR_CONNECTION;
    }

    struct smb2dirent *ent = NULL;
    while ((ent = smb2_readdir(session->smb2, dir)) != NULL) {
        if (!ent->name ||
            strcmp(ent->name, ".") == 0 ||
            strcmp(ent->name, "..") == 0) {
            continue;
        }

        if (count == capacity) {
            size_t new_cap = capacity * 2;
            csmb_dir_entry_t *grown = (csmb_dir_entry_t *)realloc(
                entries,
                new_cap * sizeof(csmb_dir_entry_t)
            );
            if (!grown) {
                break;
            }
            entries = grown;
            capacity = new_cap;
        }

        entries[count].name = csmb_strdup(ent->name);
        entries[count].is_directory = (ent->st.smb2_type == SMB2_TYPE_DIRECTORY) ? 1 : 0;
        entries[count].size_bytes = ent->st.smb2_size;
        entries[count].modified_at_epoch = (int64_t)ent->st.smb2_mtime;
        count++;
    }

    smb2_closedir(session->smb2, dir);
    out_list->entries = entries;
    out_list->count = count;
    return CSMB_OK;
}

void csmb_free_dir_list(csmb_dir_list_t *list) {
    if (!list || !list->entries) {
        return;
    }
    for (size_t i = 0; i < list->count; i++) {
        free(list->entries[i].name);
    }
    free(list->entries);
    list->entries = NULL;
    list->count = 0;
}

csmb_error_code_t csmb_session_read_file_range(
    csmb_session_t *session,
    const char *rel_path,
    uint64_t offset,
    uint64_t max_length,
    uint8_t **out_buffer,
    size_t *out_bytes_read,
    uint64_t *out_total_size,
    char **out_error_message
) {
    if (!session || !session->smb2) {
        csmb_set_error(out_error_message, "Invalid SMB session");
        return CSMB_ERR_CONNECTION;
    }
    if (out_buffer) *out_buffer = NULL;
    if (out_bytes_read) *out_bytes_read = 0;
    if (out_total_size) *out_total_size = 0;

    const char *norm_path = csmb_normalize_rel_path(rel_path);
    struct smb2fh *fh = smb2_open(session->smb2, norm_path, O_RDONLY);
    if (!fh && session->was_reused && csmb_classify_error(session->smb2, -EIO) == CSMB_ERR_CONNECTION) {
        if (csmb_reconnect_reused_session(session)) {
            fh = smb2_open(session->smb2, norm_path, O_RDONLY);
        } else {
            csmb_set_error(out_error_message, "SMB session reconnect failed");
            return CSMB_ERR_CONNECTION;
        }
    }
    session->was_reused = 0;

    if (!fh) {
        csmb_error_code_t code = csmb_classify_error(session->smb2, -EIO);
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(session->smb2));
        return code;
    }

    struct smb2_stat_64 st;
    memset(&st, 0, sizeof(st));
    if (smb2_fstat(session->smb2, fh, &st) < 0) {
        csmb_error_code_t code = csmb_classify_error(session->smb2, -EIO);
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(session->smb2));
        smb2_close(session->smb2, fh);
        return code;
    }

    uint64_t total_size = st.smb2_size;
    if (out_total_size) {
        *out_total_size = total_size;
    }

    if (max_length == 0 || offset >= total_size || !out_buffer) {
        smb2_close(session->smb2, fh);
        return CSMB_OK;
    }

    uint64_t available = total_size - offset;
    uint64_t to_read = (max_length < available) ? max_length : available;
    uint8_t *buffer = (uint8_t *)malloc((size_t)to_read);
    if (!buffer) {
        smb2_close(session->smb2, fh);
        csmb_set_error(out_error_message, "Out of memory");
        return CSMB_ERR_CONNECTION;
    }

    uint32_t max_chunk = smb2_get_max_read_size(session->smb2);
    if (max_chunk == 0 || max_chunk > 1048576) {
        max_chunk = 262144;
    }

    size_t total_read = 0;
    while (total_read < (size_t)to_read) {
        size_t remaining = (size_t)to_read - total_read;
        uint32_t chunk = (remaining < (size_t)max_chunk) ? (uint32_t)remaining : max_chunk;
        int n = smb2_pread(
            session->smb2,
            fh,
            buffer + total_read,
            chunk,
            offset + (uint64_t)total_read
        );
        if (n < 0) {
            csmb_error_code_t code = csmb_classify_error(session->smb2, n);
            if (code == CSMB_ERR_CONNECTION) {
                session->tainted = 1;
            }
            csmb_set_error(out_error_message, smb2_get_error(session->smb2));
            free(buffer);
            smb2_close(session->smb2, fh);
            return code;
        }
        if (n == 0) {
            break;
        }
        total_read += (size_t)n;
    }

    smb2_close(session->smb2, fh);
    *out_buffer = buffer;
    if (out_bytes_read) {
        *out_bytes_read = total_read;
    }
    return CSMB_OK;
}

csmb_error_code_t csmb_file_open(
    csmb_session_t *session,
    const char *rel_path,
    csmb_file_t **out_file,
    uint64_t *out_total_size,
    uint32_t *out_max_read_size,
    char **out_error_message
) {
    if (!session || !session->smb2 || !out_file) {
        csmb_set_error(out_error_message, "Invalid SMB session");
        return CSMB_ERR_CONNECTION;
    }
    *out_file = NULL;
    if (out_total_size) *out_total_size = 0;
    if (out_max_read_size) *out_max_read_size = 262144;

    const char *norm_path = csmb_normalize_rel_path(rel_path);
    struct smb2fh *fh = smb2_open(session->smb2, norm_path, O_RDONLY);
    if (!fh && session->was_reused && csmb_classify_error(session->smb2, -EIO) == CSMB_ERR_CONNECTION) {
        if (csmb_reconnect_reused_session(session)) {
            fh = smb2_open(session->smb2, norm_path, O_RDONLY);
        } else {
            csmb_set_error(out_error_message, "SMB session reconnect failed");
            return CSMB_ERR_CONNECTION;
        }
    }
    session->was_reused = 0;

    if (!fh) {
        csmb_error_code_t code = csmb_classify_error(session->smb2, -EIO);
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(session->smb2));
        return code;
    }

    if (out_total_size) {
        struct smb2_stat_64 st;
        memset(&st, 0, sizeof(st));
        if (smb2_fstat(session->smb2, fh, &st) < 0) {
            csmb_error_code_t code = csmb_classify_error(session->smb2, -EIO);
            if (code == CSMB_ERR_CONNECTION) {
                session->tainted = 1;
            }
            csmb_set_error(out_error_message, smb2_get_error(session->smb2));
            smb2_close(session->smb2, fh);
            return code;
        }
        *out_total_size = st.smb2_size;
    }

    csmb_file_t *file = (csmb_file_t *)calloc(1, sizeof(csmb_file_t));
    if (!file) {
        smb2_close(session->smb2, fh);
        csmb_set_error(out_error_message, "Out of memory");
        return CSMB_ERR_CONNECTION;
    }
    file->session = session;
    file->smb2 = session->smb2;
    file->fh = fh;
    *out_file = file;

    if (out_max_read_size) {
        uint32_t max_chunk = smb2_get_max_read_size(session->smb2);
        if (max_chunk == 0 || max_chunk > 1048576) {
            max_chunk = 262144;
        }
        *out_max_read_size = max_chunk;
    }
    return CSMB_OK;
}

csmb_error_code_t csmb_file_pread(
    csmb_file_t *file,
    uint64_t offset,
    uint8_t *buffer,
    uint32_t count,
    size_t *out_bytes_read,
    char **out_error_message
) {
    if (!file || !file->smb2 || !file->fh || !buffer) {
        csmb_set_error(out_error_message, "Invalid SMB file handle");
        return CSMB_ERR_CONNECTION;
    }
    if (out_bytes_read) *out_bytes_read = 0;

    int n = smb2_pread(file->smb2, file->fh, buffer, count, offset);
    if (n < 0) {
        csmb_error_code_t code = csmb_classify_error(file->smb2, n);
        if (code == CSMB_ERR_CONNECTION && file->session) {
            file->session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(file->smb2));
        return code;
    }
    if (out_bytes_read) {
        *out_bytes_read = (size_t)n;
    }
    return CSMB_OK;
}

void csmb_file_close(csmb_file_t *file) {
    if (!file) {
        return;
    }
    if (file->smb2 && file->fh) {
        smb2_close(file->smb2, file->fh);
        file->fh = NULL;
    }
    free(file);
}

csmb_error_code_t csmb_session_rename(
    csmb_session_t *session,
    const char *old_rel_path,
    const char *new_rel_path,
    char **out_error_message
) {
    if (!session || !session->smb2) {
        csmb_set_error(out_error_message, "Invalid SMB session");
        return CSMB_ERR_CONNECTION;
    }
    const char *norm_old = csmb_normalize_rel_path(old_rel_path);
    const char *norm_new = csmb_normalize_rel_path(new_rel_path);

    int rc = smb2_rename(session->smb2, norm_old, norm_new);
    if (rc < 0 && session->was_reused && csmb_classify_error(session->smb2, rc) == CSMB_ERR_CONNECTION) {
        if (csmb_reconnect_reused_session(session)) {
            rc = smb2_rename(session->smb2, norm_old, norm_new);
        } else {
            csmb_set_error(out_error_message, "SMB session reconnect failed");
            return CSMB_ERR_CONNECTION;
        }
    }
    session->was_reused = 0;

    if (rc < 0) {
        csmb_error_code_t code = csmb_classify_error(session->smb2, rc);
        if (code == CSMB_ERR_CONNECTION) {
            session->tainted = 1;
        }
        csmb_set_error(out_error_message, smb2_get_error(session->smb2));
        return code;
    }
    return CSMB_OK;
}

void csmb_free_buffer(void *ptr) {
    free(ptr);
}
