/*
 *  Copyright (C) 2018 Masatoshi Fukunaga
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 *
 *  src/stats.c
 *  tempest
 *
 *  Created by Masatoshi Fukunaga on 18/07/27.
 */

#include "tempest.h"
#include <sys/mman.h>
#include <math.h>


#define tempest_stats_add(field) do{ \
    tempest_stats_t *s = lauxh_checkudata( L, 1, TEMPEST_STATS_MT ); \
    uint64_t v = (uint64_t)lauxh_checkuint64( L, 2 ); \
    __atomic_fetch_add( &(s->data->field), v, __ATOMIC_RELAXED ); \
    return 0; \
}while(0)


#define tempest_stats_incr(field) do{ \
    tempest_stats_t *s = lauxh_checkudata( L, 1, TEMPEST_STATS_MT ); \
    __atomic_fetch_add( &(s->data->field), 1, __ATOMIC_RELAXED ); \
    return 0; \
}while(0)


static int incr_einternal_lua( lua_State *L ){
    tempest_stats_incr( einternal );
}
static int incr_esend_timeo_lua( lua_State *L ){
    tempest_stats_incr( esend_timeo );
}
static int incr_esend_lua( lua_State *L ){
    tempest_stats_incr( esend );
}
static int incr_erecv_timeo_lua( lua_State *L ){
    tempest_stats_incr( erecv_timeo );
}
static int incr_erecv_lua( lua_State *L ){
    tempest_stats_incr( erecv );
}
static int incr_econnect_lua( lua_State *L ){
    tempest_stats_incr( econnect );
}
static int add_bytes_recv_lua( lua_State *L ){
    tempest_stats_add( bytes_recv );
}
static int add_bytes_sent_lua( lua_State *L ){
    tempest_stats_add( bytes_sent );
}
static int incr_failure_lua( lua_State *L ){
    tempest_stats_incr( failure );
}
static int incr_success_lua( lua_State *L ){
    tempest_stats_incr( success );
}


static int data_lua( lua_State *L )
{
    tempest_stats_t *s = lauxh_checkudata( L, 1, TEMPEST_STATS_MT );

    if( s->pid != getpid() || !s->data ){
        lua_pushnil( L );
    }
    else
    {
        tempest_stats_data_t *data = s->data;
        uint64_t *latency = &data->latency;
        int idx_msec = 0;
        int idx_mgrp = 0;
        int idx_nreq = 0;
        double msecf = 0.0;
        double prev_msec = 0.0;
        double prev_msecf = 0.0;
        uint64_t nreqs = 0;
        uint64_t min_nreq = UINT64_MAX;
        uint64_t max_nreq = 0;
        size_t avg = 0;
        size_t i = 0;
        size_t k = 0;
        size_t g = 0;

        lua_settop( L, 0 );
        lua_createtable( L, 0, 12 );
        lauxh_pushnum2tbl( L, "success", data->success );
        lauxh_pushnum2tbl( L, "failure", data->failure );
        lauxh_pushnum2tbl( L, "bytesSent", data->bytes_sent );
        lauxh_pushnum2tbl( L, "bytesRecv", data->bytes_recv );
        lauxh_pushnum2tbl( L, "econnect", data->econnect );
        lauxh_pushnum2tbl( L, "erecv", data->erecv );
        lauxh_pushnum2tbl( L, "erecvTimeo", data->erecv_timeo );
        lauxh_pushnum2tbl( L, "esend", data->esend );
        lauxh_pushnum2tbl( L, "esendTimeo", data->esend_timeo );
        lauxh_pushnum2tbl( L, "einternal", data->einternal );

        lua_pushliteral( L, "latency_msec_grp" );
        lua_newtable( L );
        idx_mgrp = lua_gettop( L );
        lua_pushliteral( L, "latency_msec" );
        lua_newtable( L );
        idx_msec = lua_gettop( L );
        lua_pushliteral( L, "latency_nreq" );
        lua_newtable( L );
        idx_nreq = lua_gettop( L );
        for(; i < data->len; i++ )
        {
            if( latency[i] )
            {
                uint64_t nreq = latency[i];
                double msec = (double)i / 100;

                msecf = floor( msec );
                k++;
                avg += i;
                lauxh_pushnum2arrat( L, k, msec, idx_msec );
                lauxh_pushnum2arrat( L, k, nreq, idx_nreq );
                if( min_nreq > nreq ){
                    min_nreq = nreq;
                }
                if( max_nreq < nreq ){
                    max_nreq = nreq;
                }

                // grouping by integer msec
                if( g == 0 ){
                    g = 1;
                    nreqs = nreq;
                    prev_msecf = msecf;
                    lua_newtable( L );
                    lauxh_pushnum2tbl( L, "msec", msecf );
                    lauxh_pushnum2tbl( L, "min", msec );
                }
                else if( msecf != prev_msecf ){
                    lauxh_pushnum2tbl( L, "max", prev_msec );
                    lauxh_pushnum2tbl( L, "nreq", nreqs );
                    lua_rawseti( L, idx_mgrp, g );

                    g++;
                    prev_msecf = msecf;
                    nreqs = nreq;
                    lua_newtable( L );
                    lauxh_pushnum2tbl( L, "msec", msecf );
                    lauxh_pushnum2tbl( L, "min", msec );
                }
                else {
                    nreqs += nreq;
                }
                prev_msec = msec;
            }
        }

        if( g ){
            lauxh_pushnum2tbl( L, "max", prev_msec );
            lauxh_pushnum2tbl( L, "nreq", nreqs );
            lua_rawseti( L, idx_mgrp, g );
        }
        lauxh_pushnum2tblat( L, "avg", (double)avg / (double)k / 100.0, idx_msec );
        lauxh_pushnum2tblat( L, "min", min_nreq, idx_nreq );
        lauxh_pushnum2tblat( L, "max", max_nreq, idx_nreq );
        lua_rawset( L, 1 );
        lua_rawset( L, 1 );
        lua_rawset( L, 1 );
    }

    return 1;
}


