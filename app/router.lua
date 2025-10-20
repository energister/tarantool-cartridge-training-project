local vshard = require('vshard')
local log = require('log')
local json = require('json')

local function http_get_weather(req)
    local place_name = req:query_param().place
    if place_name == nil or place_name == "" then
        return { status = 400, body = "'place' parameter is required" }
    end

    local bucket_id = vshard.router.bucket_id_strcrc32(place_name)
    local storage_response, err = vshard.router.callrw(bucket_id, 'storage_api.get_weather_for_place', { bucket_id, place_name })
    if storage_response == nil then
        if err ~= nil then
            log.error("Failed to request the storage: %s", err)
        end
        return { status = 500, body = 'Unexpected error while querying cache' }
    end

    local x_cache_header = { ['x-cache'] = storage_response.cached and 'HIT' or 'MISS' }
    if next(storage_response.coordinates) == nil then
        return { status = 404, headers = x_cache_header, body = "'"..place_name.."' not found" }
    elseif storage_response.weather == nil then
        local response = { coordinates = storage_response.coordinates }
        return { status = 503, headers = x_cache_header, body = json.encode(response) }
    else
        local response = { coordinates = storage_response.coordinates }
        do
            local weather = storage_response.weather
            
            response.point_in_time = weather.point_in_time
            response.temperature_celsius = weather.temperature_celsius
        end
        return { status = 200, headers = x_cache_header, body = json.encode(response) }
    end
end

return {
    http_get_weather = http_get_weather,
}