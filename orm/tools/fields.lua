------------------------------------------------------------------------------
--                                  Libs                                   --
------------------------------------------------------------------------------

Type = require('orm.class.type')
Field = require('orm.class.fields')



------------------------------------------------------------------------------
--                                Field Types                               --
------------------------------------------------------------------------------
local function save_as_str(str)
    return "'" .. str .. "'"
end

local field = {}

-- The "Field" class will be used to search a table index that the "field" class doesn't have.
-- This way field:register() will call the same function like Field:register() and the register
-- function has access to the default values for the field configuration.
setmetatable(field, {__index = Field});


field.PrimaryField = Field:register({
    __type__ = "integer",
    validator = Type.is.int,
    settings = {
        null = true,
        primary_key = true,
        auto_increment = true
    },
    to_type = Type.to.number
})

field.IntegerField = Field:register({
    __type__ = "integer",
    validator = Type.is.int,
    to_type = Type.to.number
})

field.CharField = Field:register({
    __type__ = "varchar",
    validator = Type.is.str,
    as = save_as_str
})

field.TextField = Field:register({
    __type__ = "text",
    validator = Type.is.str,
    as = save_as_str
})

field.BooleandField = Field:register({
    __type__ = "bool"
})

field.DateTimeField = Field:register({
    __type__ = "integer",
    validator = function (value)
        if (Type.is.table(value) and value.isdst ~= nil)
        or Type.is.int(value) then
            return true
        end
    end,
    as = function (value)
        return Type.is.int(value) and value or os.time(value)
    end,
    to_type = function (value)
        return os.date("*t", Type.to.number(value))
    end
})

field.ForeignKey = Field:register({
    __type__ = "integer",
    settings = {
        null = true,
        foreign_key = true
    },
    to_type = Type.to.number
})

return field