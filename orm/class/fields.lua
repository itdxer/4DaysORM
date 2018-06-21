------------------------------------------------------------------------------
--                                  Class                                   --
------------------------------------------------------------------------------

local Field = {
    -- Table column type
    __type__ = "varchar",

    -- Validator handler
    validator = function (self, value)
        return true
    end,

    -- Default parser
    as = function (value)
        return value
    end,

    to_type = Type.to.str,

    -- Call when create new field in some table
    register = function (self, args)
        if not args then
            args = {}
        end

        -- New field type
        -------------------------------------------
        -- @args {table}
        -- Table can have parametrs:
        --    @args.__type__ {string} some sql valid type
        --    @args.validator {function} type validator
        --    @args.as {function} return parse value
        -------------------------------------------
        new_field_type = {
            -- some sql valid type
            __type__ = args.__type__ or self.__type__,

            -- Validator handler
            validator = args.validator or self.validator,

            -- Parse variable for equation
            as = args.as or self.as,

            -- Cast values to correct type
            to_type = args.to_type or self.to_type,

            -- Default settings for type
            settings = args.settings or {},

            -- Get new table column instance
            new = function (this, args)
                if not args then
                    args = {}
                end

                local new_self = {
                    -- link to field instance
                    field = this,

                    -- Column name
                    name = nil,

                    -- Parent table
                    __table__ = nil,

                    -- table column settings
                    settings = {
                        default = nil,
                        null = false,
                        unique = false,
                        max_length = nil,
                        primary_key = false,
                        escape_value = false
                    },

                    -- Return string for column type create
                    _create_type = function (this)
                        local _type = this.field.__type__

                        if this.settings.max_length and this.settings.max_length > 0 then
                            _type = _type .. "(" .. this.settings.max_length .. ")"
                        end

                        if this.settings.primary_key then
                            _type = _type .. " PRIMARY KEY"
                        end

                        if this.settings.auto_increment and DB.type ~= SQLITE then
                            _type = _type .. " AUTO_INCREMENT"
                        end

                        if this.settings.unique then
                            _type = _type .. " UNIQUE"
                        end

                        _type = _type .. (this.settings.null and " NULL"
                                                             or " NOT NULL")
                        return _type
                    end
                }

                -- Set Default settings

                --
                -- The content of the settings table must be copied because trying to copy a table
                -- directly will result in a reference to the original table, thus all
                -- instances of the same field type would have the same settings table.
                --
                for index, setting in pairs(new_self.field.settings) do
                  new_self.settings[index] = setting
                end

                -- Set settings for column
                if args.max_length then
                    new_self.settings.max_length = args.max_length
                end

                if args.null ~= nil then
                    new_self.settings.null = args.null
                end

                if new_self.settings.foreign_key and args.to then
                    new_self.settings.to = args.to
                end

                if args.escape_value then
                  new_self.settings.escape_value = true
                end

                return new_self
            end
        }

        setmetatable(new_field_type, {__call = new_field_type.new})

        return new_field_type
    end
}

return Field