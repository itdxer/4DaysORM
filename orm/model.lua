------------------------------------------------------------------------------
--                               Require                                    --
------------------------------------------------------------------------------

require('orm.class.global')
require("orm.tools.func")

local Table = require('orm.class.table')

------------------------------------------------------------------------------
--                                Constants                                 --
------------------------------------------------------------------------------

-- databases types
SQLITE = "sqlite3"
ORACLE = "oracle"
MYSQL = "mysql"
POSTGRESQL = "postgresql"

------------------------------------------------------------------------------
--                              Model Settings                              --
------------------------------------------------------------------------------

if not DB then
    BACKTRACE(INFO, "Can't find global database settings variable 'DB'")
    DB = {}
end

-- Set all user configs and default for database
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
    -- not sqllite db settings
    host = DB.host or nil,
    port = DB.port or nil,
    username = DB.username or nil,
    password = DB.password or nil
}

-- if DB.new then
--     BACKTRACE(INFO, "Remove old database")

--     if DB.type == SQLITE then
--         os.remove(DB.name)
--     else
--         _connect:execute('DROP DATABASE `' .. DB.name .. '`')
--     end
-- end

_G.db = require('orm.modules.luasql')

return Table