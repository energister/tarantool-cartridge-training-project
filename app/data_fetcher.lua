local log = require('log')
local http_client = require('http.client')
local datetime = require('datetime')

local settings = {
    open_meteo_api = {
        REQUEST_TIMEOUT_IN_SECONDS_DEFAULT = 1
    }
}
settings.open_meteo_api.request_timeout_in_seconds = settings.open_meteo_api.REQUEST_TIMEOUT_IN_SECONDS_DEFAULT
function settings.open_meteo_api:set_request_timeout_in_seconds(timeout)
    checks('?', 'number|nil')
    self.request_timeout_in_seconds = timeout or self.REQUEST_TIMEOUT_IN_SECONDS_DEFAULT
    log.info("Set open_meteo_api.request_timeout_in_seconds to %s", tostring(self.request_timeout_in_seconds))
end

local function get_coordinates(place_name)
    checks('string')
    local url = string.format(
        'https://geocoding-api.open-meteo.com/v1/search?name=%s&count=1&language=en&format=json',
        place_name
    )
    local response = http_client.get(url, { timeout = settings.open_meteo_api.request_timeout_in_seconds })
    local geo_data = response:decode()
    if geo_data['results'] == nil or #geo_data['results'] == 0 then
        -- place not found
        return {}
    end

    return {
        latitude = geo_data['results'][1]['latitude'],
        longitude = geo_data['results'][1]['longitude'],
    }
end

local function get_weather(latitude, longitude)
    checks('number', 'number')
    local url = string.format(
        'https://api.open-meteo.com/v1/forecast?latitude=%f&longitude=%f&current=temperature',
        latitude,
        longitude
    )
    local response = http_client.get(url, {timeout = settings.open_meteo_api.request_timeout_in_seconds})
    local response_data = response:decode()
    if response_data['current'] == nil then
        log.error("No current weather data for coordinates: %f,%f", latitude, longitude)
        return nil
    end

    if response_data['current']['time'] == nil then
        log.error("No 'time' field in the weather data for coordinates: %f,%f", latitude, longitude)
        return nil
    end

    if response_data['current']['temperature'] == nil then
        log.error("No 'temperature' field in the weather data for coordinates: %f,%f", latitude, longitude)
        return nil
    end

    if response_data['current']['interval'] == nil then
        log.error("No 'interval' field in the weather data for coordinates: %f,%f", latitude, longitude)
        return nil
    end

    local point_in_time = datetime.parse(response_data['current']['time'])
    local ttl_interval = datetime.interval.new({ sec = response_data['current']['interval'] })

    return {
        point_in_time = point_in_time,
        expiration = point_in_time + ttl_interval,
        temperature_celsius = response_data['current']['temperature'],
    }
end


return {
    settings = settings,
    get_coordinates = get_coordinates,
    get_weather = get_weather,
}