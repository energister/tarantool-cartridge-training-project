-- Role: data_fetcher
-- Purpose: Encapsulate interactions with the remote server API (https://open-meteo.com/)
local log = require('log')
local fetcher = require('app.data_fetcher')

local CFG_FILE_NAME = 'custom_config' -- custom_config.yml
local CFG_SECTION_NAME = 'open_meteo_api'
local CFG_REQUEST_TIMEOUT_OPTION_NAME = 'request_timeout_in_seconds'

local function validate_config(conf_new, conf_old) -- luacheck: no unused args
    local timeout = ((conf_new[CFG_FILE_NAME] or {})[CFG_SECTION_NAME] or {})[CFG_REQUEST_TIMEOUT_OPTION_NAME]
    if timeout ~= nil
        and (type(timeout) ~= 'number' or timeout < 0) then

        local option_path = CFG_FILE_NAME .. '.' .. CFG_SECTION_NAME .. '.' .. CFG_REQUEST_TIMEOUT_OPTION_NAME
        log.info("Invalid %s value: %s", option_path, tostring(timeout))
        return nil, option_path .. " must be a non-negative number"
    end

    return true
end

local function apply_config(conf, opts) -- luacheck: no unused args
    local timeout = ((conf[CFG_FILE_NAME] or {})[CFG_SECTION_NAME] or {})[CFG_REQUEST_TIMEOUT_OPTION_NAME]

    fetcher.settings.open_meteo_api:set_request_timeout_in_seconds(timeout)

    return true
end

return {
    role_name = 'app.roles.data_fetcher',
    validate_config = validate_config,
    apply_config = apply_config,
    get_coordinates = fetcher.get_coordinates,
    get_weather = fetcher.get_weather,
}