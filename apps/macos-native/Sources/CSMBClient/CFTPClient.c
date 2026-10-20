#include "CSMBClient.h"

#include <ctype.h>
#include <curl/curl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

typedef struct {
    uint8_t *data;
    size_t length;
    size_t capacity;
    size_t max_bytes;
    int stopped_at_limit;
} cftp_buffer_t;

static void cftp_set_error(char **out_error_message, const char *msg) {
    if (!out_error_message) {
        return;
    }
    *out_error_message = strdup(msg && msg[0] ? msg : "FTP operation failed");
}

static size_t cftp_write_cb(void *contents, size_t size, size_t nmemb, void *userp) {
    size_t total = size * nmemb;
    cftp_buffer_t *buf = (cftp_buffer_t *)userp;
    if (!buf || total == 0) {
        return total;
    }

    size_t to_copy = total;
    if (buf->max_bytes > 0) {
        if (buf->length >= buf->max_bytes) {
            buf->stopped_at_limit = 1;
            return 0;
        }
        size_t remaining = buf->max_bytes - buf->length;
        if (to_copy > remaining) {
            to_copy = remaining;
            buf->stopped_at_limit = 1;
        }
    }

    if (buf->length + to_copy + 1 > buf->capacity) {
        size_t new_cap = buf->capacity == 0 ? 4096 : buf->capacity * 2;
        while (new_cap < buf->length + to_copy + 1) {
            new_cap *= 2;
        }
        uint8_t *grown = (uint8_t *)realloc(buf->data, new_cap);
        if (!grown) {
            return 0;
        }
        buf->data = grown;
        buf->capacity = new_cap;
    }

    memcpy(buf->data + buf->length, contents, to_copy);
    buf->length += to_copy;
    buf->data[buf->length] = 0;

    if (buf->stopped_at_limit && to_copy < total) {
        return 0;
    }
    return total;
}

static size_t cftp_discard_cb(void *contents, size_t size, size_t nmemb, void *userp) {
    (void)contents;
    (void)userp;
    return size * nmemb;
}

static char *cftp_build_url(CURL *curl, const char *host, int port, const char *rel_path, int trailing_slash) {
    int is_ipv6 = (host && host[0] != '[' && strchr(host, ':') != NULL);
    char authority[512];
    if (is_ipv6) {
        snprintf(authority, sizeof(authority), "ftp://[%s]:%d", host, port > 0 ? port : 21);
    } else {
        snprintf(authority, sizeof(authority), "ftp://%s:%d", host ? host : "", port > 0 ? port : 21);
    }

    const char *p = rel_path ? rel_path : "";
    while (*p == '/') {
        p++;
    }

    size_t cap = strlen(authority) + strlen(p) * 3 + 8;
    char *url = (char *)malloc(cap);
    if (!url) {
        return NULL;
    }
    strcpy(url, authority);

    if (*p == '\0') {
        strcat(url, "/");
        return url;
    }

    const char *seg_start = p;
    while (*seg_start != '\0') {
        const char *slash = strchr(seg_start, '/');
        size_t seg_len = slash ? (size_t)(slash - seg_start) : strlen(seg_start);
        if (seg_len > 0) {
            strcat(url, "/");
            char *escaped = curl_easy_escape(curl, seg_start, (int)seg_len);
            if (escaped) {
                strcat(url, escaped);
                curl_free(escaped);
            }
        }
        if (!slash) {
            break;
        }
        seg_start = slash + 1;
        while (*seg_start == '/') {
            seg_start++;
        }
    }

    if (trailing_slash && url[strlen(url) - 1] != '/') {
        strcat(url, "/");
    }
    return url;
}

static struct curl_slist *cftp_configure_common(CURL *curl, const char *username, const char *password, char *errbuf) {
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 30L);
    curl_easy_setopt(curl, CURLOPT_FTP_USE_EPSV, 1L);
    if (errbuf) {
        errbuf[0] = '\0';
        curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, errbuf);
    }
    int has_user = (username && username[0] != '\0');
    int has_pass = (password && password[0] != '\0');
    curl_easy_setopt(curl, CURLOPT_USERNAME, has_user ? username : "anonymous");
    curl_easy_setopt(curl, CURLOPT_PASSWORD, (has_user || has_pass) ? (password ? password : "") : "anonymous@");

    struct curl_slist *quote = curl_slist_append(NULL, "*OPTS UTF8 ON");
    if (quote) {
        curl_easy_setopt(curl, CURLOPT_QUOTE, quote);
    }
    return quote;
}

