------------------------------------------------------------------------------
--                                Constants                                 --
------------------------------------------------------------------------------

-- For WHERE equations ends
local LESS_THEN = "__lt"
local EQ_OR_LESS_THEN = "__lte"
local MORE_THEN = "__gt"
local EQ_OR_MORE_THEN = "__gte"
local IN = "__in"
local NOT_IN = "__notin"
local IS_NULL = '__null'

-- Joining types
local JOIN = {
    INNER = 'i',
    LEFT = 'l',
    RIGHT = 'r',
    FULL = 'f'
}

------------------------------------------------------------------------------
--                                  Class                                   --
------------------------------------------------------------------------------

local Select = function(own_table)
    return {
        ------------------------------------------------
        --          Table info varibles               --
        ------------------------------------------------
        -- Link for table instance
        own_table = own_table,

        -- Create select rules
        _rules = {
            -- Where equation rules
            where = {},
            -- Having equation rules
            having = {},
            -- limit
            limit = nil,
            -- offset
            offset = nil,
            -- order columns list
            order = {},
            -- group columns list
            group = {},
            --Columns rules
            columns = {
                -- Joining tables rules
                join = {},
                -- including columns list
                include = {},
            }
        },

        ------------------------------------------------
        --          Private methods                   --
        ------------------------------------------------

        -- Build correctly equation for SQL searching
        _build_equation = function (self, colname, value)
            local result = ""
            local table_column
            local rule
            local _in

            -- Special conditions that need no value escaping
            if colname:endswith(IS_NULL) then
                colname = string.cutend(colname, IS_NULL)

                if value then
                    result = " IS NULL"
                else
                    result = " NOT NULL"
                end

            elseif colname:endswith(IN) or colname:endswith(NOT_IN) then
                rule = colname:endswith(IN) and IN or NOT_IN

                if type(value) == "table" and #value > 0 then
                    colname = string.cutend(colname, rule)
                    table_column = self.own_table:get_column(colname)
                    _in = {}

                    for counter, val in pairs(value) do
                        table.insert(_in, table_column.field.as(val))
                    end

                    if rule == IN then
                        result = " IN (" .. table.join(_in) .. ")"
                    elseif rule == NOT_IN then
                        result = " NOT IN (" .. table.join(_in) .. ")"
                    end

                end

            else

                -- Conditions that need value escaping when it's enabled
                local conditionPrepend = ""

                if colname:endswith(LESS_THEN) and Type.is.number(value) then
                    colname = string.cutend(colname, LESS_THEN)
                    conditionPrepend = " < "

                elseif colname:endswith(MORE_THEN) and Type.is.number(value) then
                    colname = string.cutend(colname, MORE_THEN)
                    conditionPrepend = " > "

                elseif colname:endswith(EQ_OR_LESS_THEN) and Type.is.number(value) then
                    colname = string.cutend(colname, EQ_OR_LESS_THEN)
                    conditionPrepend = " <= "

                elseif colname:endswith(EQ_OR_MORE_THEN) and Type.is.number(value) then
                    colname = string.cutend(colname, EQ_OR_MORE_THEN)
                    conditionPrepend = " >= "

                else
                    conditionPrepend = " = "
                end

                value = _G.escapeValue(self.own_table, colname, value)
                table_column = self.own_table:get_column(colname)
                result = conditionPrepend .. table_column.field.as(value)

            end

            if self.own_table:has_column(colname) then
                local parse_column, _ = self.own_table:column(colname)
                result = parse_column .. result
            end

            return result
        end,

        -- Need for ASC and DESC columns
        _update_col_names = function (self, list_of_cols)
            local tablename = self.own_table.__tablename__
            local result = {}
            local parsed_column

            for _, col in pairs(list_of_cols) do
                if Type.is.table(col) and col.__classtype__ == AGGREGATOR then
                    col.__table__ = self.own_table.__tablename__
                    table.insert(result, col)

                else
                    parsed_column, _ = self.own_table:column(col)
                    table.insert(result, parsed_column)
                end
            end

            return result
        end,

        -- Build condition for equation rules
        ---------------------------------------------------
        -- @rules {table} list of columns
        -- @start_with {string} WHERE or HAVING
        --
        -- @retrun {string} parsed string for select equation
        ---------------------------------------------------
        _condition = function (self, rules, start_with)
            local counter = 0
            local condition = ""
            local _equation

            condition = condition .. start_with

            -- TODO: add OR
            for colname, value in pairs(rules) do
                _equation = self:_build_equation(colname, value)

                if counter ~= 0 then
                     _equation = "AND " .. _equation
                end

                condition = condition .. " " .. _equation
                counter = counter + 1
            end

            return condition
        end,

        _has_foreign_key_table = function (self, left_table, right_table)
            for _, key in pairs(left_table.__foreign_keys) do
                if key.settings.to == right_table then
                    return true
                end
            end
        end,

        -- Build join tables rules
        _build_join = function (self)
            local result_join = ""
            local unique_tables = {}
            local left_table, right_table, mode
            local join_mode, colname
            local parsed_column, _
            local tablename

            for _, value in pairs(self._rules.columns.join) do
                left_table = value[1]
                right_table = value[2]
                mode = value[3]
                tablename = left_table.__tablename__

                if mode == JOIN.INNER then
                    join_mode = "INNER JOIN"

                elseif mode == JOIN.LEFT then
                    join_mode = "LEFT OUTER JOIN"

                elseif mode == JOIN.RIGHT then
                    join_mode = "RIGHT OUTER JOIN"

                elseif mode == JOIN.FULL then
                    join_mode = "FULL OUTER JOIN"

                else
                    BACKTRACE(WARNING, "Not valid join mode " .. mode)
                end

                if self:_has_foreign_key_table(right_table, left_table) then
                    left_table, right_table = right_table, left_table
                    tablename = right_table.__tablename__

                elseif not self:_has_foreign_key_table(right_table, left_table) then
                    BACKTRACE(WARNING, "Not valid tables links")
                end

                for _, key in pairs(left_table.__foreign_keys) do
                    if key.settings.to == right_table then
                        colname = key.name

                        result_join = result_join .. " \n" .. join_mode .. " `" ..
                                      tablename .. "` ON "

                        parsed_column, _ = left_table:column(colname)
                        result_join = result_join .. parsed_column

                        parsed_column, _ = right_table:column(ID)
                        result_join = result_join .. " = " .. parsed_column

                        break
                    end
                end
            end

            return result_join
        end,

        -- String with including data in select
        --------------------------------------------
        -- @own_table {table|nil} Table instance
        --
        -- @return {string} comma separated fields
        --------------------------------------------
        _build_including = function (self, own_table)
            local include = {}
            local colname_as, colname

            if not own_table then
                own_table = self.own_table
            end

            -- get current column
            for _, column in pairs(own_table.__colnames) do
                colname, colname_as = own_table:column(column.name)
                table.insert(include, colname .. " AS " .. colname_as)
            end

            include = table.join(include)

            return include
        end,

        -- Method for build select with rules
        _select = function (self)
            local including = self:_build_including()
            local joining = ""
            local _select
            local tablename
            local condition
            local where
            local rule
            local join

            --------------------- Include Columns To Select ------------------
            _select = "SELECT " .. including

            -- Add join rules
            if #self._rules.columns.join > 0 then
                local unique_tables = { self.own_table }
                local join_tables = {}
                local left_table, right_table

                for _, values in pairs(self._rules.columns.join) do
                    left_table = values[1]
                    right_table = values[2]

                    if not table.has_value(unique_tables, left_table) then
                        table.insert(unique_tables, left_table)
                        _select = _select .. ", " .. self:_build_including(left_table)
                    end

                    if not table.has_value(unique_tables, right_table) then
                        table.insert(unique_tables, right_table)
                        _select = _select .. ", " .. self:_build_including(right_table)
                    end
                end

                join = self:_build_join()
            end

            -- Check aggregators in select
            if #self._rules.columns.include > 0 then
                local aggregators = {}
                local aggregator, as

                for _, value in pairs(self._rules.columns.include) do
                    _, as = own_table:column(value.as)
                    table.insert(aggregators, value[1] .. " AS " .. as)
                end

                _select = _select .. ", " .. table.join(aggregators)
            end
            ------------------- End Include Columns To Select ----------------

            _select = _select .. " FROM `" .. self.own_table.__tablename__ .. "`"

            if join then
                _select = _select .. " " .. join
            end

            -- Build WHERE
            if next(self._rules.where) then
                condition = self:_condition(self._rules.where, "\nWHERE")
                _select = _select .. " " .. condition
            end

            -- Build GROUP BY
            if #self._rules.group > 0 then
                rule = self:_update_col_names(self._rules.group)
                rule = table.join(rule)
                _select = _select .. " \nGROUP BY " .. rule
            end

            -- Build HAVING
            if next(self._rules.having) and self._rules.group then
                condition = self:_condition(self._rules.having, "\nHAVING")
                _select = _select .. " " .. condition
            end

            -- Build ORDER BY
            if #self._rules.order > 0 then
                rule = self:_update_col_names(self._rules.order)
                rule = table.join(rule)
                _select = _select .. " \nORDER BY " .. rule
            end

            -- Build LIMIT
            if self._rules.limit then
                _select = _select .. " \nLIMIT " .. self._rules.limit
            end

            -- Build OFFSET
            if self._rules.offset then
                _select = _select .. " \nOFFSET " .. self._rules.offset
            end

            return db:rows(_select, self.own_table)
        end,

        -- Add column to table
        -------------------------------------------------
        -- @col_table {table} table with column names
        -- @colname {string/table} column name or list of column names
        -------------------------------------------------
        _add_col_to_table = function (self, col_table, colname)
            if Type.is.str(colname) and self.own_table:has_column(colname) then
                table.insert(col_table, colname)

            elseif Type.is.table(colname) then
                for _, column in pairs(colname) do
                    if (Type.is.table(column) and column.__classtype__ == AGGREGATOR
                    and self.own_table:has_column(column.colname))
                    or self.own_table:has_column(column) then
                        table.insert(col_table, column)
                    end
                end

            else
                BACKTRACE(WARNING, "Not a string and not a table (" ..
                                   tostring(colname) .. ")")
            end
        end,

        --------------------------------------------------------
        --                   Column filters                   --
        --------------------------------------------------------

        -- Including columns to select query
        include = function (self, column_list)
            if Type.is.table(column_list) then
                for _, value in pairs(column_list) do
                    if Type.is.table(value) and value.as and value[1]
                    and value[1].__classtype__ == AGGREGATOR then
                        table.insert(self._rules.columns.include, value)
                    else
                        BACKTRACE(WARNING, "Not valid aggregator syntax")
                    end
                end
            else
                BACKTRACE(WARNING, "You can include only table type data")
            end

            return self
        end,

        --------------------------------------------------------
        --              Joining tables methods                --
        --------------------------------------------------------

        -- By default, join is INNER JOIN command
        _join = function (self, left_table, MODE, right_table)
            if not right_table then
                right_table = self.own_table
            end

            if left_table.__tablename__ then
                table.insert(self._rules.columns.join,
                            {left_table, right_table, MODE})
            else
                BACKTRACE(WARNING, "Not table in join")
            end

            return self
        end,

        join = function (self, left_table, right_table)
            self:_join(left_table, JOIN.INNER, right_table)
            return self
        end,

        -- left outer joining command
        left_join = function (self, left_table, right_table)
            self:_join(left_table, JOIN.LEFT, right_table)
            return self
        end,

        -- right outer joining command
        right_join = function (self, left_table, right_table)
            self:_join(left_table, JOIN.RIGHT, right_table)
            return self
        end,

        -- full outer joining command
        full_join = function (self, left_table, right_table)
            self:_join(left_table, JOIN.FULL, right_table)
            return self
        end,

        --------------------------------------------------------
        --              Select building methods               --
        --------------------------------------------------------

        -- SQL Where query rules
        where = function (self, args)
            for col, value in pairs(args) do
                self._rules.where[col] = value
            end

            return self
        end,

        -- Set returned data limit
        limit = function (self, count)
            if Type.is.int(count) then
                self._rules.limit = count
            else
                BACKTRACE(WARNING, "You try set limit to not integer value")
            end

            return self
        end,

        -- From which position start get data
        offset = function (self, count)
            if Type.is.int(count) then
                self._rules.offset = count
            else
                BACKTRACE(WARNING, "You try set offset to not integer value")
            end

            return self
        end,

        -- Order table
        order_by = function (self, colname)
            self:_add_col_to_table(self._rules.order, colname)
            return self
        end,

        -- Group table
        group_by = function (self, colname)
            self:_add_col_to_table(self._rules.group, colname)
            return self
        end,

        -- Having
        having = function (self, args)
            for col, value in pairs(args) do
                self._rules.having[col] = value
            end

            return self
        end,

        --------------------------------------------------------
        --                 Update data methods                --
        --------------------------------------------------------

        update = function (self, data)
            if Type.is.table(data) then
                local _update = "UPDATE `" .. self.own_table.__tablename__ .. "`"
                local _set = ""
                local coltype
                local _set_tbl = {}
                local i=1

                for colname, new_value in pairs(data) do
                    coltype = self.own_table:get_column(colname)

                    if coltype and coltype.field.validator(new_value) then
                        _set = _set .. " `" .. colname .. "` = " ..
                              coltype.field.as(new_value)
                        _set_tbl[i] = " `" .. colname .. "` = " ..
                                coltype.field.as(new_value)
                        i=i+1
                    else
                        BACKTRACE(WARNING, "Can't update value for column `" ..
                                            Type.to.str(colname) .. "`")
                    end
                end

                -- Build WHERE
                if next(self._rules.where) then
                    _where = self:_condition(self._rules.where, "\nWHERE")
                else
                    BACKTRACE(INFO, "No 'where' statement. All data update!")
                end

                if _set ~= "" then
                    if #_set_tbl<2 then
                        _update = _update .. " SET " .. _set .. " " .. _where
                    else
                        _update = _update .. " SET " .. table.concat(_set_tbl,",") .. " " .. _where
                    end

                    db:execute(_update)
                else
                    BACKTRACE(WARNING, "No table columns for update")
                end
            else
                BACKTRACE(WARNING, "No data for global update")
            end
        end,

        --------------------------------------------------------
        --                 Delete data methods                --
        --------------------------------------------------------

        delete = function (self)
            local _delete = "DELETE FROM `" .. self.own_table.__tablename__ .. "` "

            -- Build WHERE
            if next(self._rules.where) then
                _delete = _delete .. self:_condition(self._rules.where, "\nWHERE")
            else
                BACKTRACE(WARNING, "Try delete all values")
            end

            db:execute(_delete)
        end,

        --------------------------------------------------------
        --              Get select data methods               --
        --------------------------------------------------------

        -- Return one value
        first = function (self)
            self._rules.limit = 1
            local data = self:all()

            if data:count() == 1 then
                return data[1]
            end
        end,

        -- Return list of values
        all = function (self)
            local data = self:_select()
            return QueryList(self.own_table, data)
        end
    }
end

return Select 