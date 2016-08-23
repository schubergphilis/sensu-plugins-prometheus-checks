#!/usr/bin/env ruby
require 'socket'
require 'json'
require 'net/http'
require 'yaml'
require 'cgi'

def query stuff
  stuff = CGI.escape(stuff)
  host, port = (ENV['PROMETHEUS_ENDPOINT'] || 'localhost:9090').split(':')
  http = Net::HTTP.new(host, port)
  http.read_timeout = 3
  http.open_timeout = 3
  request = Net::HTTP::Get.new("/api/v1/query?query=#{stuff}")
  JSON.load(http.request(request).body)
end

def safe_hostname(hostname)
  hostname.gsub(/-|:/,'_')
end

def send_event(event)
  s = TCPSocket.open('localhost', 3030)
  s.puts JSON.generate(event)
  s.close
end

def check result, warn, crit
  result = result.to_f
  warn = warn.to_f
  crit = crit.to_f
  status = 3
  if result < warn
    status = 0
  elsif result >= crit
    status = 2
  elsif result >= warn
    status = 1
  end
  status
end

def percent_query_free(total,available)
  "100-((#{available}/#{total})*100)"
end

def memory(cfg)
  results = []
  query(percent_query_free('node_memory_MemTotal','node_memory_MemAvailable'))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    memory = result['value'][1].to_i
    status = check(memory, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Memory #{memory}%|memory=#{memory}", 'name' => 'check_memory', 'source' => hostname}
  end
  results
end

def disk(cfg)
  results = []
  mountpoint = "mountpoint=\"#{cfg['mount']}\""
  query(percent_query_free("node_filesystem_size{#{mountpoint}}", "node_filesystem_avail{#{mountpoint}}"))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    disk = result['value'][1].to_i
    status = check(disk, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{disk}%, Mountpoint: #{cfg['mount']} |disk=#{disk}", 'name' => "check_disk_#{cfg['name']}", 'source' => hostname}
  end
  results
end

def disk_all(cfg)
  results = []
  ignored = cfg['ignore_fs'] || 'tmpfs'
  ignore_fs = "fstype!~\"#{ignored}\""
  query(percent_query_free("node_filesystem_files{#{ignore_fs}}","node_filesystem_files_free{#{ignore_fs}}"))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    mountpoint = result['metric']['mountpoint']
    inodes = result['value'][1].to_i
    status = check(inodes, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{mountpoint}, Inode Usage: #{inodes}% |inodes=#{inodes}", 'name' => "check_inode_#{mountpoint}", 'source' => hostname}
  end
  query(percent_query_free("node_filesystem_size{#{ignore_fs}}","node_filesystem_avail{#{ignore_fs}}"))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    mountpoint = result['metric']['mountpoint']
    disk = result['value'][1].to_i
    status = check(disk, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{mountpoint}, Usage: #{disk}% |disk=#{disk}", 'name' => "check_disk_#{mountpoint}", 'source' => hostname}
  end
  results
end

def inode(cfg)
  results = []
  disk = "mountpoint=\"#{cfg['mount']}\""
  query(percent_query_free("node_filesystem_files{#{disk}}","node_filesystem_files_free{#{disk}}"))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    inodes = result['value'][1].to_i
    status = check(inodes, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{cfg['mount']}, Inodes: #{inodes}% |inodes=#{inodes}", 'name' => "check_inodes_#{cfg['name']}", 'source' => hostname}
  end
  results
end

def service(cfg)
  results = []
  name = cfg['name']
  query("node_systemd_unit_state{name='#{name}',state='active'}")['data']['result'].each do |result|
    hostname = result['metric']['instance']
    state = result['value'][1].to_i
    status = equals(state, 1)
    results << {'status' => status, 'output' => "Service: #{name}", 'name' => "check_service_#{name}", 'source' => hostname}
  end
  results
end

def load_per_cluster_minus_n(cfg)
  cluster = cfg['cluster']
  minus_n = cfg['minus_n']
  sum_load = "sum(node_load5{job=\"#{cluster}\"})"
  total_cpus = "count(node_cpu{mode=\"system\",job=\"#{cluster}\"})"
  total_nodes = "count(node_load5{job=\"#{cluster}\"})"

  cpu = query("#{sum_load}/(#{total_cpus}-(#{total_cpus}/#{total_nodes})*#{minus_n})")['data']['result'][0]['value'][1].to_f.round(2)
  status = check(cpu, cfg['warn'], cfg['crit'])
  [{'status' => status, 'output' => "Cluster Load: #{cpu}|load=#{cpu}", 'name' => 'cluster_load_minus_n', 'source' => cfg['source']}]
end


def load_per_cluster(cfg)
  cluster = cfg['cluster']
  cpu = query("sum(node_load5{job=\"#{cluster}\"})/count(node_cpu{mode=\"system\",job=\"#{cluster}\"})")['data']['result'][0]['value'][1].to_f.round(2)
  status = check(cpu, cfg['warn'], cfg['crit'])
  [{'status' => status, 'output' => "Cluster Load: #{cpu}|load=#{cpu}", 'name' => 'cluster_load', 'source' => cfg['source']}]
end


def equals result, value
  if result.to_f == value.to_f
    0
  else
    2
  end
end

def custom(check)
  results = []
  query(check['query'])['data']['result'].each do |result|
    status = send(check['check']['type'], result['value'][1], check['check']['value'])
    results << {'status' => status, 'output' => "#{check['msg'][status]}", 'source' => result['metric']['instance'], 'name' => check['name']}
  end
  results
end

if __FILE__ == $0
  results = []
  checks = YAML.load_file(ARGV[0]||'config.yml')
  cfg = checks['config']
  checks['checks'].each do |check|
    begin
      results << send(check['check'], check['cfg'])
    rescue
      puts "Check: #{check} failed!"
    end
  end
  checks['custom'].each do |check|
    begin
      results << custom(check)
    rescue
      puts "Check: #{check} failed!"
    end
  end
  results.flatten(1).each do |result|
    event = {
      'reported_by' => cfg['reported_by']
    }.merge(result)
    if event['source'] =~ /#{cfg['whitelist']}/
      event['source'] = safe_hostname(event['source'])
      if ENV['PROM_DEBUG']
        puts event
      else
        send_event(event)
      end
    end
  end
  exit 0
end
