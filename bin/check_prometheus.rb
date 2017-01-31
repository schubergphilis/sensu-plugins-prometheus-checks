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

def sensu_safe(string)
  string.gsub(/[^\w\.-]+/,'_')
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

def predict_disk_all(cfg)
  disks = []
  days = cfg['days'].to_i * 86400
  query("predict_linear(node_filesystem_avail{}[24h], #{days}) < 0")['data']['result'].each do |result|
    hostname = result['metric']['instance']
    disk = result['metric']['mountpoint']
    disks << "#{hostname}:#{disk}"
  end
  if disks.length == 0
    {'status' => 0, 'output' => "No disks are predicted to run out of space in the next #{days} days", 'name' => 'predict_disks', 'source' => cfg['source']}
  else
    disks = disks.join(',')
    {'status' => 1, 'output' => "Disks predicted to run out of space in the next #{days} days: #{disks}", 'name' => 'predict_disks', 'source' => cfg['source']}
  end
end

def nice_disk_name(disk)
  if disk == '/'
    'root'
  else
    disk.gsub(/^\//,'').gsub(/\/$/,'').gsub(/\//,'_')
  end
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
    disk_name = nice_disk_name(mountpoint)
    inodes = result['value'][1].to_i
    status = check(inodes, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{mountpoint}, Inode Usage: #{inodes}% |inodes=#{inodes}", 'name' => "check_inode_#{disk_name}", 'source' => hostname}
  end
  query(percent_query_free("node_filesystem_size{#{ignore_fs}}","node_filesystem_avail{#{ignore_fs}}"))['data']['result'].each do |result|
    hostname = result['metric']['instance']
    mountpoint = result['metric']['mountpoint']
    disk_name = nice_disk_name(mountpoint)
    disk = result['value'][1].to_i
    status = check(disk, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Disk: #{mountpoint}, Usage: #{disk}% |disk=#{disk}", 'name' => "check_disk_#{disk_name}", 'source' => hostname}
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
  defaults = {
    'state'=> 'active',
    'state_required'=> 1
  }
  cfg = defaults.merge(cfg)

  results = []
  name = cfg['name']
  query("node_systemd_unit_state{name='#{name}',state='#{cfg['state']}'}")['data']['result'].each do |result|
    hostname = result['metric']['instance']
    state = result['value'][1].to_i
    status = equals(state, cfg['state_required'])
    results << {'status' => status, 'output' => "Service: #{name} (#{cfg['state']}=#{state})", 'name' => "check_service_#{name}", 'source' => hostname}
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
  [{'status' => status, 'output' => "Cluster Load: #{cpu}|load=#{cpu}", 'name' => "cluster_#{cfg['cluster']}_load_minus_n", 'source' => cfg['source']}]
end


def load_per_cluster(cfg)
  cluster = cfg['cluster']
  cpu = query("sum(node_load5{job=\"#{cluster}\"})/count(node_cpu{mode=\"system\",job=\"#{cluster}\"})")['data']['result'][0]['value'][1].to_f.round(2)
  status = check(cpu, cfg['warn'], cfg['crit'])
  [{'status' => status, 'output' => "Cluster Load: #{cpu}|load=#{cpu}", 'name' => "cluster_#{cfg['cluster']}_load", 'source' => cfg['source']}]
end

def memory_per_cluster(cfg)
  cluster = cfg['cluster']
  memory = query(percent_query_free("sum(node_memory_MemTotal{job=\"#{cluster}\"})","sum(node_memory_MemAvailable{job=\"#{cluster}\"})"))['data']['result'][0]['value'][1].to_i
  status = check(memory, cfg['warn'], cfg['crit'])
  [{'status' => status, 'output' => "Cluster Memory: #{memory}%|memory=#{memory}", 'name' => "cluster_#{cfg['cluster']}_memory", 'source' => cfg['source']}]
end

def load_per_cpu(cfg)
  results = []
  cpu_counts = {}
  query('(count(node_cpu{mode="system"})by(instance))')['data']['result'].each do |result|
    cpu_counts[result['metric']['instance']] = result['value'][1]
  end
  query("node_load5")['data']['result'].each do |result|
    hostname = result['metric']['instance']
    cpu = result['value'][1].to_f.round(2) / cpu_counts[hostname].to_f
    status = check(cpu, cfg['warn'], cfg['crit'])
    results << {'status' => status, 'output' => "Load: #{cpu}|load=#{cpu}", 'name' => 'check_load', 'source' => hostname}
  end
  results
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

def map_nodenames
  node_map = {}
  query('max_over_time(node_uname_info[1d])')['data']['result'].each do |result|
    node_map[result['metric']['instance']] = result['metric']['nodename'].split('.',2)[0]
  end
  node_map
end

def build_event(event,node_map,cfg)
  event['reported_by'] = cfg['reported_by']
  event['occurrences'] = cfg['occurences'] || 1
  node_name = node_map[event['source']] || event['source']
  address = "#{node_name}.#{cfg['domain']}"
  event['source'] = sensu_safe(node_name)
  event['name'] = sensu_safe(event['name'])
  event['address'] = sensu_safe(address)
  event
end

def run(checks)
  results = []
  status = 0
  failed_checks = []
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
  node_map = map_nodenames
  results.flatten(1).each do |result|
    if result['source'] =~ /#{cfg['whitelist']}/
      event = build_event(result,node_map,cfg)
      if ENV['PROM_DEBUG']
        puts event
      else
        send_event(event)
      end
      if event['status'] != 0
        failed_checks << "Source: #{event['source']}: Check: #{event['name']}: Output: #{event['output']}: Status: #{event['status']}"
      end
    else
      if ENV['PROM_DEBUG']
        puts "Event dropped because source: #{result['source']} did not match whitelist: #{cfg['whitelist']} event: #{event}"
      end
    end
  end
  if failed_checks.length != 0
    status = 1
    output = failed_checks.join(' ')
  else
    status = 0
    output = "OK: Ran #{results.length} checks succesfully!"
  end
  return status, output
end

if File.basename(__FILE__) == File.basename($PROGRAM_NAME)
  checks = YAML.load_file(ARGV[0]||'config.yml')
  status, output = run(checks)
  puts output
  exit(status)
end
