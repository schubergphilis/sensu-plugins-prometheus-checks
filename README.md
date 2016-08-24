# Sensu Kubernetes Prometheus Plugin

## Description
Sensu plugin designed to query prometheus data output from node-exporter

## Usage
`check_prometheus.rb /path/to/config.yml`

### Config.yml
Check configuration is defined in the `config.yml` file under the key `checks`

Example
```
config:
  reported_by: sbppapik8s
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
    <td><li>name: servicename</li></td>
    <td><li>name: test-service.service</li></td>
  </tr>
  <tr>
    <td>memory</td>
    <td>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
   </td>
    <td>
      <li>warn: 90</li>
      <li>crit: 95</li>
   </td>
  </tr>
  <tr>
    <td>load_per_cpu</td>
    <td>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
   </td>
    <td>
      <li>warn: 90</li>
      <li>crit: 95</li>
   </td>
  </tr>
  <tr>
    <td>load_per_cluster</td>
    <td>
      <li>cluster: cluster name</li>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
      <li>source: name that shows in sensu</li>
   </td>
    <td>
      <li>cluster: nodes</li>
      <li>warn: 90</li>
      <li>crit: 95</li>
      <li>source: sbppapik8s</li>
   </td>
  </tr>
  <tr>
    <td>load_per_cluster_minus_n</td>
    <td>
      <li>cluster: cluster name</li>
      <li>minus_n: amount of member failures</li>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
      <li>source: name that shows in sensu</li>
   </td>
    <td>
      <li>cluster: nodes</li>
      <li>minus_n: 1</li>
      <li>warn: 90</li>
      <li>crit: 95</li>
      <li>source: sbppapik8s</li>
   </td>
  </tr>
  <tr>
    <td>inode</td>
    <td>
      <li>mount: mountpoint</li>
      <li>name: human readable name</li>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
   </td>
    <td>
      <li>mount: /var/lib/docker</li>
      <li>name: docker</li>
      <li>warn: 90</li>
      <li>crit: 95</li>
   </td>
  </tr>
  <tr>
    <td>disk</td>
    <td>
      <li>mount: mountpoint</li>
      <li>name: human readable name</li>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
   </td>
    <td>
      <li>mount: /var/lib/docker</li>
      <li>name: docker</li>
      <li>warn: 90</li>
      <li>crit: 95</li>
   </td>
  </tr>
  <tr>
    <td>disk_all</td>
    <td>
      <li>ignore_fs: regex of filesystems</li>
      <li>warn: warning percentage</li>
      <li>crit: critical percentage</li>
   </td>
    <td>
      <li>ignore_fs: tmpfs</li>
      <li>warn: 90</li>
      <li>crit: 95</li>
   </td>
  </tr>
 </table>