static void cftp_cleanup_handle(CURL *curl, struct curl_slist *quote) {
    if (curl) {
        curl_easy_cleanup(curl);
    }
    if (quote) {
        curl_slist_free_all(quote);
    }
}

static csmb_error_code_t cftp_classify_curl_error(CURL *curl, CURLcode res) {
    long resp = 0;
    if (curl) {
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp);
    }
    if (res == CURLE_LOGIN_DENIED || resp == 530 || resp == 430 || resp == 331 || resp == 332) {
        return CSMB_ERR_AUTH;
    }
    if (res == CURLE_REMOTE_ACCESS_DENIED) {
        return (resp == 530) ? CSMB_ERR_AUTH : CSMB_ERR_NOT_FOUND;
    }
    if (res == CURLE_REMOTE_FILE_NOT_FOUND || resp == 550 || resp == 450) {
        return CSMB_ERR_NOT_FOUND;
    }
    return CSMB_ERR_CONNECTION;
}

static int64_t cftp_parse_mlsd_time(const char *val) {
    if (!val || strlen(val) < 14) {
        return 0;
    }
    struct tm tm_val;
    memset(&tm_val, 0, sizeof(tm_val));
    if (sscanf(val, "%4d%2d%2d%2d%2d%2d",
               &tm_val.tm_year, &tm_val.tm_mon, &tm_val.tm_mday,
               &tm_val.tm_hour, &tm_val.tm_min, &tm_val.tm_sec) != 6) {
        return 0;
    }
    tm_val.tm_year -= 1900;
    tm_val.tm_mon -= 1;
    return (int64_t)timegm(&tm_val);
}

static void cftp_append_entry(csmb_dir_list_t *list, size_t *cap, const char *name, int is_dir, uint64_t size, int64_t mtime) {
    if (!name || name[0] == '\0' || strcmp(name, ".") == 0 || strcmp(name, "..") == 0) {
        return;
    }
    if (list->count == *cap) {
        size_t new_cap = (*cap == 0) ? 32 : (*cap * 2);
        csmb_dir_entry_t *grown = (csmb_dir_entry_t *)realloc(list->entries, new_cap * sizeof(csmb_dir_entry_t));
        if (!grown) {
            return;
        }
        list->entries = grown;
        *cap = new_cap;
    }
    list->entries[list->count].name = strdup(name);
    list->entries[list->count].is_directory = is_dir;
    list->entries[list->count].size_bytes = size;
    list->entries[list->count].modified_at_epoch = mtime;
    list->count++;
}

static void cftp_parse_mlsd_listing(const char *text, csmb_dir_list_t *out_list) {
    size_t cap = 0;
    const char *line = text;
    while (line && *line) {
        const char *eol = strpbrk(line, "\r\n");
        size_t len = eol ? (size_t)(eol - line) : strlen(line);
        if (len > 0) {
            char *row = strndup(line, len);
            char *space = strchr(row, ' ');
            if (space) {
                *space = '\0';
                const char *name = space + 1;
                while (*name == ' ') name++;
                int is_dir = 0;
                int skip = 0;
                uint64_t size = 0;
                int64_t mtime = 0;
                char *saveptr = NULL;
                for (char *fact = strtok_r(row, ";", &saveptr); fact; fact = strtok_r(NULL, ";", &saveptr)) {
                    char *eq = strchr(fact, '=');
                    if (!eq) continue;
                    *eq = '\0';
                    const char *k = fact;
                    const char *v = eq + 1;
                    if (strcasecmp(k, "type") == 0) {
                        if (strcasecmp(v, "cdir") == 0 || strcasecmp(v, "pdir") == 0) {
                            skip = 1;
                        } else if (strcasecmp(v, "dir") == 0) {
                            is_dir = 1;
                        }
                    } else if (strcasecmp(k, "size") == 0 || strcasecmp(k, "sizd") == 0) {
                        size = strtoull(v, NULL, 10);
                    } else if (strcasecmp(k, "modify") == 0) {
                        mtime = cftp_parse_mlsd_time(v);
                    }
                }
                if (!skip) {
                    cftp_append_entry(out_list, &cap, name, is_dir, size, mtime);
                }
            }
            free(row);
        }
        if (!eol) break;
        line = eol + 1;
        while (*line == '\r' || *line == '\n') line++;
    }
}

