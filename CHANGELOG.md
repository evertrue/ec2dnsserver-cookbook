# CHANGELOG for ec2dnsserver

## 2.2.2

* Add issues/source URLs and supports metadata

## 2.2.1

* Switch to Apache v2.0 license

## 2.2.0

* Add the ability to handle zone types besides "master"

## 2.1.3

* Fix Chef search to accommodate chef/chef#2312
* Move installation of `bind9` up to fix race condition ()
* Rubocop & Test Kitchen config cleanup
    - Still doesn’t test standalone

## 2.1.2:

* A bunch of library code cleanup
* attempt to create host records only for the networking interface that is first according to "deviceIndex" (as opposed to first according to random)

## 2.1.1:

* Fixed OR code to correctly set record types on static records

## 2.1.0:

* Enable zone transfers by IP

## 2.0.2:

* Delete set-bind-forwarders DHCP hook

## 2.0.1:

* Explicitly specify localhost in dig test

## 2.0.0:

* Don't put file logging properties in the query syslog config
* Convert to berkshelf 3
* Remove now-meaningless `node['ec2dnsserver']['vpc']` attribute
* Rename min_ttl to the more meaningful nxdomain_ttl
* Remove requirement that path be specified in resource
* Duplicate the full path under the template cache path in order to minimize the chances of conflict if a file name is re-used for whatever reason.
* Static records are not really required so the default recipe shouldn't fail if they're missing from the attributes
* Remove options that are not valid in syslog logs from syslog query logger
* Fix format of file parameter in query log config
* ptr is an optional resource parameter so it should also be an optional node attribute
* Don't handle undefined stub attribute in a way that is dumb
* Clean up handling of DNS suffixes in zones other than the parent zone of the name server
* Bump et_fog 1.0.4
* Create docs!
* Broke compatibility with old zones hash format
* Add reverse DNS test; Use regex for test response instead of string matching

## 1.5.0:

* Support multiple VPCs per DNS server and no VPC at all
* Get VPC CIDR block directly from ohai data rather tha via Fog.
* Allow forwarders override
* Define VPC(s) in zone config
* Refuse to run without EC2

## 1.4.0:

* Derive local VPC DNS IP if it is not hardcoded in an attribute

## 1.3.0:

* Optimize library for better testing

## 1.2.0:

* Add static_records function

## 1.1.2:

* Removed EverTrue's email from the default

## 1.1.1:

* Use external fog cookbook
* Add recursion clients default null value

## 1.1.0:

* Add recursion clients parameter

## 1.0.13:

* Pass avoid_subnets to ec2 zone resource

## 1.0.12:

* log avoid_subnets value

## 1.0.11:

* Don't try to use IP addresses belonging to NICs on the "avoid subnets" list (prevents public subnets from receiving DNS entries)
* Break out query log (if enabled) into a separate non-syslog file, in addition to sending it over the syslog link.
* Give up on using externally generated forwarders file
* Set more permissive mode on log dir

## 1.0.10:

* Only display "forwarders" section in named.conf if "forwarders" array has non-zero value

## 1.0.9:

* Started doing a changelog
* Validate hostnames according to http://en.wikipedia.org/wiki/Hostname (essential because many things--like spaces--are valid in EC2 "Name" tags that aren't allowed as hostnames)
* Shorten chef-client interval to 300s and splay to 180s
* Switched to use_inline_resources for resource notification in Zone provider
