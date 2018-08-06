/*
 *  Copyright (C) 2018 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to
 *  deal in the Software without restriction, including without limitation the
 *  rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 *
 *  src/tempest.h
 *  tempest
 *  Created by Masatoshi Fukunaga on 18/07/18.
 *
 */

#ifndef tempest_h
#define tempest_h

#include <assert.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <stdint.h>
#include <time.h>
#include "lauxhlib.h"


#define TEMPEST_STATS_MT    "tempest.stats"

typedef struct {
    uint64_t success;
    uint64_t failure;
    uint64_t elapsed;
    uint64_t bytes_sent;
    uint64_t bytes_recv;

    uint64_t econnect;
    uint64_t erecv;
    uint64_t erecv_timeo;
    uint64_t esend;
    uint64_t esend_timeo;
    uint64_t einternal;

    size_t len;
    uint64_t latency;
} tempest_stats_data_t;


typedef struct {
    pid_t pid;
    size_t nbyte;
    tempest_stats_data_t *data;
} tempest_stats_t;


static inline void tempest_stats_record( tempest_stats_t *s, uint64_t nsec )
{
    size_t idx = nsec / 1000 / 10;

    if( idx < s->data->len ){
        __atomic_fetch_add( &(&s->data->latency)[idx], 1, __ATOMIC_RELAXED );
    }
}


LUALIB_API int luaopen_tempest_stats( lua_State *L );


#define TEMPEST_ARRAY_MT    "tempest.array"

typedef struct {
    size_t len;
    uint32_t *data;
} tempest_array_t;


static inline void tempest_array_incr( tempest_array_t *arr, uint64_t nsec )
{
    size_t idx = nsec / 1000 / 10;

    if( idx < arr->len ){
        arr->data[idx]++;
    }
}

LUALIB_API int luaopen_tempest_array( lua_State *L );


#define TEMPEST_TIMER_MT    "tempest.timer"

typedef struct {
    int ref;
    tempest_stats_t *stats;
    uint64_t start;
    uint64_t stop;
    uint64_t ttfb;
} tempest_timer_t;


LUALIB_API int luaopen_tempest_timer( lua_State *L );


#endif
