#!/usr/bin/env ruby

require 'json'
require 'net/http'

`docker-compose rm -f`
`docker-compose start`

count = 0
until count == 10 do
  host, port = 'localhost:9090'.split(':')
  http = Net::HTTP.new(host, port)
  http.read_timeout = 3
  http.open_timeout = 3
  request = Net::HTTP::Get.new("/api/v1/query?query=count(up)")
  begin
    value = JSON.load(http.request(request).body)['data']['result'][0]['value'][1]
  rescue
    puts 'Prometheus not ready yet...'
  end
  if value == '3'
    break
  end
  count = count + 1
  sleep(3)
end

puts 'starting rspec'
puts `rspec`
exit($?.exitstatus)
