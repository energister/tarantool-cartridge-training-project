local checks = require('checks')

local function create_place_space()
    local places = box.schema.create_space(
        'place',
        {
            format = {
                {'place_name', 'string'},
                {'bucket_id', 'unsigned'},
                {'coordinates', 'map'},
            },

            -- create space only if it does not exist
            if_not_exists = true,
        }
    )

    places:create_index('primary', {
        parts = {'place_name'},
        if_not_exists = true,
    })

    -- required for vshard
    places:create_index('bucket_id', {
        parts = {'bucket_id'},
        unique = false,
        if_not_exists = true,
    })
end

local function create_weather_space()
    local weather = box.schema.create_space(
        'weather',
        {
            format = {
                {'place_name', 'string'},
                {'bucket_id', 'unsigned'},
                {'point_in_time', 'datetime'},
                {'expiration', 'datetime'},
                {'weather_data', 'map'},
            },

            -- create space only if it does not exist
            if_not_exists = true,
        }
    )

    weather:create_index('primary', {
        parts = {'place_name'},
        if_not_exists = true,
    })

    -- required for vshard
    weather:create_index('bucket_id', {
        parts = {'bucket_id'},
        unique = false,
        if_not_exists = true,
    })
end

local function create_spaces(is_master)
    checks('boolean')
    if not is_master then
        return
    end

    create_place_space()
    create_weather_space()
end

local function coordinates_get(place_name)
    local stored = box.space.place:get(place_name)
    return stored and stored.coordinates
end

local function coordinates_put(bucket_id, place_name, coordinates)
    checks('number', 'string', 'table')
    local storable_coordinates = setmetatable(coordinates, { __serialize = "map" })
    box.space.place:insert({ place_name, bucket_id, storable_coordinates })
    return true
end

local function weather_get(place_name)
    checks('string')
    local stored = box.space.weather:get(place_name)
    return stored and {
        expiration = stored.expiration,
        weather_data = stored.weather_data
    }
end

local function weather_upsert(bucket_id, place_name, point_in_time, expiration, weather_data)
    checks('number', 'string', 'datetime', 'datetime', 'table')
    box.space.weather:put({ place_name, bucket_id, point_in_time, expiration, weather_data })
    return true
end

return {
    create_spaces = create_spaces,
    coordinates_get = coordinates_get,
    coordinates_put = coordinates_put,
    weather_get = weather_get,
    weather_upsert = weather_upsert
}