static void cftp_parse_list_listing(const char *text, csmb_dir_list_t *out_list) {
    size_t cap = 0;
    const char *line = text;
    while (line && *line) {
        const char *eol = strpbrk(line, "\r\n");
        size_t len = eol ? (size_t)(eol - line) : strlen(line);
        if (len > 0) {
            char *row = strndup(line, len);
            if (strncasecmp(row, "total ", 6) != 0) {
                if (isdigit((unsigned char)row[0]) && strstr(row, "<DIR>") != NULL) {
                    char *dir_tag = strstr(row, "<DIR>");
                    const char *name = dir_tag + 5;
                    while (*name == ' ' || *name == '\t') name++;
                    cftp_append_entry(out_list, &cap, name, 1, 0, 0);
                } else {
                    int is_dir = (row[0] == 'd' || row[0] == 'D');
                    const char *p = row;
                    int tokens = 0;
                    uint64_t size = 0;
                    while (*p && tokens < 8) {
                        while (*p == ' ' || *p == '\t') p++;
                        if (!*p) break;
                        if (tokens == 4) {
                            size = strtoull(p, NULL, 10);
                        }
                        while (*p && *p != ' ' && *p != '\t') p++;
                        tokens++;
                    }
                    while (*p == ' ' || *p == '\t') p++;
                    if (tokens >= 8 && *p) {
                        char *arrow = strstr(p, " -> ");
                        if (arrow) *arrow = '\0';
                        cftp_append_entry(out_list, &cap, p, is_dir, is_dir ? 0 : size, 0);
                    }
                }
            }
            free(row);
        }
        if (!eol) break;
        line = eol + 1;
        while (*line == '\r' || *line == '\n') line++;
    }
}

csmb_error_code_t cftp_stat(
    const char *host,
    int port,
    const char *rel_path,
    const char *username,
    const char *password,
    int *out_is_directory,
    uint64_t *out_size_bytes,
    int64_t *out_modified_at_epoch,
    char **out_error_message
) {
    if (out_is_directory) *out_is_directory = 0;
    if (out_size_bytes) *out_size_bytes = 0;
    if (out_modified_at_epoch) *out_modified_at_epoch = 0;

    CURL *curl = curl_easy_init();
    if (!curl) {
        cftp_set_error(out_error_message, "Failed to initialize libcurl");
        return CSMB_ERR_CONNECTION;
    }

    char errbuf[CURL_ERROR_SIZE];
    struct curl_slist *quote = cftp_configure_common(curl, username, password, errbuf);
    curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, cftp_discard_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, cftp_discard_cb);

    const char *norm = rel_path ? rel_path : "";
    while (*norm == '/') norm++;

    char *dir_url = cftp_build_url(curl, host, port, norm, 1);
    curl_easy_setopt(curl, CURLOPT_URL, dir_url);
    CURLcode res = curl_easy_perform(curl);
    free(dir_url);

    if (res == CURLE_OK) {
        if (out_is_directory) *out_is_directory = 1;
        cftp_cleanup_handle(curl, quote);
        return CSMB_OK;
    }

    csmb_error_code_t dir_code = cftp_classify_curl_error(curl, res);
    if (norm[0] == '\0' || dir_code == CSMB_ERR_AUTH || dir_code == CSMB_ERR_CONNECTION) {
        cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
        cftp_cleanup_handle(curl, quote);
        return dir_code;
    }

    /* Not a directory; check if it is a regular file */
    char *file_url = cftp_build_url(curl, host, port, norm, 0);
    curl_easy_setopt(curl, CURLOPT_URL, file_url);
    curl_easy_setopt(curl, CURLOPT_FILETIME, 1L);
    res = curl_easy_perform(curl);
    free(file_url);

    if (res == CURLE_OK) {
        curl_off_t cl = -1;
        long ft = -1;
        curl_easy_getinfo(curl, CURLINFO_CONTENT_LENGTH_DOWNLOAD_T, &cl);
        curl_easy_getinfo(curl, CURLINFO_FILETIME, &ft);
        if (cl >= 0) {
            if (out_is_directory) *out_is_directory = 0;
            if (out_size_bytes) *out_size_bytes = (uint64_t)cl;
            if (out_modified_at_epoch) *out_modified_at_epoch = (ft > 0) ? (int64_t)ft : 0;
            cftp_cleanup_handle(curl, quote);
            return CSMB_OK;
        }
    }

    csmb_error_code_t file_code = cftp_classify_curl_error(curl, res);
    if (res == CURLE_OK) {
        file_code = CSMB_ERR_NOT_FOUND;
    }
    cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
    cftp_cleanup_handle(curl, quote);
    return file_code;
}

