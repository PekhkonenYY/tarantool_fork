#!/usr/bin/env tarantool
local test = require("sqltester")
test:plan(85)

--!./tcltestrunner.lua
-- 2007 May 14
--
-- The author disclaims copyright to this source code.  In place of
-- a legal notice, here is a blessing:
--
--    May you do good and not evil.
--    May you find forgiveness for yourself and forgive others.
--    May you share freely, never taking more than you give.
--
-------------------------------------------------------------------------
-- This file implements regression tests for sql library.  The
-- focus of this file is testing the built-in SUBSTRING() function.
--

test:execsql [[
    CREATE TABLE t1(id integer primary key --autoincrement
    , t text, b SCALAR)
]]

local function substring_test(id, string, start, length, result)
    local sql = string.format([[
        DELETE FROM t1;
        INSERT INTO t1(id, t) VALUES(1, '%s')
    ]], string)

    test:execsql(sql)
    test:do_execsql_test(
        "substring-"..id..".1",
        string.format(
            "SELECT SUBSTRING(t FROM %s FOR %s) FROM t1", start, length),
        {result})

    local qstr = string
    test:do_execsql_test(
        "substring-"..id..".2",
        string.format(
            "SELECT SUBSTRING('%s' FROM %s FOR %s)", qstr, start, length),
        {result})
end

local function substring_blob_test(id, hex, start, length, hexresult)
    local sql = string.format([[
        DELETE FROM t1;
        INSERT INTO t1(id, b) VALUES(1, x'%s')
    ]], hex)

    test:execsql(sql)
    test:do_execsql_test(
        "substring-"..id..".1",
        string.format(
            "SELECT HEX(SUBSTRING(CAST(b AS VARBINARY) FROM %s FOR %s)) FROM t1",
            start, length),
        {hexresult})

    test:do_execsql_test(
        "substring-"..id..".2",
        string.format(
            "SELECT HEX(SUBSTRING(x'%s' FROM %s FOR %s))",
            hex, start, length),
        {hexresult})
end

-- Basic SUBSTRING functionality
--
substring_test("1.1", "abcdefg", "1", "1", "a")
substring_test("1.2", "abcdefg", "2", "1", "b")
substring_test("1.3", "abcdefg", "1", "2", "ab")
substring_test("1.4", "abcdefg", "1", "100", "abcdefg")
substring_test("1.5", "abcdefg", "0", "2", "a")
substring_test("1.6", "abcdefg", "-1", "1", "")
substring_test("1.7", "abcdefg", "-1", "10", "abcdefg")
substring_test("1.8", "abcdefg", "-5", "3", "")
substring_test("1.9", "abcdefg", "-7", "3", "")
substring_test("1.10", "abcdefg", "-100", "98", "")
substring_test("1.17", "abcdefg", "100", "200", "")
substring_test("1.18", "abcdefg", "200", "100", "")

-- Make sure NULL is returned if any parameter is NULL
--
test:do_test(
    "substring-1.90",
    function()
        return test:execsql(
            "SELECT IFNULL(SUBSTRING(NULL FROM 1 FOR 1), 'nil')")
    end, {
        "nil"
    })

test:do_test(
    "substring-1.91",
    function()
        return test:execsql(
            "SELECT IFNULL(SUBSTRING(NULL FROM 1), 'nil')")
    end, {
        "nil"
    })

test:do_test(
    "substring-1.92",
    function()
        return test:execsql(
            "SELECT IFNULL(SUBSTRING('abcdefg' FROM NULL FOR 1), 'nil')")
    end, {
        "nil"
    })

test:do_test(
    "substring-1.93",
    function()
        return test:execsql(
            "SELECT IFNULL(SUBSTRING('abcdefg' FROM NULL), 'nil')")
    end, {
        "nil"
    })

test:do_test(
    "substring-1.94",
    function()
        return test:execsql(
            "SELECT IFNULL(SUBSTRING('abcdefg' FROM 1 FOR NULL), 'nil')")
    end, {
        "nil"
    })

-- Make sure everything works with long unicode characters
--
substring_test("2.1", "ሴ⍅㑖", "1", "1", "ሴ")
substring_test("2.2", "ሴ⍅㑖", "2", "1", "⍅")
substring_test("2.3", "ሴ⍅㑖", "1", "2", "ሴ⍅")
substring_test("2.4", "ሴ⍅㑖", "-1", "1", "")
substring_test("2.5", "aሴb⍅c㑖c", "-5", "3", "")

