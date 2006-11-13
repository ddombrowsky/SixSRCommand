
notes on SixSRCommand
---

* make sure mod_env and mod_rewrite are installed in apache

* this error message ->
	[Sun Nov 12 23:39:21 2006] [error] [client 192.168.1.7] malformed header from script. Bad header=current startrow = 0: dispatch.cgi, referer: http://www.6thstreetradio.org/SixSRCommand/track/

	is caused by puts() commands in the ruby scripts.  Using WEBrick, this doesn't cause a 
	problem.  But once you get it into apache, they are interpreted as headers, and break things.

