# ec2dnsserver cookbook

Uses the AWS API to build bind zone files to reference all of the nodes in your cluster using their tagged names and internal IPs.

# Requirements

* Fog gem (to call the EC2 API and get node tags)
* IPAddress gem (for some IP address parsing)
* Rsyslog (if you want to use syslog logging)

# Necessary changes to the chef-client

This cookbook sets the `node['chef_client']['interval']` and `node['chef_client']['splay']` attributes which are read by the chef-client cookbook to make chef-client run more rapidly.  If you are not using the chef-client cookbook, you may want to find some other way to adjust the chef run interval so that your DNS stay reasonably up to date.

# Known Issues

* Currently only supports IPv4
* Currently only supports RSyslog
* Possibly more complicated to use than it really should be

## Required Permissions

Create an IAM user with the following permissions:

    {
      "Version": "2014-03-12",
      "Statement": [
        {
          "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeNetworkInterface*",
            "ec2:DescribeVpcs"
          ],
          "Resource": [
            "*"
          ],
          "Effect": "Allow"
        }
      ]
    }

# Usage

There are essentially two supported ways to use the ec2dnsserver cookbook.  One
is to include the recipe via `include_recipe` and the other is via the
ec2dnsserver_zone resource, like so:

## ec2dnsserver_zone Resource

    execute 'reload_zones' do
      command 'rndc reload'
      action :nothing
    end

    ec2dnsserver_zone "priv.yourdomain.local" do
      vpcs %w(vpc-1a2b3c4d)
      stub false
      ptr false
      suffix "priv.yourdomain.local"
      static_records(
        'hostname' => {
          'cookbook' => 'some_cookbook'
        }
      )
      avoid_subnets %w(subnet-1a2b3c4d)
      contact_email 'hostmaster@yourcompany.com'
      path '/etc/bind/db.priv.yourdomain.local'
      notifies :run, 'execute[reload_zones]'
    end

### Properties explained

* **apex (name attribute)** - The zone apex.
* **vpcs** - This is the list of VPCs from which to include zone data (default: [])
* **avoid_subnets** - IPs for network adapters in these subnets will not be used to generate the zone
* **path** - The location of the zone file (default: `#{node['ec2dnsserver']['zones_dir']}/db.#{apex}`)
* **stub** - Set to `true` if this is to be a "stub" zone.  A stub zone is a zone with only one A record at the zone apex.  It is useful for overriding FQDNs in zones for which your DNS server is not authoritative.
* **suffix** - Name to append to any tagged names found in your EC2 cluster.  E.g. In PTR zones, records will be constructed as "4.3.2.1.in-addr.arpa IN PTR ec2servername.suffix".  Defaults to the zone apex if not specified.
* **ptr** - True if this is a PTR (reverse lookup) zone (default: false)
* **static_records** - A hash describing extra records to be appended to the zone (See `static_records` section)
* **ns_zone** - The parent zone of the name server (NS) record for this zone.  (default: value of **suffix**)

#### Properties pertaining specifically to the SOA record (See: http://www.zytrax.com/books/dns/ch8/soa.html).  *All times are in seconds.*

* **source_host** - The host used for the SOA record name server field (default: node.name)
* **default_ttl** - The default time-to-live (i.e. cache timeout) for the zone in seconds (default: 300)
* **contact_email** - The hostmaster's email address (REQUIRED)
* **refresh_time** - Timeout before the slave will try to refresh the zone from the master (default: 3600)
* **retry_time** - Time between retries if the slave fails to contact the master when *refresh* (above) has expired (default: 600)
* **expire_time** - Indicates when the zone data is no longer considered authoritative (default: 86400)
* **nxdomain_ttl** - How long a bad lookup (e.g. one that finds nothing) is cached (default: 300)

## static_records

This section describes the format of the hash used to define static records.  Basically they look like this:

### To define the base of a "stub" (aka. override) zone
    {
      "value": "1.1.1.1",
      "type": "A"
    }

