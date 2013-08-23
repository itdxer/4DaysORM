local sql, _connect

-- Get database by settings
if DB.type == SQLITE then
    require("luasql.sqlite3")
    sql = luasql.sqlite3()
    _connect = sql:connect(DB.name)

elseif DB.type == MYSQL then
    require("luasql.mysql")
    sql = luasql.mysql()
    _connect = sql:connect(DB.name, DB.username, DB.password, DB.host, DB.port)

elseif DB.type == POSTGRESQL then
    require("luasql.postgres")
    sql = luasql.postgres()
    _connect = sql:connect(DB.name, DB.username, DB.password, DB.host, DB.port)

else
    BACKTRACE(ERROR, "Database type not suported '" .. tostring(DB.type) .. "'")
end

if not _connect then
    BACKTRACE(ERROR, "Connect problem!")
end

------------------------------------------------------------------------------
--                               Database                                   --
------------------------------------------------------------------------------

-- Database settings
db = {
    -- Satabase connect instance
    connect = _connect,

    -- Execute SQL query
    execute = function (self, query)

        if not TRANSACTION.MODE then
            BACKTRACE(DEBUG, query)

            local result = self.connect:execute(query)

            if result then
                return result
            else
                BACKTRACE(WARNING, "Wrong SQL query")
            end
        else
            table.insert(TRANSACTION._STACK, query)
        end
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

return db