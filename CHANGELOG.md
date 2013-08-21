## 1.0.10:

* Only display "forwarders" section in named.conf if "forwarders" array has non-zero value

## 1.0.9:

* Started doing a changelog
* Validate hostnames according to http://en.wikipedia.org/wiki/Hostname (essential because many things--like spaces--are valid in EC2 "Name" tags that aren't allowed as hostnames)
* Shorten chef-client interval to 300s and splay to 180s
* Switched to use_inline_resources for resource notification in Zone provider
