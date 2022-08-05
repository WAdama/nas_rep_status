#!/bin/bash
# Version 1.1

source $1
LOGPATH="/var/log"
LOGS=$(ls -1r $LOGPATH/synolog/synodr.*[!.xz])
echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
if [[ ! -z "$SHAREREPS" ]]
then
for SHAREREP in "${SHAREREPS[@]}"
do
CONTENT=$(awk "/folder/ && /replication/ && /$(echo $SHAREREP | sed 's/\$//')/" $LOGS | tail -1)
case $CONTENT in
	*"completed"*) STATUS="1" ;;
	*"Created"*) STATUS="2" ;;
	*"Failed"*) STATUS="3" ;;
	*) STATUS="0" ;;
esac
ACTTIME=$(date +%s)
if [ "${CONTENT}" ] && [ ! $STATUS == 2 ]; then
	TIME=$(echo $CONTENT | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
	TIMEEND=$(date -d "$TIME" +%s)
	LASTRUN=$(($ACTTIME - $TIMEEND))
fi
echo "<result><channel>Share $SHAREREP: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>Share $SHAREREP: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>"
done
fi

if [[ ! -z "$LUNREPS" ]]
then
for LUNREP in "${LUNREPS[@]}"
do
CONTENT=$(awk "/LUN/ && /replication/ && /$LUNREP/" $LOGS | tail -1)
case $CONTENT in
	*"completed"*) STATUS="1" ;;
	*"Created"*) STATUS="2" ;;
	*"Failed"*) STATUS="3" ;;
	*) STATUS="0" ;;
esac
ACTTIME=$(date +%s)
if [ "${CONTENT}" ] && [ ! $STATUS == 2 ]; then
	TIME=$(echo $CONTENT | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")
	TIMEEND=$(date -d "$TIME" +%s)
	LASTRUN=$(($ACTTIME - $TIMEEND))
fi
echo "<result><channel>LUN $LUNREP: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>LUN $LUNREP: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>"
done
fi
echo "</prtg>"
exit