csmb_error_code_t cftp_list_directory(
    const char *host,
    int port,
    const char *rel_path,
    const char *username,
    const char *password,
    csmb_dir_list_t *out_list,
    char **out_error_message
) {
    if (!out_list) {
        return CSMB_ERR_CONNECTION;
    }
    out_list->entries = NULL;
    out_list->count = 0;

    CURL *curl = curl_easy_init();
    if (!curl) {
        cftp_set_error(out_error_message, "Failed to initialize libcurl");
        return CSMB_ERR_CONNECTION;
    }

    char errbuf[CURL_ERROR_SIZE];
    struct curl_slist *quote = cftp_configure_common(curl, username, password, errbuf);

    char *url = cftp_build_url(curl, host, port, rel_path, 1);
    curl_easy_setopt(curl, CURLOPT_URL, url);

    cftp_buffer_t buf;
    memset(&buf, 0, sizeof(buf));
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, cftp_write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "MLSD");

    CURLcode res = curl_easy_perform(curl);
    if (res == CURLE_OK) {
        cftp_parse_mlsd_listing(buf.data ? (const char *)buf.data : "", out_list);
        free(buf.data);
        free(url);
        cftp_cleanup_handle(curl, quote);
        return CSMB_OK;
    }

    csmb_error_code_t mlsd_code = cftp_classify_curl_error(curl, res);
    free(buf.data);
    memset(&buf, 0, sizeof(buf));

    if (mlsd_code == CSMB_ERR_AUTH) {
        cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
        free(url);
        cftp_cleanup_handle(curl, quote);
        return CSMB_ERR_AUTH;
    }

    /* Fall back to standard LIST */
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, NULL);
    curl_easy_setopt(curl, CURLOPT_DIRLISTONLY, 0L);
    res = curl_easy_perform(curl);
    free(url);

    if (res == CURLE_OK) {
        cftp_parse_list_listing(buf.data ? (const char *)buf.data : "", out_list);
        free(buf.data);
        cftp_cleanup_handle(curl, quote);
        return CSMB_OK;
    }

    csmb_error_code_t list_code = cftp_classify_curl_error(curl, res);
    free(buf.data);
    cftp_cleanup_handle(curl, quote);

    if (list_code == CSMB_ERR_NOT_FOUND && rel_path && rel_path[0] != '\0') {
        int is_dir = 0;
        if (cftp_stat(host, port, rel_path, username, password, &is_dir, NULL, NULL, NULL) == CSMB_OK && !is_dir) {
            cftp_set_error(out_error_message, "Target FTP path is not a directory");
            return CSMB_ERR_NOT_DIR;
        }
    }

    cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
    return list_code;
}

