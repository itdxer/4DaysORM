------------------------------------------------------------------------------
--                          query_list.lua                                  --
------------------------------------------------------------------------------

function QueryList(own_table, rows)
    local current_query
    local _query_list = {
        ------------------------------------------------
        --          Table info varibles               --
        ------------------------------------------------

        --class name
        __classname__ = QUERY_LIST,

        -- Own Table
        own_table = own_table,

        -- Stack of data rows
        _stack = {},

        ------------------------------------------------
        --             Metamethods                    --
        ------------------------------------------------

        -- Get n-th position value from Query stack
        ------------------------------------------------
        -- @position {integer} position element is stack
        --
        -- @return {Query Instance} Table row instance
        -- in n-th position
        ------------------------------------------------
        __index = function (self, position)
            if Type.is.int(position) and position >= 1 then
                return self._stack[position]
            end
        end,

        __call = function (self)
            return pairs(self._stack)
        end,

        ------------------------------------------------
        --             User methods                   --
        ------------------------------------------------

        -- Get Query instance by id
        ------------------------------------------------
        -- @id {integer} table data row identifier
        --
        -- @return {table/nil} get Query instance or nil if
        -- instance is not exists
        ------------------------------------------------
        with_id = function (self, id)
            if Type.is.int(id) then
                for _, query in pairs(self) do
                    if query.id == id then
                        return query
                    end
                end
            else
                BACKTRACE(WARNING, "ID `" .. id .. "` is not integer value")
            end
        end,

        -- Add new Query Instance to stack
        add = function (self, QueryInstance)
            table.insert(self._stack, QueryInstance)
        end,

        -- Get count of values in stack
        count = function (self)
            return #self._stack
        end,

        -- Remove from database all elements from stack
        delete = function (self)
            for _, query in pairs(self._stack) do
                query:delete()
            end

            self._stack = {}
        end
    }

    setmetatable(_query_list, {__index = _query_list.__index,
                               __len = _query_list.__len,
                               __call = _query_list.__call})

    for _, row in pairs(rows) do
        current_query = _query_list:with_id(Type.to.number(row.id))

        if current_query then
            for key, value in pairs(row) do
                if Type.is.table(value)
                and current_query._readonly[key .. "_all"] then
                    current_query._readonly[key .. "_all"]:add(
                        Query(_G.All_Tables[key], value)
                    )
                end
            end
        else
            _query_list:add(Query(own_table, row))
        end
    end

    return _query_list
end

return QueryList