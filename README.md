# treb - time range regular expression builder for circular logs timestamp format, i. e. 'Jan  1 00:00:00'
usage: treb 'Jun 21 17:53:27' 'Aug 19 13:45:11' = ^(Jun (21 (17:(53:(2[7-9]|[3-5])|5[4-9])|1[89]|2)|2[2-9]|3)|Jul|Aug (19 (13:(45:(0|1[01])|[0-3]|4[0-4])|0|1[0-2])| |1[0-8]))