csmb_error_code_t cftp_read_file_range(
    const char *host,
    int port,
    const char *rel_path,
    uint64_t offset,
    uint64_t max_length,
    const char *username,
    const char *password,
    uint8_t **out_buffer,
    size_t *out_bytes_read,
    uint64_t *out_total_size,
    char **out_error_message
) {
    if (out_buffer) *out_buffer = NULL;
    if (out_bytes_read) *out_bytes_read = 0;
    if (out_total_size) *out_total_size = 0;

    int is_dir = 0;
    uint64_t total_size = 0;
    csmb_error_code_t st_code = cftp_stat(
        host, port, rel_path, username, password,
        &is_dir, &total_size, NULL, out_error_message
    );
    if (st_code != CSMB_OK) {
        return st_code;
    }
    if (is_dir) {
        cftp_set_error(out_error_message, "Target FTP path is a directory");
        return CSMB_ERR_NOT_DIR;
    }
    if (out_total_size) {
        *out_total_size = total_size;
    }
    if (max_length == 0 || offset >= total_size || !out_buffer) {
        return CSMB_OK;
    }

    uint64_t available = total_size - offset;
    uint64_t to_read = (max_length < available) ? max_length : available;

    CURL *curl = curl_easy_init();
    if (!curl) {
        cftp_set_error(out_error_message, "Failed to initialize libcurl");
        return CSMB_ERR_CONNECTION;
    }

    char errbuf[CURL_ERROR_SIZE];
    struct curl_slist *quote = cftp_configure_common(curl, username, password, errbuf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);

    char *url = cftp_build_url(curl, host, port, rel_path, 0);
    curl_easy_setopt(curl, CURLOPT_URL, url);

    char range_spec[64];
    snprintf(range_spec, sizeof(range_spec), "%llu-%llu",
             (unsigned long long)offset,
             (unsigned long long)(offset + to_read - 1));
    curl_easy_setopt(curl, CURLOPT_RANGE, range_spec);

    cftp_buffer_t buf;
    memset(&buf, 0, sizeof(buf));
    buf.max_bytes = (size_t)to_read;
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, cftp_write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);

    CURLcode res = curl_easy_perform(curl);
    free(url);

    if (res == CURLE_OK || (res == CURLE_WRITE_ERROR && buf.stopped_at_limit)) {
        cftp_cleanup_handle(curl, quote);
        *out_buffer = buf.data;
        if (out_bytes_read) {
            *out_bytes_read = buf.length;
        }
        return CSMB_OK;
    }

    csmb_error_code_t code = cftp_classify_curl_error(curl, res);
    cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
    free(buf.data);
    cftp_cleanup_handle(curl, quote);
    return code;
}

csmb_error_code_t cftp_rename(
    const char *host,
    int port,
    const char *old_rel_path,
    const char *new_rel_path,
    const char *username,
    const char *password,
    char **out_error_message
) {
    CURL *curl = curl_easy_init();
    if (!curl) {
        cftp_set_error(out_error_message, "Failed to initialize libcurl");
        return CSMB_ERR_CONNECTION;
    }

    char errbuf[CURL_ERROR_SIZE];
    struct curl_slist *quote = cftp_configure_common(curl, username, password, errbuf);
    curl_easy_setopt(curl, CURLOPT_NOBODY, 1L);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, cftp_discard_cb);
    curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, cftp_discard_cb);

    char *root_url = cftp_build_url(curl, host, port, "", 1);
    curl_easy_setopt(curl, CURLOPT_URL, root_url);

    const char *old_norm = old_rel_path ? old_rel_path : "";
    while (*old_norm == '/') old_norm++;
    const char *new_norm = new_rel_path ? new_rel_path : "";
    while (*new_norm == '/') new_norm++;

    size_t rnfr_len = strlen(old_norm) + 8;
    size_t rnto_len = strlen(new_norm) + 8;
    char *rnfr_cmd = (char *)malloc(rnfr_len);
    char *rnto_cmd = (char *)malloc(rnto_len);
    snprintf(rnfr_cmd, rnfr_len, "RNFR /%s", old_norm);
    snprintf(rnto_cmd, rnto_len, "RNTO /%s", new_norm);

    quote = curl_slist_append(quote, rnfr_cmd);
    quote = curl_slist_append(quote, rnto_cmd);
    curl_easy_setopt(curl, CURLOPT_QUOTE, quote);

    CURLcode res = curl_easy_perform(curl);
    free(rnfr_cmd);
    free(rnto_cmd);
    free(root_url);

    if (res == CURLE_OK) {
        cftp_cleanup_handle(curl, quote);
        return CSMB_OK;
    }

    csmb_error_code_t code = cftp_classify_curl_error(curl, res);
    if (res == CURLE_QUOTE_ERROR) {
        long resp = 0;
        curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &resp);
        if (resp == 530) {
            code = CSMB_ERR_AUTH;
        } else if (resp == 550) {
            code = CSMB_ERR_NOT_FOUND;
        }
    }
    cftp_set_error(out_error_message, errbuf[0] ? errbuf : curl_easy_strerror(res));
    cftp_cleanup_handle(curl, quote);
    return code;
}
