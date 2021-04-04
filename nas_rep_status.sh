#!/bin/bash
# Version 1.0.0

CONF=$1
source $CONF

echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
if [[ ! -z "$SHAREREPS" ]]
then
for SHAREREP in "${SHAREREPS[@]}"
do
CONTENT=`cat $LOG | grep -E 'folder replication|$SHAREREP' | tail -1`
if [ -z "${CONTENT}" ]; then
	CONTENT=`cat $LOG | grep -E 'folder replication|$SHAREREP' | tail -1`
fi
if [[ $CONTENT == *"completed"* ]]; then
	STATUS="1"
	elif [[ $CONTENT == *"Failed"* ]]; then
	STATUS="2"
	else
	STATUS="0"
fi
ACTTIME=`date +%s`
TIME=`echo $CONTENT | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}"`
TIMEEND=`date -d "$TIME" +%s`
LASTRUN=$(($ACTTIME - $TIMEEND))
echo "<result><channel>Share $SHAREREP: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>Share $SHAREREP: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>"
done
fi

if [[ ! -z "$LUNREPS" ]]
then
for LUNREP in "${LUNREPS[@]}"
do
CONTENT=`cat $LOG | grep -E 'folder replication|$LUNREP' | tail -1`
if [ -z "${CONTENT}" ]; then
	CONTENT=`cat $LOG | grep -E 'folder replication|$LUNREP' | tail -1`
fi
if [[ $CONTENT == *"completed"* ]]; then
	STATUS="1"
	elif [[ $CONTENT == *"Failed"* ]]; then
	STATUS="2"
	else
	STATUS="0"
fi
ACTTIME=`date +%s`
TIME=`echo $CONTENT | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}"`
TIMEEND=`date -d "$TIME" +%s`
LASTRUN=$(($ACTTIME - $TIMEEND))
echo "<result><channel>LUN $LUNREP: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>LUN $LUNREP: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>"
done
fi
echo "</prtg>"
exit
