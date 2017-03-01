#!/usr/bin/env ruby

require 'json'
require 'net/http'

`docker network create check_prometheus`
`docker-compose stop`
`docker-compose rm -f`
`docker-compose build`
`docker-compose create`
`docker-compose start`

prom_endpoint = '127.0.0.1:19090'
ENV['PROMETHEUS_ENDPOINT'] = prom_endpoint

count = 0
until count == 10
  host, port = prom_endpoint.split(':')
  http = Net::HTTP.new(host, port)
  http.read_timeout = 3
  http.open_timeout = 3
  request = Net::HTTP::Get.new('/api/v1/query?query=count(up)')
  begin
    value = JSON.load(http.request(request).body)['data']['result'][0]['value'][1]
  rescue
    puts "Prometheus not ready yet ... #{count}"
  end
  break if value == '3'
  count += 1
  sleep(3)
end

if count == 10
  puts 'ERROR: Prometheus failed to start'
  exit(1)
end

puts 'starting rspec'
puts `rspec -c`
exit_code = `echo $?`
exit(exit_code.to_i)
