# Sensu Kubernetes Prometheus Plugin

[![build status](https://sbp.gitlab.schubergphilis.com/MCP/sensu-plugins-k8s/badges/master/build.svg)](https://sbp.gitlab.schubergphilis.com/MCP/sensu-plugins-k8s/commits/master)
[![coverage report](https://sbp.gitlab.schubergphilis.com/MCP/sensu-plugins-k8s/badges/master/coverage.svg)](https://sbp.gitlab.schubergphilis.com/MCP/sensu-plugins-k8s/commits/master)

## Description
Sensu plugin designed to query prometheus data output from node-exporter

## Usage
```
check_prometheus.rb /path/to/config.yml

# Debug mode to output all json and blacklisted checks
PROM_DEBUG=true check_prometheus.rb /path/to/config.yml
```

## Development and testing

Dependencies: docker, docker-compose

To spinup a development stack and run the integration tests
```
ruby test.rb
```

Afterwards you can just run `rspec` to run the tests

To run the dockerized version (that gitlab-ci uses)
```
bash test.sh
```

### Environment variables

<table>
 <tr>
   <th>Name</th>
   <th>Example</th>
   <th>Default</th>
   <th>Description</th>
 </tr>
 <tr>
   <td>PROM_DEBUG</td>
   <td>true</td>
   <td>false</td>
   <td>Debug output instead of sending checks to sensu</td>
 </tr>
 <tr>
   <td>PROMETHEUS_ENDPOINT</td>
   <td>hostname:9090</td>
   <td>localhost:9090</td>
   <td>Connection string in the format address:port</td>
 </tr>
 <tr>
   <td>SENSU_SOCKET_ADDRESS</td>
   <td>hostname</td>
   <td>localhost</td>
   <td>Address used to connect to the sensu socket</td>
 </tr>
 <tr>
   <td>SENSU_SOCKET_PORT</td>
   <td>1234</td>
   <td>3030</td>
   <td>Port used to connect to the sensu socket</td>
 </tr>
</table>


### Config.yml
Check configuration is defined in the `config.yml` file under the key `checks`, and checks based on custom Prometheus queries are under `custom`. Example:

``` yaml
config:
  reported_by: sbppapik8s
  occurrences: 3
  domain: example.com
  whitelist: sbppapik8s.*
checks:
  - service:
    name: kube-controller-manager.service
  - check: load_per_cluster
    host: sbppapik8s
    cfg:
      cluster: prometheus
      warn: 1.0
      crit: 2.0
      source: sbppapik8s
custom:
  - name: heartbeat
    query: up
    check:
      type: equals
      value: 1
    msg:
      0: 'OK: Endpoint is alive and kicking'
      2: 'CRIT: Endpoints not reachable!'
```

## Checks

 <table>
  <tr>
    <th>Name</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>service</td>
    <td>Checks if a systemd service is active</td>
  </tr>
  <tr>
    <td>memory</td>
    <td>Checks memory usage as a percentage</td>
  </tr>
  <tr>
    <td>load_per_cpu</td>
    <td>Checks cpu load divided by cpus</td>
  </tr>
  <tr>
    <td>load_per_cluster</td>
    <td>Checks cpu load of entire cluster divided by total cpus</td>
  </tr>
  <tr>
    <td>load_per_cluster_minus_n</td>
    <td>Checks cpu load of entire cluster divided by total cpus minus n failures</td>
  </tr>
  <tr>
    <td>inode</td>
    <td>Checks inode usage as a percentage per mountpoint</td>
  </tr>
  <tr>
    <td>disk</td>
    <td>Checks filesytem usage as a percentage per mountpoint</td>
  </tr>
  <tr>
    <td>disk_all</td>
    <td>Checks filesystem and inode usage of all mountpoints</td>
  </tr>
  <tr>
    <td>predict_disk_all</td>
    <td>Predicts if any of the disks in prometheus will be full in x days</td>
  </tr>
 </table>
 
## Custom

 <table>
  <tr>
    <th>Name</th>
    <th>Example</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>name</td>
    <td>heartbeat</td>
    <td>Custom check's name</td>
  </tr>
  <tr>
    <td>query</td>
    <td>up</td>
    <td>Prometheus query</td>
  </tr>
  <tr>
    <td>check.type</td>
    <td>equals</td>
    <td>Type of evaluation applied against value. Avilable: `equals`</td>
  </tr>
  <tr>
    <td>check.value</td>
    <td>1</td>
    <td>Value to be compared against query results, using `check.type` evaluation</td>
  </tr>
  <tr>
    <td>msg.0</td>
    <td>OK: heartbeat is up</td>
    <td>Message to be used when `value` evaluation is sucessful.</td>
  </tr>
  <tr>
    <td>msg.2</td>
    <td>CRITICAL: heartbeat is down</td>
    <td>Message to be used when not sucessful.</td>
  </tr>
  </table>

## Global Configuration Options
 <table>
  <tr>
    <th>Name</th>
    <th>Example</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>reported_by</td>
    <td>sbppapik8s</td>
    <td>hostname that shows up in sensu reported_by field</td>
  </tr>
  <tr>
    <td>occurrences</td>
    <td>3</td>
    <td>amount of failures before sensu will send an alert</td>
  </tr>
  <tr>
    <td>whitelist</td>
    <td>sbppapik8s.*</td>
    <td>regex used as a safety whitelist to make sure the source names are correct</td>
  </tr>
  </table>

## Check Configuration Options
 <table>
  <tr>
    <th>Name</th>
    <th>Config</th>
    <th>Example</th>
  </tr>
  <tr>
    <td>service</td>
    <td>
        name: servicename<br>
        state: active|deactivating|failed|inactive (default:active)<br>
        state_required: 0|1 (default:1)
    </td>
    <td>name: test-service.service</td>
  </tr>
  <tr>
    <td>memory</td>
    <td>
      warn: warning percentage<br>
      crit: critical percentage
   </td>
    <td>
      warn: 90 <br>
      crit: 95
   </td>
  </tr>
  <tr>
    <td>load_per_cpu</td>
    <td>
      warn: warning percentage <br>
      crit: critical percentage
   </td>
    <td>
      warn: 90 <br>
      crit: 95
   </td>
  </tr>
  <tr>
    <td>load_per_cluster</td>
    <td>
      cluster: cluster name <br>
      warn: warning percentage <br>
      crit: critical percentage <br>
      source: name that shows in sensu
   </td>
    <td>
      cluster: nodes <br>
      warn: 90 <br>
      crit: 95 <br>
      source: sbppapik8s
   </td>
  </tr>
  <tr>
    <td>load_per_cluster_minus_n</td>
    <td>
      cluster: cluster name <br>
      minus_n: amount of member failures <br>
      warn: warning percentage <br>
      crit: critical percentage <br>
      source: name that shows in sensu
   </td>
    <td>
      cluster: nodes <br>
      minus_n: 1 <br>
      warn: 90 <br>
      crit: 95 <br>
      source: sbppapik8s
   </td>
  </tr>
  <tr>
    <td>inode</td>
    <td>
      mount: mountpoint <br>
      name: human readable name <br>
      warn: warning percentage <br>
      crit: critical percentage
   </td>
    <td>
      mount: /var/lib/docker <br>
      name: docker <br>
      warn: 90 <br>
      crit: 95
   </td>
  </tr>
  <tr>
    <td>disk</td>
    <td>
      mount: mountpoint <br>
      name: human readable name <br>
      warn: warning percentage <br>
      crit: critical percentage
   </td>
    <td>
      mount: /var/lib/docker <br>
      name: docker <br>
      warn: 90 <br>
      crit: 95
   </td>
  </tr>
  <tr>
    <td>disk_all</td>
    <td>
      ignore_fs: regex of filesystems <br>
      warn: warning percentage <br>
      crit: critical percentage
   </td>
    <td>
      ignore_fs: tmpfs <br>
      warn: 90 <br>
      crit: 95
   </td>
  </tr>
  <tr>
    <td>predict_disk_all</td>
    <td>
      range_vector: Prometheus range vector used for sample size of prediction
      filter: prometheus filter to include/exclude disks<br>
      days: prediction days
      source: sensu name
   </td>
    <td>
      range_vector: 24h <br>
      filter: {mountpoint="/"}<br>
      days: 14
      source: sbppapik8s
   </td>
  </tr>
 </table>
