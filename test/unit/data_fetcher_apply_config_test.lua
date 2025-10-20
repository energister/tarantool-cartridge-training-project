local t = require('luatest')
local g = t.group('data_fetcher_role.apply_config')

local yaml = require('yaml')

local data_fetcher_role = require('app.roles.data_fetcher_role')

local OPTS_ARGUMENT = { is_master = true }

local settings = require('app.data_fetcher').settings.open_meteo_api

g.test_default_on_start = function()
    local custom_config = { }

    data_fetcher_role.apply_config(custom_config, OPTS_ARGUMENT)

    t.assert_equals(settings.request_timeout_in_seconds, settings.REQUEST_TIMEOUT_IN_SECONDS_DEFAULT)
end

g.test_apply_config = function()
    local custom_config = yaml.decode([[
    custom_config:
        open_meteo_api:
            request_timeout_in_seconds: 15
    ]])

    data_fetcher_role.apply_config(custom_config, OPTS_ARGUMENT)

    t.assert_equals(settings.request_timeout_in_seconds, 15)
end

g.test_remove_the_option_or_config = function()
    local custom_config = yaml.decode([[
    custom_config:
        open_meteo_api:
            # request_timeout_in_seconds option is removed
            some_other_option: 123
    ]])

    data_fetcher_role.apply_config(custom_config, OPTS_ARGUMENT)

    -- become default again
    t.assert_equals(settings.request_timeout_in_seconds, settings.REQUEST_TIMEOUT_IN_SECONDS_DEFAULT)
end