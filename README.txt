Blamewidth
===

I use this script with a rails application to monitor bandwidth of my office network. I can connect to my linux server with iptables via ssh and get a snapshot of my network usage.
This a modified script written first by stevie@slowbicycle.com.
I used SSH instead Telnet and added support to monitor bandwidth speed.

Todo list:
===

* We need get the original code, add support to ssh on top of it instead rewrite the module
* Add rspec or test/unit tests
* Package in a gem or plugin
* Add connection exception treatment
* Remove singleton pattern. I only use this for my rails application. 
* Refactory the code ;)

Basic usage:
===

require 'blamewidth'

# initialize blamewidth
b = Blamewidth.instance

# setup monitoring for ip range 192.168.0.100 - 150
array_of_ips = (0..50).to_a.map{|i| "192.168.0.#{100 + i}"}
or
array_of_ips = ["192.168.0.5", "192.168.0.20", "192.168.0.230", "192.168.0.100", "192.168.0.101", "192.168.0.103", "192.168.0.130", "192.168.0.140", "192.168.0.150", "192.168.0.160", "192.168.0.170", "192.168.0.180"]
b.setup('192.168.0.1', 'root', 'secretpassword', array_of_ips)

# print list of hogs, sorted by biggest consumer first
b.blame

# reset bandwidth stats
b.reset

# disconnect
b.disconnect