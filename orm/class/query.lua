------------------------------------------------------------------------------
--                          query.lua                                       --
------------------------------------------------------------------------------


-- Creates an instance to retrieve and manage a
-- string table with the database
---------------------------------------------------
-- @own_table {table} parent table instace
-- @data {table} data returned by the query to the database
--
-- @return {table} database query instance
---------------------------------------------------
function Query(own_table, data)
    local query = {
        ------------------------------------------------
        --          Table info varibles               --
        ------------------------------------------------

        -- Table instance
        own_table = own_table,

        -- Column data
        -- Structure example of one column
        -- fieldname = {
        --     old = nil,
        --     new = nil
        -- }
        _data = {},

        -- Data only for read mode
        _readonly = {},

        ------------------------------------------------
        --             Metamethods                    --
        ------------------------------------------------

        -- Get column value
        -----------------------------------------
        -- @colname {string} column name in table
        --
        -- @return {string|boolean|number|nil} column value
        -----------------------------------------
        _get_col = function (self, colname)
            if self._data[colname] and self._data[colname].new then
                return self._data[colname].new

            elseif self._readonly[colname] then
                return self._readonly[colname]
            end
        end,

        -- Set column new value
        -----------------------------------------
        -- @colname {string} column name in table
        -- @colvalue {string|number|boolean} new column value
        -----------------------------------------
        _set_col = function (self, colname, colvalue)
            local coltype

            if self._data[colname] and self._data[colname].new and colname ~= ID then
                coltype = self.own_table:get_column(colname)

                if coltype and coltype.field.validator(colvalue) then
                    self._data[colname].old = self._data[colname].new
                    self._data[colname].new = colvalue
                else
                    BACKTRACE(WARNING, "Not valid column value for update")
                end
            end
        end,

        ------------------------------------------------
        --             Private methods                --
        ------------------------------------------------

        -- Add new row to table
        _add = function (self)
            local insert = "INSERT INTO `" .. self.own_table.__tablename__ .. "` ("
            local counter = 0
            local values = ""
            local _connect
            local value
            local colname

            for _, table_column in pairs(self.own_table.__colnames) do
                colname = table_column.name

                if colname ~= ID then

                    -- If value exist correct value
                    if self[colname] ~= nil then
                        value = self[colname]

                        if table_column.field.validator(value) then
                            value = _G.escapeValue(self.own_table, colname, value)
                            value = table_column.field.as(value)
                        else
                            BACKTRACE(WARNING, "Wrong type for table '" ..
                                                self.own_table.__tablename__ ..
                                                "' in column '" .. tostring(colname) .. "'")
                            return false
                        end

                    -- Set default value
                    elseif table_column.settings.default then
                        value = table_column.field.as(table_column.settings.default)

                    else
                        value = "NULL"
                    end

                    colname = "`" .. colname .. "`"

                    -- TODO: save in correct type
                    if counter ~= 0 then
                        colname = ", " .. colname
                        value = ", " .. value
                    end

                    values = values .. value
                    insert = insert .. colname

                    counter = counter + 1
                end
            end

            insert = insert .. ") \n\t    VALUES (" .. values .. ")"

            -- TODO: return valid ID
            _connect = db:insert(insert)

            self._data.id = {new = _connect}
        end,

        -- Update data in database
        _update = function (self)
            local update = "UPDATE `" .. self.own_table.__tablename__ .. "` "
            local equation_for_set = {}
            local set, coltype

            for colname, colinfo in pairs(self._data) do
                if colinfo.old ~= colinfo.new and colname ~= ID then
                    coltype = self.own_table:get_column(colname)

                    if coltype and coltype.field.validator(colinfo.new) then

                        local colvalue = _G.escapeValue(self.own_table, colname, colinfo.new)
                        set = " `" .. colname .. "` = " .. coltype.field.as(colvalue)

                        table.insert(equation_for_set, set)
                    else
                        BACKTRACE(WARNING, "Can't update value for column `" ..
                                           Type.to.str(colname) .. "`")
                    end
                end
            end

            set = table.join(equation_for_set, ",")

            if set ~= "" then
                update = update .. " SET " .. set .. "\n\t    WHERE `" .. ID .. "` = " .. self.id
                db:execute(update)
            end
        end,

        ------------------------------------------------
        --             User methods                   --
        ------------------------------------------------

        -- save row
        save = function (self)
            if self.id then
                self:_update()
            else
                self:_add()
            end
        end,

        -- delete row
        delete = function (self)
            local delete, result

            if self.id then
                delete = "DELETE FROM `" .. self.own_table.__tablename__ .. "` "
                delete = delete .. "WHERE `" .. ID .. "` = " .. self.id

                db:execute(delete)
            end
            self._data = {}
        end
    }

    if data then
        local current_table

        for colname, colvalue in pairs(data) do
            if query.own_table:has_column(colname) then
                colvalue = query.own_table:get_column(colname)
                                          .field.to_type(colvalue)
                query._data[colname] = {
                    new = colvalue,
                    old = colvalue
                }
            else
                if _G.All_Tables[colname] then
                    current_table = _G.All_Tables[colname]
                    colvalue = Query(current_table, colvalue)

                    query._readonly[colname .. "_all"] = QueryList(current_table, {})
                    query._readonly[colname .. "_all"]:add(colvalue)

                end

                query._readonly[colname] = colvalue
            end
        end
    else
        BACKTRACE(INFO, "Create empty row instance for table '" ..
                        self.own_table.__tablename__ .. "'")
    end

    setmetatable(query, {__index = query._get_col,
                         __newindex = query._set_col})

    return query
end

local QueryList = require('orm.class.query_list')

return Query, QueryList