### To use a cookbook or a role to create a dynamic mapping
    {
      "hostname": {
        "cookbook": "cookbook_name"
      }
    }

### Or a role
    {
      "hostname": {
        "role": "role_name"
      }
    }

## zones

This section describes the format of the *keyed hash* used to define zones (by way of the `node['ec2dnsserver']['zones']` attribute).  The format looks like the following...

### Simplest possible primary zone config:
    {
      "priv.yourdomain.local": {}
    }

### Simplest possible PTR config:
    {
      "10.in-addr.arpa": {
        "ptr_zone": true,
        "suffix": "priv.yourdomain.local"
      }
    }

### For a standard, primary zone with some *static records* that uses VPCs:
    {
      "priv.yourdomain.local": {
        "ptr_zone": false,
        "primary": true,
        "static_records": {
          "stage-storm": {
            "cookbook": "et_ops_haproxy"
          }
        },
        "vpcs": [
          "vpc-1a2b3c4d"
        ]
      }
    }

### For a PTR zone:
    {
      "10.in-addr.arpa": {
        "ptr_zone": true,
        "suffix": "priv.yourdomain.local",
        "primary": false,
        "vpcs": [
          "vpc-1a2b3c4d"
        ]
      }
    }

### For a stub zone that uses a cookbook search to build its apex record:
    {
      "test-cookbook-host.anotherdomain.com": {
        "stub": true,
        "suffix": "priv.yourdomain.local",
        "primary": false,
        "static_records": {
          "cookbook": "et_ops_haproxy"
        }
      }
    }

### For a stub zone that uses a statically defined IP address for its apex record:
    {
      "test-value-host.anotherdomain.com": {
        "stub": true,
        "suffix": "priv.yourdomain.local",
        "primary": false,
        "static_records": {
          "value": "1.1.1.1",
          "type": "A"
        }
      }
    }

# Attributes

*All attributes fall under the **['ec2dnsserver']** hash key.*

* **['user']** - User that bind will run under.  (default: bind)
* **['group']** - Grou that bind will run under.  (default: bind)
* **['aws_api_user']** - User that ec2dnsserver will use to interact with the EC2 API (in fact this is currently only used as the key to lookup the real keys in the API keys data bag).  (default: Ec2DnsServer)
* **['config_dir']** - The bind config path (default: /etc/bind)
* **['cache_dir']** - The bind cache directory (default: /var/cache/bind)
* **['zones_dir']** - Where the zone files live (default: value of **['config_dir']**)
* **['contact_email']** - The hostmaster's email address (default: nil)
* **['dnssec_validation']** - Sets the flag by the same name in bind conf (See: [DNS BIND9 Security Statements](http://www.zytrax.com/books/dns/ch7/security.html)) (default: no)
* **['avoid_subnets']** - IPs for network adapters in these subnets will not be used to generate the zone.  (default: [])
* **['recursion_clients']** - Array of CIDR-formatted network addresses that will be allowed to do recursive queries against the nameserver.  (attribute default is [] but template automatically includes localhost, 10/8, and localnets)
* **['zones']** - Use this to pass a list of zones to the cookbook instead of using the resource.  See **zones** section.

## Logging Attributes
* **['log']['log_queries']** - Enable logging of every single query (warning: disk space monster).  (default: false)
* **['log']['facility']** - Which syslog facility to use.  (default: daemon)
* **['log']['versions']** - How many old log files to keep.  (default: 5)
* **['log']['size']** - Max log file size.  (default: 25M)
* **['log']['logger']** - Which log config recipe to use.  (default and currently the only one supported: rsyslog)
* **['log']['severity']** - Which severity to attach to syslog messages.  (default: dynamic)
* **['log']['file']** - File to send logs to when not using syslog.  (default: /var/log/named/named.log)

# Recipes

The only one you care about is `default`.  `rsyslog` (and any future sys logger dependencies) are brought in as dependencies automatically.

# Author

Author:: EverTrue, Inc. (<devops@evertrue.com>)
