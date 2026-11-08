/* Native SDK Showcase - static library round trips (zstd, lz4, sqlite from the Nexvyn sysroot). */
#include <lz4.h>
#include <sqlite3.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zstd.h>

#define N 65536

static void fill(unsigned char* p) {
    for (int i = 0; i < N; i++) p[i] = (unsigned char)((i * 7) ^ (i >> 5) ^ ((i / 97) * 13));
}

int sc_zstd(char* msg, size_t n) {
    unsigned char* src = malloc(N);
    unsigned char* back = malloc(N);
    size_t cap = ZSTD_compressBound(N);
    void* comp = malloc(cap);
    int ok = 0;
    if (src && back && comp) {
        fill(src);
        size_t c = ZSTD_compress(comp, cap, src, N, 3);
        if (ZSTD_isError(c)) {
            snprintf(msg, n, "compress: %s", ZSTD_getErrorName(c));
        } else {
            size_t d = ZSTD_decompress(back, N, comp, c);
            ok = !ZSTD_isError(d) && d == N && memcmp(src, back, N) == 0;
            snprintf(msg, n, "zstd %s: %d -> %zu bytes, round trip %s", ZSTD_versionString(), N, c, ok ? "equal" : "DIFFERS");
        }
    } else {
        snprintf(msg, n, "out of memory");
    }
    free(src);
    free(back);
    free(comp);
    return ok;
}

int sc_lz4(char* msg, size_t n) {
    unsigned char* src = malloc(N);
    unsigned char* back = malloc(N);
    int cap = LZ4_compressBound(N);
    char* comp = malloc((size_t)cap);
    int ok = 0;
    if (src && back && comp) {
        fill(src);
        int c = LZ4_compress_default((const char*)src, comp, N, cap);
        int d = c > 0 ? LZ4_decompress_safe(comp, (char*)back, c, N) : -1;
        ok = c > 0 && d == N && memcmp(src, back, N) == 0;
        snprintf(msg, n, "lz4 %s: %d -> %d bytes, decoded %d, round trip %s", LZ4_versionString(), N, c, d, ok ? "equal" : "FAILED");
    } else {
        snprintf(msg, n, "out of memory");
    }
    free(src);
    free(back);
    free(comp);
    return ok;
}

int sc_sqlite(char* msg, size_t n) {
    sqlite3* db = NULL;
    int ok = 0;
    if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
        snprintf(msg, n, "open: %s", db ? sqlite3_errmsg(db) : "no handle");
        sqlite3_close(db);
        return 0;
    }
    char* err = NULL;
    int rc = sqlite3_exec(db, "CREATE TABLE t(a INTEGER, b TEXT);", NULL, NULL, &err);
    if (rc == SQLITE_OK) rc = sqlite3_exec(db, "BEGIN;", NULL, NULL, &err);
    for (int i = 1; rc == SQLITE_OK && i <= 100; i++) {
        char sql[96];
        snprintf(sql, sizeof sql, "INSERT INTO t VALUES(%d,'row %d');", i, i);
        rc = sqlite3_exec(db, sql, NULL, NULL, &err);
    }
    if (rc == SQLITE_OK) rc = sqlite3_exec(db, "COMMIT;", NULL, NULL, &err);
    if (rc == SQLITE_OK) {
        sqlite3_stmt* st = NULL;
        if (sqlite3_prepare_v2(db, "SELECT sum(a), count(*) FROM t;", -1, &st, NULL) == SQLITE_OK && sqlite3_step(st) == SQLITE_ROW) {
            long long sum = sqlite3_column_int64(st, 0);
            int cnt = sqlite3_column_int(st, 1);
            ok = sum == 5050 && cnt == 100;
            snprintf(msg, n, "sqlite %s: %d rows, sum %lld (%s)", sqlite3_libversion(), cnt, sum, ok ? "as expected" : "UNEXPECTED");
        } else {
            snprintf(msg, n, "select: %s", sqlite3_errmsg(db));
        }
        sqlite3_finalize(st);
    } else {
        snprintf(msg, n, "sql: %s", err ? err : sqlite3_errmsg(db));
    }
    sqlite3_free(err);
    sqlite3_close(db);
    return ok;
}
