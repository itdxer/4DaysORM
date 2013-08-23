local transaction = {
    _clear = function (self)
        TRANSACTION._STACK = {}
        TRANSACTION.MODE = false
    end,
    -------------------------------------------
    --           User methds                 --
    -------------------------------------------

    begin = function (self)
        BACKTRACE(INFO, "Start add queries to transaction")
        TRANSACTION.MODE = true
    end,

    commit = function (self)
        local _stack = TRANSACTION._STACK
        BACKTRACE(INFO, "Transaction commit")
        
        self:_clear()

        db:execute("BEGIN TRANSACTION")

        for _, sql in pairs(_stack) do
            db:execute(sql)
        end

        db:execute("COMMIT TRANSACTION")
    end,

    rollback = function (self)
        BACKTRACE(INFO, "Transaction rollback")
        self:_clear()
    end
}

return transaction