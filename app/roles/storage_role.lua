local storage = require('app.storage')
local checks = require('checks')
local cartridge = require('cartridge')
local log = require('log')
local datetime = require('datetime')

local function init(opts)
    storage.create_spaces(opts.is_master)

    return true
end

local function get_coordinates(bucket_id, place_name)
    checks('number', 'string')

    local stored = storage.coordinates_get(place_name)
    if stored ~= nil then
        return stored
    end

    local coordinates, err = cartridge.rpc_call('app.roles.data_fetcher', 'get_coordinates', { place_name })
    if err ~= nil or coordinates == nil then
        log.error("Failed to perform an RPC call to the data_fetcher.get_coordinates: %s", err)
        return nil
    end

    -- cache the response
    storage.coordinates_put(bucket_id, place_name, coordinates)
    return coordinates
end

local function fetch_weather(bucket_id, place_name, coordinates)
    checks('number', 'string', 'table')

    local arguments = { coordinates.latitude, coordinates.longitude }
    local weather, err = cartridge.rpc_call('app.roles.data_fetcher', 'get_weather', arguments)
    if err ~= nil or weather == nil then
        log.error("Failed to perform an RPC call to the data_fetcher.get_weather: %s", err)
        return nil
    end

    -- cache the response
    storage.weather_upsert(bucket_id, place_name, weather.point_in_time, weather.expiration, weather)

    return weather
end

local function get_weather_for_place(bucket_id, place_name)
    checks('number', 'string')

    local stored_weather = storage.weather_get(place_name)
    if stored_weather ~= nil and datetime.now() < stored_weather.expiration then
        log.debug("Cache HIT for weather of '%s' (will expire at %s)", place_name, stored_weather.expiration)
        return {
            cached = true,
            -- coordinates are guaranteed to be cached when the weather is cached
            coordinates = storage.coordinates_get(place_name),
            weather = stored_weather.weather_data
        }
    end

    log.debug("Cache MISS for weather of '%s' (expiration was at %s)", place_name, stored_weather and stored_weather.expiration)

    local coordinates = get_coordinates(bucket_id, place_name)
    if coordinates == nil then
        -- failed to fetch coordinates
        return nil
    elseif next(coordinates) == nil then
        -- place not found
        return {
            cached = true,
            coordinates = {},
            weather = nil,
        }
    end

    local weather = fetch_weather(bucket_id, place_name, coordinates)
    if weather == nil then
        -- failed to fetch weather
        return nil
    end
    return {
        cached = false,
        coordinates = coordinates,
        weather = weather,
    }
end

storage_api = {
    get_weather_for_place = get_weather_for_place,
}

return {
    role_name = 'app.roles.storage',
    init = init,
    dependencies = {'cartridge.roles.vshard-storage'},
}