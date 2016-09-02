# Sensu Kubernetes Prometheus Plugin

## Description
Sensu plugin designed to query prometheus data output from node-exporter

## Usage
`check_prometheus.rb /path/to/config.yml`

## Development and testing

Dependencies: docker, docker-compose

To spinup a development stack and run the integration tests
`ruby test.rb`

Afterwards you can just run `rspec` to run the tests

### Config.yml
Check configuration is defined in the `config.yml` file under the key `checks`

Example
```
config:
  reported_by: sbppapik8s
  occurences: 3
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
    <td>occurences</td>
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
    <td>name: servicename</td>
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
      days: prediction days
      source: sensu name
   </td>
    <td>
      days: 14
      source: sbppapik8s
   </td>
  </tr>
 </table>
