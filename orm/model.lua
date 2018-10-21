------------------------------------------------------------------------------
--                               Require                                    --
------------------------------------------------------------------------------

require('orm.class.global')
require("orm.tools.func")

local Table = require('orm.class.table')

------------------------------------------------------------------------------
--                                Constants                                 --
------------------------------------------------------------------------------
-- Global
ID = "id"
AGGREGATOR = "aggregator"
QUERY_LIST = "query_list"

-- databases types
SQLITE = "sqlite3"
ORACLE = "oracle"
MYSQL = "mysql"
POSTGRESQL = "postgresql"

------------------------------------------------------------------------------
--                              Model Settings                              --
------------------------------------------------------------------------------

if not DB then
    print("[SQL:Startup] Can't find global database settings variable 'DB'. Creating empty one.")
    DB = {}
end

DB = {
    -- ORM settings
    new = (DB.new == true),
    DEBUG = (DB.DEBUG == true),
    backtrace = (DB.backtrace == true),
    -- database settings
    type = DB.type or "sqlite3",
    -- if you use sqlite set database path value
    -- if not set a database name
    name = DB.name or "database.db",
    -- not sqlite db settings
    host = DB.host or nil,
    port = DB.port or nil,
    username = DB.username or nil,
    password = DB.password or nil
}

local sql, _connect

-- Get database by settings
if DB.type == SQLITE then
    local luasql = require("luasql.sqlite3")
    sql = luasql.sqlite3()
    _connect = sql:connect(DB.name)

elseif DB.type == MYSQL then
    local luasql = require("luasql.mysql")
    sql = luasql.mysql()
    print(DB.name, DB.username, DB.password, DB.host, DB.port)
    _connect = sql:connect(DB.name, DB.username, DB.password, DB.host, DB.port)

elseif DB.type == POSTGRESQL then
    local luasql = require("luasql.postgres")
    sql = luasql.postgres()
    print(DB.name, DB.username, DB.password, DB.host, DB.port)
    _connect = sql:connect(DB.name, DB.username, DB.password, DB.host, DB.port)

else
    BACKTRACE(ERROR, "Database type not suported '" .. tostring(DB.type) .. "'")
end

if not _connect then
    BACKTRACE(ERROR, "Connect problem!")
end

-- if DB.new then
--     BACKTRACE(INFO, "Remove old database")

--     if DB.type == SQLITE then
--         os.remove(DB.name)
--     else
--         _connect:execute('DROP DATABASE `' .. DB.name .. '`')
--     end
-- end

------------------------------------------------------------------------------
--                               Database                                   --
------------------------------------------------------------------------------

-- Database settings
db = {
    -- Database connect instance
    connect = _connect,

    -- Execute SQL query
    execute = function (self, query)
        BACKTRACE(DEBUG, query)

        local result = self.connect:execute(query)

        if result then
            return result
        else
            BACKTRACE(WARNING, "Wrong SQL query")
        end
    end,

    -- Return insert query id
    insert = function (self, query)
        local _cursor = self:execute(query)
        return 1
    end,

    -- get parced data
    rows = function (self, query, own_table)
        local _cursor = self:execute(query)
        local data = {}
        local current_row = {}
        local current_table
        local row

        if _cursor then
            row = _cursor:fetch({}, "a")

            while row do
                for colname, value in pairs(row) do
                    current_table, colname = string.divided_into(colname, "_")

                    if current_table == own_table.__tablename__ then
                        current_row[colname] = value
                    else
                        if not current_row[current_table] then
                            current_row[current_table] = {}
                        end

                        current_row[current_table][colname] = value
                    end
                end

                table.insert(data, current_row)

                current_row = {}
                row = _cursor:fetch({}, "a")
            end

        end

        return data
    end
}

return Table