-- Basic functionality for BLOBs
--
substring_blob_test("3.1", "61626364656667", "1", "1", "61")
substring_blob_test("3.2", "61626364656667", "2", "1", "62")
substring_blob_test("3.3", "61626364656667", "1", "2", "6162")
substring_blob_test("3.4", "61626364656667", "1", "100", "61626364656667")
substring_blob_test("3.5", "61626364656667", "0", "2", "61")
substring_blob_test("3.6", "61626364656667", "-1", "1", "")
substring_blob_test("3.7", "61626364656667", "-1", "10", "61626364656667")
substring_blob_test("3.8", "61626364656667", "-5", "3", "")
substring_blob_test("3.9", "61626364656667", "-7", "3", "")
substring_blob_test("3.10", "61626364656667", "-100", "98", "")
substring_blob_test("3.11", "61626364656667", "100", "200", "")
substring_blob_test("3.12", "61626364656667", "200", "100", "")

-- If these blobs were strings, then they would contain multi-byte
-- characters. But since they are blobs, the substring indices refer
-- to bytes.
--
substring_blob_test("4.1", "61E188B462E28D8563E3919663", "1", "1", "61")
substring_blob_test("4.2", "61E188B462E28D8563E3919663", "2", "1", "E1")
substring_blob_test("4.3", "61E188B462E28D8563E3919663", "1", "2", "61E1")
substring_blob_test("4.4", "61E188B462E28D8563E3919663", "-2", "1", "")
substring_blob_test("4.5", "61E188B462E28D8563E3919663", "-5", "4", "")
substring_blob_test("4.6", "61E188B462E28D8563E3919663", "-100", "98", "")

-- Two-argument SUBSTRING
--
local function substring_2_test(id, string, start, result)
    local sql = string.format([[
        DELETE FROM t1;
        INSERT INTO t1(id, t) VALUES(1, '%s')
    ]], string)

    test:execsql(sql)
    test:do_execsql_test(
        "substring-"..id..".1",
        string.format("SELECT SUBSTRING(t FROM %s) FROM t1", start),
        {result})

    local qstr = string
    test:do_execsql_test(
        "substring-"..id..".2",
        string.format("SELECT SUBSTRING('%s' FROM %s)", qstr, start),
        {result})
end

substring_2_test("5.1", "abcdefghijklmnop", "5", "efghijklmnop")
substring_2_test("5.2", "abcdef", "-5", "abcdef")

--
-- gh-4145: Make sure SUBSTRING() throws an error if the length is
-- negative.
--
test:do_catchsql_test(
    "substring-6.1",
    [[
        SELECT SUBSTRING('12345' FROM 1 FOR -1);
    ]],
    {
        1, [[Failed to execute SQL statement: ]]..
           [[Length of the result cannot be less than 0]]
    }
)

test:do_catchsql_test(
    "substring-6.2",
    [[
        SELECT SUBSTRING(x'3132333435' FROM 1 FOR -1);
    ]],
    {
        1, [[Failed to execute SQL statement: ]]..
           [[Length of the result cannot be less than 0]]
    }
)

-- gh-4145: Make sure that SUBSTRING() works according to ANSI.

--
-- Make sure SUBSTRING() returns "" if the sum of the start and length
-- arguments is 1 or less.
--
test:do_execsql_test(
    "substring-6.3",
    [[
        SELECT SUBSTRING('asdfg' FROM -10 FOR 5),
               SUBSTRING('asdfg' FROM -4 FOR 5);
    ]],
    {
        '', ''
    }
)

--
-- Make sure that if the sum of the start and length arguments is more
-- than 1 and the start argument is negative, the result starts from the
-- start of the string and length of the result will be one less than
-- the sum of the start and length arguments.
--
test:do_execsql_test(
    "substring-6.4",
    [[
        SELECT SUBSTRING('123456789' FROM -5 FOR 10);
    ]],
    {
        '1234'
    }
)

-- Make sure SUBSTRING() can work with big INTEGERs.
test:do_execsql_test(
    "substring-6.5",
    [[
        SELECT SUBSTRING('123456789' FROM -9223372036854775808
                         FOR 9223372036854775812);
    ]],
    {
        '123'
    }
)

test:do_execsql_test(
    "substring-6.6",
    [[
        SELECT SUBSTRING('123456789' FROM 0 FOR 18000000000000000000);
    ]],
    {
        '123456789'
    }
)

test:finish_test()
