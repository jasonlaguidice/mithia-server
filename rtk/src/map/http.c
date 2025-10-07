#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <time.h>

#include "socket.h"
#include "map.h"
#include "pc.h"
#include "clif.h"

// Simple HTTP metrics endpoint for players online
// Listens on MAP_HTTP_PORT (env) or defaults to 9000

int http_listen_fd = -1;
static int http_port = 9000;
static int http_debug = 0;

static void jb_append(char **buf, size_t *cap, size_t *len, const char *s)
{
    size_t add = strlen(s);
    if (*len + add + 1 > *cap) {
        size_t ncap = (*cap == 0 ? 4096 : *cap);
        while (*len + add + 1 > ncap) ncap *= 2;
        char *nbuf = (char*)realloc(*buf, ncap);
        if (!nbuf) return;
        *buf = nbuf;
        *cap = ncap;
    }
    memcpy(*buf + *len, s, add);
    *len += add;
    (*buf)[*len] = '\0';
}

static void jb_append_quoted(char **buf, size_t *cap, size_t *len, const char *s)
{
    jb_append(buf, cap, len, "\"");
    for (const char *p = s; *p; ++p) {
        if (*len + 2 >= *cap) {
            size_t ncap = (*cap == 0 ? 4096 : *cap) * 2;
            char *nbuf = (char*)realloc(*buf, ncap);
            if (!nbuf) return;
            *buf = nbuf;
            *cap = ncap;
        }
        if (*p == '"' || *p == '\\') {
            (*buf)[(*len)++] = '\\';
            (*buf)[(*len)++] = *p;
        } else if ((unsigned char)*p < 0x20) {
            (*buf)[(*len)++] = ' ';
        } else {
            (*buf)[(*len)++] = *p;
        }
        (*buf)[*len] = '\0';
    }
    jb_append(buf, cap, len, "\"");
}

static int http_players_cb(struct block_list *bl, va_list ap)
{
    if (bl->type != BL_PC) return 0;
    USER *sd = (USER*)bl;
    char **buf = va_arg(ap, char**);
    size_t *cap = va_arg(ap, size_t*);
    size_t *len = va_arg(ap, size_t*);
    int *first = va_arg(ap, int*);
    int *count = va_arg(ap, int*);

    if (!sd) return 0;

    if (!*first) jb_append(buf, cap, len, ",");
    *first = 0;

    char tmp[64];
    jb_append(buf, cap, len, "{");

    jb_append(buf, cap, len, "\"chaId\":");
    snprintf(tmp, sizeof(tmp), "%u", sd->status.id);
    jb_append(buf, cap, len, tmp);

    jb_append(buf, cap, len, ",\"name\":");
    jb_append_quoted(buf, cap, len, sd->status.name);

    jb_append(buf, cap, len, ",\"mapId\":");
    snprintf(tmp, sizeof(tmp), "%u", sd->bl.m);
    jb_append(buf, cap, len, tmp);

    jb_append(buf, cap, len, ",\"mapName\":");
    const char *title = map_isloaded(sd->bl.m) ? (const char*)map[sd->bl.m].title : "";
    jb_append_quoted(buf, cap, len, title);

    jb_append(buf, cap, len, "}");

    (*count)++;
    return 0;
}

static void http_build_players_json(char **out, size_t *out_len)
{
    char *buf = NULL; size_t cap = 0; size_t len = 0;
    int first = 1; int count = 0;

    jb_append(&buf, &cap, &len, "{");
    // players array
    jb_append(&buf, &cap, &len, "\"players\":[");

    for (int m = 0; m < 65535; m++) {
        if (map_isloaded(m)) {
            map_foreachinarea(http_players_cb, m, 1, 1, SAMEMAP, BL_PC, &buf, &cap, &len, &first, &count);
        }
    }

    jb_append(&buf, &cap, &len, "],");

    // online count
    jb_append(&buf, &cap, &len, "\"online\":");
    char tmp[32];
    snprintf(tmp, sizeof(tmp), "%d", count);
    jb_append(&buf, &cap, &len, tmp);

    jb_append(&buf, &cap, &len, ",\"server\":");
    // serverid is declared in map.c
    extern int serverid;
    snprintf(tmp, sizeof(tmp), "%d", serverid);
    jb_append(&buf, &cap, &len, tmp);

    // timestamp
    jb_append(&buf, &cap, &len, ",\"updatedAt\":");
    time_t now = time(NULL);
    struct tm *gt = gmtime(&now);
    char iso[64];
    if (gt) {
        strftime(iso, sizeof(iso), "%Y-%m-%dT%H:%M:%SZ", gt);
    } else {
        snprintf(iso, sizeof(iso), "%ld", (long)now);
    }
    jb_append_quoted(&buf, &cap, &len, iso);

    jb_append(&buf, &cap, &len, "}");

    *out = buf;
    *out_len = len;
}

