# opennms-alarmhistory
small config snippets to create a history on OpenNMS alarms

## functionality
By default, an OpenNMS alarm will be deleted from the OpenNMS database after it was cleared. The
SQL- and configuration snippets in this repository will create an alarms\_history database table,
which tracks each alarm with the related user actions and timestamps.

## setup
Execute create.sql in your OpenNMS database. Use the vacuumd-configuration.xml.snippet to delete old
alarms from the history table after 45 days, if you want. 

## supported OpenNMS versions
This version was developed and tested with OpenNMS Meridian 2017. It may/should work with other versions, too.
