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
 *  src/array.c
 *  tempest
 *
 *  Created by Masatoshi Fukunaga on 18/07/18.
 */

#include "tempest.h"


static int merge_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );

    if( arr->data ){
        tempest_array_t *src = lauxh_checkudata( L, 2, TEMPEST_ARRAY_MT );
        size_t i = 0;

        for(; i < arr->len && i < src->len; i++ ){
            arr->data[i] += src->data[i];
        }

        lua_pushboolean( L, 1 );
    }
    else {
        lua_pushboolean( L, 0 );
    }

    return 1;
}


static int encode_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );

    if( arr->data ){
        lua_settop( L, 0 );
        lua_pushlstring( L, (char*)&arr->len, sizeof( size_t ) );
        lua_pushlstring( L, (char*)arr->data, arr->len * sizeof( uint32_t ) );
        lua_concat( L, 2 );
    }
    else {
        lua_pushnil( L );
    }

    return 1;
}


static int reset_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );

    if( arr->data ){
        memset( arr->data, 0, arr->len * sizeof( uint32_t ) );
    }

    return 0;
}


static int data_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );

    if( arr->data ){
        size_t i = 0;

        lua_createtable( L, arr->len, 0 );
        for(; i < arr->len; i++ ){
            lauxh_pushnum2arr( L, i + 1, arr->data[i] );
        }
    }
    else {
        lua_pushnil( L );
    }

    return 1;
}


static int dispose_lua( lua_State *L )
{
    tempest_array_t *arr = lauxh_checkudata( L, 1, TEMPEST_ARRAY_MT );

    if( arr->data ){
        free( (void*)arr->data );
        arr->data = NULL;
        arr->len = 0;
    }

    return 0;
}


static int len_lua( lua_State *L )
{
    tempest_array_t *arr = (tempest_array_t*)lua_touserdata( L, 1 );

    lua_pushnumber( L, arr->len );

    return 1;
}


static int tostring_lua( lua_State *L )
{
    lua_pushfstring( L, TEMPEST_ARRAY_MT ": %p", lua_touserdata( L, 1 ) );
    return 1;
}


static int gc_lua( lua_State *L )
{
    tempest_array_t *arr = (tempest_array_t*)lua_touserdata( L, 1 );

    if( arr->data ){
        free( (void*)arr->data );
    }

    return 0;
}


static int new_lua( lua_State *L )
{
    uint64_t len = (uint64_t)lauxh_checkuint8( L, 1 ) * 1000 * 10;
    tempest_array_t *arr = lua_newuserdata( L, sizeof( tempest_array_t ) );

    arr->data = calloc( len, sizeof( uint32_t ) );
    if( arr->data ){
        arr->len = len;
        lauxh_setmetatable( L, TEMPEST_ARRAY_MT );
        return 1;
    }

    lua_pushnil( L );
    lua_pushstring( L, strerror( errno ) );

    return 2;
}


static int decode_lua( lua_State *L )
{
    size_t nbyte = 0;
    const char *data = lauxh_checklstring( L, 1, &nbyte );
    tempest_array_t *arr = NULL;
    size_t len = 0;

    if( nbyte < sizeof( size_t ) ){
        lua_pushnil( L );
        return 1;
    }

    len = *(size_t*)data;
    nbyte -= sizeof( size_t );
    data += sizeof( size_t );
    if( nbyte != len * sizeof( uint32_t ) ){
        lua_pushnil( L );
        return 1;
    }

    arr = lua_newuserdata( L, sizeof( tempest_array_t ) );
    arr->len = len;
    arr->data = malloc( nbyte );
    if( arr->data ){
        memcpy( (void*)arr->data, (void*)data, nbyte );
        lauxh_setmetatable( L, TEMPEST_ARRAY_MT );
        return 1;
    }

    lua_settop( L, 0 );
    lua_pushnil( L );
    lua_pushstring( L, strerror( errno ) );

    return 2;
}


LUALIB_API int luaopen_tempest_array( lua_State *L )
{
    // create metatable
    if( luaL_newmetatable( L, TEMPEST_ARRAY_MT ) )
    {
        struct luaL_Reg mmethod[] = {
            { "__gc", gc_lua },
            { "__tostring", tostring_lua },
            { "__len", len_lua },
            { NULL, NULL }
        };
        struct luaL_Reg method[] = {
            { "dispose", dispose_lua },
            { "data", data_lua },
            { "reset", reset_lua },
            { "encode", encode_lua },
            { "merge", merge_lua },
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
    lauxh_pushfn2tbl( L, "decode", decode_lua );

    return 1;
}

