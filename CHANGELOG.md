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
