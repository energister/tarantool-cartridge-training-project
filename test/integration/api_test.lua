local t = require('luatest')
local g = t.group('integration_api')

local helper = require('test.helper')

local http_client = require('http.client')
local datetime = require('datetime')

g.before_all(function(cg)
    cg.cluster = helper.cluster
    cg.cluster:start()
end)

g.after_all(function(cg)
    helper.stop_cluster(cg.cluster)
end)

g.before_each(function(cg) -- luacheck: no unused args
    -- helper.truncate_space_on_cluster(g.cluster, 'Set your space name here')
end)

g.test_weather_requires_parameter = function(cg)
    local server = cg.cluster.main_server
    local response = server:http_request('get', '/weather', { raise = false })
    t.assert_equals(response.status, 400)
    t.assert_str_contains(response.body, "place")
end

g.test_weather_Berlin = function(cg)
    local server = cg.cluster.main_server
    local response = server:http_request('get', '/weather?place=Berlin')
    t.assert_equals(response.status, 200)
    t.assert_equals(response.json['coordinates']['latitude'], 52.52437)
    t.assert_equals(response.json['coordinates']['longitude'], 13.41053)
    t.assert_gt(response.json['temperature_celsius'], 0)
end

local function get_temperature(latitude, longitude)
    local url = string.format(
        'https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s&current=temperature',
        tostring(latitude),
        tostring(longitude)
    )
    local data = http_client.get(url):decode()
    return tostring(datetime.parse(data['current']['time'])),
        data['current']['temperature']
end

g.test_weather_London = function(cg)
    local time1, temperature1 = get_temperature(51.50853, -0.12574)
    local server = cg.cluster.main_server

    --[[ Act ]]
    local response = server:http_request('get', '/weather?place=London')

    --[[ Assert ]]
    t.assert_equals(response.status, 200)
    t.assert_equals(response.json['coordinates']['latitude'], 51.50853)
    t.assert_equals(response.json['coordinates']['longitude'], -0.12574)

    -- Check temperature value (it might change between requests)
    local time2, temperature2 = get_temperature(51.50853, -0.12574)

    if response.json['point_in_time'] == time1 then
        t.assert_equals(response.json['temperature_celsius'], temperature1)
    elseif response.json['point_in_time'] == time2 then
        t.assert_equals(response.json['temperature_celsius'], temperature2)
    else
        local error_msg = string.format(
            "Temperature time can't change twice during test (and so the temperature): got %s, expected %s or %s",
            response.json['point_in_time'], time1, time2
        )
        t.fail(error_msg)
    end
end

g.test_weather_in_nonexisting_place = function(cg)
    local server = cg.cluster.main_server
    local response = server:http_request('get', '/weather?place=Nowhereville', { raise = false })
    t.assert_equals(response.status, 404)
    t.assert_equals(response.body, "'Nowhereville' not found")
end

g.test_second_request_for_existing_place_is_served_from_cache = function(cg)
    local server = cg.cluster.main_server
    local city = 'Paris'

    local response1 = server:http_request('get', '/weather?place=' .. city)
    -- first request is served from the upstream server
    t.assert_equals(response1.headers['x-cache'], 'MISS')

    -- second request is served from the cache
    local response2 = server:http_request('get', '/weather?place=' .. city)
    t.assert_equals(response2.headers['x-cache'], 'HIT')
end

g.test_response_then_upstream_is_temporarily_unavailable = function(cg)
    local server = cg.cluster.main_server
    local response = server:http_request('get', '/weather?place=Paris')
    t.assert_equals(response.status, 200)
    t.assert_equals(response.json['coordinates']['latitude'], 48.85341)
    t.assert_equals(response.json['coordinates']['longitude'], 2.3488)
    t.assert_gt(response.json['temperature_celsius'], 0)

    --[[ TODO: Simulate temporal unavailability of the upstream server
    local response = server:http_request('get', '/weather?place=Paris')
    t.assert_equals(response.status, 503)
    t.assert_equals(response.json['coordinates']['latitude'], 48.85341)
    t.assert_equals(response.json['coordinates']['longitude'], 2.3488)
    t.assert_equals(response.json['point_in_time'], nil)
    t.assert_equals(response.json['temperature_celsius'], nil)
    ]]
end

g.test_cache_record_expiration = function(cg)
    local server = cg.cluster.main_server
    local city = 'Rome'

    -- first request is served from the upstream server
    local response1 = server:http_request('get', '/weather?place=' .. city)
    t.assert_equals(response1.headers['x-cache'], 'MISS')

    -- simulate cache record expiration
    for _, server in ipairs(cg.cluster:servers_by_role('app.roles.storage')) do
        server.net_box:eval([[
        if not box.cfg.read_only then
            local space = box.space.weather
            local expiration = require('datetime').now():sub({ seconds = 1 })
            space:update('Rome', {{'=', 4, expiration}})
        end
        ]])
    end

    -- next request after cache expiration is served from the upstream server again
    local response2 = server:http_request('get', '/weather?place=' .. city)
    t.assert_equals(response2.headers['x-cache'], 'MISS')
end