static void http_respond_json(int fd, const char *json, size_t json_len)
{
    // Write a minimal HTTP/1.1 response into the socket FIFO
    char header[256];
    int hlen = snprintf(header, sizeof(header),
        "HTTP/1.1 200 OK\r\n"
        "Content-Type: application/json\r\n"
        "Content-Length: %zu\r\n"
        "Cache-Control: no-cache, no-store, must-revalidate\r\n"
        "Pragma: no-cache\r\n"
        "Expires: 0\r\n"
        "Connection: close\r\n"
        "Access-Control-Allow-Origin: *\r\n"
        "\r\n", json_len);

    WFIFOHEAD(fd, hlen + (int)json_len);
    memcpy(WFIFOP(fd, 0), header, hlen);
    memcpy(WFIFOP(fd, hlen), json, json_len);
    WFIFOSET(fd, hlen + (int)json_len);

    // mark for close after send
    session[fd]->eof = 1;
}

static int handle_http_request(int fd)
{
    // Very simple parser for the request line
    // Debug: show available bytes
    if (http_debug) printf("HTTP parse on fd %d, bytes=%zu\n", fd, (size_t)RFIFOREST(fd));
    size_t n = RFIFOREST(fd);
    if (n < 4) return 0;

    const char *p = (const char*)RFIFOP(fd, 0);

    // Only support GET ...
    if (!(n >= 4 && p[0] == 'G' && p[1] == 'E' && p[2] == 'T' && p[3] == ' ')) {
        return 0;
    }

    // find end of request line
    const char *end = NULL;
    for (size_t i = 0; i + 1 < n; i++) {
        if (p[i] == '\r' && p[i+1] == '\n') { end = p + i; break; }
    }
    if (!end) return 0;

    // extract path token
    const char *sp1 = p + 3; // points at space before path
    while (*sp1 == ' ' && sp1 < end) sp1++;
    const char *sp2 = sp1;
    while (sp2 < end && *sp2 != ' ') sp2++;

    // Match path
    int match_players = 0;
    if ((size_t)(sp2 - sp1) >= strlen("/metrics/players") && strncmp(sp1, "/metrics/players", strlen("/metrics/players")) == 0) {
        match_players = 1;
    } else if ((size_t)(sp2 - sp1) == 1 && *sp1 == '/') {
        // allow root to also return players summary
        match_players = 1;
    }

    if (match_players) {
        char *json = NULL; size_t jlen = 0;
        http_build_players_json(&json, &jlen);
        if (!json) {
            const char *err = "{\"online\":0,\"players\":[],\"error\":\"alloc\"}";
            http_respond_json(fd, err, strlen(err));
            if (http_debug) printf("HTTP players responded: ERR len=%zu\n", strlen(err));
        } else {
            http_respond_json(fd, json, jlen);
            if (http_debug) printf("HTTP players responded: len=%zu\n", jlen);
            free(json);
        }
        // consume request
        RFIFOSKIP(fd, (int)RFIFOREST(fd));
        return 1;
    }

    // Not found response
    const char *nf = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
    WFIFOHEAD(fd, (int)strlen(nf));
    memcpy(WFIFOP(fd, 0), nf, strlen(nf));
    WFIFOSET(fd, (int)strlen(nf));
    session[fd]->eof = 1;
    RFIFOSKIP(fd, (int)RFIFOREST(fd));
    return 1;
}

int multiplex_parse(int fd)
{
    if (http_debug) printf("multiplex_parse fd=%d eof=%d r=%zu w=%zu\n", fd, session[fd]?session[fd]->eof:-1, session[fd]?session[fd]->rdata_size:0, session[fd]?session[fd]->wdata_size:0);
    if (fd < 0 || fd >= fd_max) return 0;
    if (!session[fd]) return 0;

    // If EOF set, close it (HTTP connections use this path too)
    if (session[fd]->eof) {
        // For HTTP sockets (no session_data), defer closing until all data is sent
        if (session[fd]->session_data) {
            return clif_parse(fd);
        } else {
            if (session[fd]->wdata_size == 0) session_eof(fd);
            return 0;
        }
    }

    size_t n = RFIFOREST(fd);
    if (n == 0) return 0;

    unsigned char b0 = RFIFOB(fd, 0);
    if (b0 != 0xAA) {
        // Not a game packet start; try to handle as HTTP when we have enough bytes
        if (n < 4) return 0; // wait for full method token
        (void)handle_http_request(fd);
        return 0;
    }

    // Otherwise, this is a normal game packet
    return clif_parse(fd);
}

int http_init(void)
{
    const char *env = getenv("MAP_HTTP_PORT");
    const char *dbg = getenv("MAP_HTTP_DEBUG");
    extern void register_http_listen_fd(int fd);
    if (env && *env) {
        int p = atoi(env);
        if (p > 0 && p < 65536) http_port = p;
    }
    if (dbg && *dbg && strcmp(dbg, "0") != 0) {
        http_debug = 1;
    }

    http_listen_fd = make_listen_port(http_port);
    if (http_listen_fd <= 0) {
        printf("HTTP metrics endpoint failed to bind on port %d\n", http_port);
        return 1;
    }
    register_http_listen_fd(http_listen_fd);
    printf("HTTP metrics endpoint listening on %d\n", http_port);
    return 0;
}
