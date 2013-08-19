
DB = {
    DEBUG = true,
    new = true,
    backtrace = true,
    name = "database.db",
    type = "sqlite3"
}

local Table = require("orm.model")
local fields = require("orm.tools.fields")

local User = Table({
    __tablename__ = "user",
    username = fields.CharField({max_length = 100, unique = true}),
    password = fields.CharField({max_length = 50, unique = true}),
    age = fields.IntegerField({max_length = 2, null = true}),
    job = fields.CharField({max_length = 50, null = true}),
    time_create = fields.DateTimeField({null = true})
})

local News = Table({
    __tablename__ = "news",
    title = fields.CharField({max_length = 100, unique = false, null = false}),
    text = fields.TextField({null = true}),
    create_user_id = fields.ForeignKey({to = User})
})


require('test.luaunit')

TestORM = {
    UNAME = "somename",
    NEWUNAME = 'somenewname',
    PASSWD = "secret",
    user = nil
}

    function TestORM:test01_create_row()
        local user_id

        -- Create new user but not add to database
        self.user = User({
            username = self.UNAME,
            password = self.PASSWD,
            time_create = os.time()
        })

        assertEquals(self.user.username, self.UNAME)
        assertEquals(self.user.password, self.PASSWD)
        assertEquals(self.user.id, nil)

        -- Save new user to database
        self.user:save()
        user_id = self.user.id

        assertEquals(type(user_id), 'number')
        assertEquals(user_id, 1)
        assertEquals(self.user.age, nil)
        -- Can be wrong if you try run it in new year
        assertEquals(self.user.time_create.year, os.date('*t', os.time()).year)
    end

    function TestORM:test02_update_row()
        local user_id = self.user.id
        -- Update user data
        self.user.username = self.NEWUNAME
        self.user:save()

        assertEquals(self.user.username, self.NEWUNAME)
        assertEquals(self.user.id, user_id)
    end

    function TestORM:test03_delete_data()
        -- Delete user
        self.user:delete()
        assertEquals(self.user.id, nil)
    end

TestORMSelect = {}

    function TestORMSelect:test04()
        local usernames = {"first", "second", "third", "operator",
                           "creator", "randomusername"}
        local passwords = {"secret_one", "scrt_tw", "hello",
                           "world", "testpasswd", "new"}
        local age = {33, 12, 22, 44, 44, 44}
        local user

        for i = 1, #usernames do
            user = User({username = usernames[i],
                         password = passwords[i],
                         age = age[i]})
            user:save()
        end

    end

    function TestORMSelect:test05_simple_select()
        local users = User.get:all()
        assertEquals(users:count(), 6)
    end

    function TestORMSelect:test06_get_one_value()
        local user = User.get:first()
        assertEquals(user.username, "first")
    end

    function TestORMSelect:test07_limit_and_offset()
        local users = User.get:limit(3):offset(2):all()
        local iterator = 3

        for _, user in pairs(users) do
            assertEquals(user.id, iterator)
            iterator = iterator + 1
        end
    end

    function TestORMSelect:test08_order()
        local users = User.get:order_by({desc('id'), asc('username')}):all()
        assertEquals(users[1].id, 6)
        assertEquals(users[1].username, 'randomusername')
    end

    function TestORMSelect:test09_where()
        local user = User.get:where({age__lt = 30,
                                     age__lte = 30,
                                     age__gt = 10,
                                     age__gte = 10,
                                     id__in = {1, 3, 5},
                                     id__notin = {2, 4, 6},
                                     username__null = false
                              }):first()

        assertEquals(user.id, 3)
    end

    function TestORMSelect:test10_group()
        local user = User.get:group_by({'age'}):all()

        assertEquals(user:count(), 4)
        assertEquals(user[4].age, 44)
    end

    function TestORMSelect:test11_having()
        local user1 = User.get:group_by({'id', 'password'})
                              :having({age__gt = 40,
                                       id__notin = {1,2,3,4,5},
                              })
                              :all()

        assertEquals(user1[1].id, 6)
        assertEquals(user1:count(), 1)
    end

    function TestORMSelect:test12_join()
        local user = User.get:first()
        local group = News({title = "some news", create_user_id = user.id})
        group:save()

        assertEquals(group.id, 1)

        local user_group = News.get:join(User):first()

        assertEquals(user_group.user.id, 1)
        assertEquals(user_group.id, 1)
    end

    function TestORMSelect:test13_join_with_all()
        local user = User.get:first()
        -- Add some test news
        local group = News({title = "some new news", create_user_id = user.id})
        group:save()

        local group = News({title = "other news", create_user_id = user.id})
        group:save()

        local users = User.get:join(News):all()

        assertEquals(users:count(), 1)
        assertEquals(users[1].news_all:count(), 3)
    end

    function TestORMSelect:test14_update_many()
        local users_query = User.get:where({age__gt = 40})
        local users_before = users_query:all()

        users_query:update({age = 41})

        local users_after = users_query:all()

        for iter, user in pairs(users_after) do
            assertEquals(user.username, users_before[iter].username)
            assertEquals(user.age, 41)
        end
    end

    function TestORMSelect:test15_delete_many()
        local users_query = User.get:where({age__lt = 40})
        local users_before = users_query:all()

        users_query:delete()

        local users_after = users_query:all()

        assertEquals(users_before:count(), 3)
        assertEquals(users_after:count(), 0)
    end

LuaUnit:run()
