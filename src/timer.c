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
 *  src/timer.c
 *  tempest
 *
 *  Created by Masatoshi Fukunaga on 18/07/18.
 */

#include "tempest.h"

#if defined(__APPLE__)
#include <mach/mach.h>
#include <mach/mach_time.h>

static inline uint64_t getnsec( void )
{
    static mach_timebase_info_data_t tbinfo = { 0 };

    if( tbinfo.denom == 0 ){
        (void)mach_timebase_info( &tbinfo );
    }

    return mach_absolute_time() * tbinfo.numer / tbinfo.denom;
}

#else

static inline uint64_t getnsec( void )
{
    struct timespec ts = {0};

#if defined(CLOCK_MONOTONIC_COARSE)
    clock_gettime( CLOCK_MONOTONIC_COARSE, &ts );
#else
    clock_gettime( CLOCK_MONOTONIC, &ts );
#endif

    return (uint64_t)ts.tv_sec * 1000000000 + (uint64_t)ts.tv_nsec;
}

#endif


static int stop_lua( lua_State *L )
{
    uint64_t nsec = getnsec();
    tempest_timer_t *t = lauxh_checkudata( L, 1, TEMPEST_TIMER_MT );

    if( t->start ){
        tempest_array_incr( t->arr, nsec - t->start );
        t->start = t->stop = t->ttfb = 0;
    }

    return 0;
}


static int measure_lua( lua_State *L )
{
    uint64_t nsec = getnsec();
    tempest_timer_t *t = lauxh_checkudata( L, 1, TEMPEST_TIMER_MT );

    if( t->stop ){
        t->stop = nsec;
    }
    else {
        t->stop = t->ttfb = nsec;
    }

    return 1;
}


static int start_lua( lua_State *L )
{
    tempest_timer_t *t = lauxh_checkudata( L, 1, TEMPEST_TIMER_MT );

    if( t->stop ){
        tempest_array_incr( t->arr, t->stop - t->start );
    }

    t->stop = t->ttfb = 0;
    t->start = getnsec();

    return 1;
}


static int reset_lua( lua_State *L )
{
    tempest_timer_t *t = lauxh_checkudata( L, 1, TEMPEST_TIMER_MT );

    t->start = t->stop = t->ttfb = 0;

    return 0;
}


static int tostring_lua( lua_State *L )
{
    lua_pushfstring( L, TEMPEST_TIMER_MT ": %p", lua_touserdata( L, 1 ) );
    return 1;
}


static int gc_lua( lua_State *L )
{
    tempest_timer_t *t = (tempest_timer_t*)lua_touserdata( L, 1 );

    lauxh_unref( L, t->ref );

    return 0;
}


static int new_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );
    tempest_timer_t *t = lua_newuserdata( L, sizeof( tempest_timer_t ) );

    lua_pushvalue( L, 1 );
    *t = (tempest_timer_t){
        .ref = lauxh_ref( L ),
        .arr = arr,
        .start = 0,
        .stop = 0,
        .ttfb = 0
    };
    lauxh_setmetatable( L, TEMPEST_TIMER_MT );

    return 1;
}


static int usleep_lua( lua_State *L )
{
    useconds_t usec = lauxh_checkuint64( L, 1 );

    usleep( usec );
    return 0;
}


LUALIB_API int luaopen_tempest_timer( lua_State *L )
{
    // create metatable
    if( luaL_newmetatable( L, TEMPEST_TIMER_MT ) )
    {
        struct luaL_Reg mmethod[] = {
            { "__gc", gc_lua },
            { "__tostring", tostring_lua },
            { NULL, NULL }
        };
        struct luaL_Reg method[] = {
            { "reset", reset_lua },
            { "start", start_lua },
            { "measure", measure_lua },
            { "stop", stop_lua },
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
    lua_pop( L, 1 );

    // create module table
    lua_newtable( L );
    lauxh_pushfn2tbl( L, "new", new_lua );
    lauxh_pushfn2tbl( L, "usleep", usleep_lua );

    return 1;
}