static int reset_lua( lua_State *L )
{
    tempest_stats_t *s = lauxh_checkudata( L, 1, TEMPEST_STATS_MT );

    if( s->data ){
        memset( (void*)s->data, 0, s->nbyte );
    }

    return 0;
}


static int dispose_lua( lua_State *L )
{
    tempest_stats_t *s = lauxh_checkudata( L, 1, TEMPEST_STATS_MT );

    if( s->data && s->pid == getpid() ){
        munmap( (void*)s->data, s->nbyte );
        s->data = NULL;
    }

    return 0;
}


static int len_lua( lua_State *L )
{
    tempest_stats_t *s = (tempest_stats_t*)lua_touserdata( L, 1 );

    lua_pushnumber( L, s->nbyte );

    return 1;
}


static int tostring_lua( lua_State *L )
{
    lua_pushfstring( L, TEMPEST_STATS_MT ": %p", lua_touserdata( L, 1 ) );
    return 1;
}


static int gc_lua( lua_State *L )
{
    tempest_stats_t *s = (tempest_stats_t*)lua_touserdata( L, 1 );

    if( s->data && s->pid == getpid() ){
        munmap( (void*)s->data, s->nbyte );
    }

    return 0;
}


static int new_lua( lua_State *L )
{
    uint32_t msec = lauxh_checkuint32( L, 1 );
    size_t len = (size_t)msec * 100;
    tempest_stats_t *s = lua_newuserdata( L, sizeof( tempest_stats_t ) );

    memset( (void*)s, 0, sizeof( tempest_stats_t ) );
    s->nbyte = sizeof( uint64_t ) * len + sizeof( tempest_stats_data_t );
    s->data = (tempest_stats_data_t*)mmap( NULL, s->nbyte, PROT_READ|PROT_WRITE,
                                          MAP_ANONYMOUS|MAP_SHARED, -1, 0 );
    if( s->data ){
        memset( (void*)s->data, 0, s->nbyte );
        s->data->len = len;
        s->pid = getpid();
        lauxh_setmetatable( L, TEMPEST_STATS_MT );
        return 1;
    }

    lua_pushnil( L );
    lua_pushstring( L, strerror( errno ) );

    return 2;
}


LUALIB_API int luaopen_tempest_stats( lua_State *L )
{
    // create metatable
    if( luaL_newmetatable( L, TEMPEST_STATS_MT ) )
    {
        struct luaL_Reg mmethod[] = {
            { "__gc", gc_lua },
            { "__tostring", tostring_lua },
            { "__len", len_lua },
            { NULL, NULL }
        };
        struct luaL_Reg method[] = {
            { "dispose", dispose_lua },
            { "reset", reset_lua },
            { "data", data_lua },
            // stat
            { "incrSuccess", incr_success_lua },
            { "incrFailure", incr_failure_lua },
            { "addBytesSent", add_bytes_sent_lua },
            { "addBytesRecv", add_bytes_recv_lua },
            { "incrEConnect", incr_econnect_lua },
            { "incrERecv", incr_erecv_lua },
            { "incrERecvTimeo", incr_erecv_timeo_lua },
            { "incrESend", incr_esend_lua },
            { "incrESendTimeo", incr_esend_timeo_lua },
            { "incrEInternal", incr_einternal_lua },
            { NULL, NULL }
        };
        struct luaL_Reg *ptr = mmethod;

        // metamethods
        do {
            lauxh_pushfn2tbl( L, ptr->name, ptr->func );
            ptr++;
        } while( ptr->name );
        // methods
        lua_pushstring( L, "__index" );
        lua_newtable( L );
        ptr = method;
        do {
            lauxh_pushfn2tbl( L, ptr->name, ptr->func );
            ptr++;
        } while( ptr->name );
        lua_rawset( L, -3 );
    }
    lua_settop( L, 0 );

    // create module table
    lua_newtable( L );
    lauxh_pushfn2tbl( L, "new", new_lua );

    return 1;
}

