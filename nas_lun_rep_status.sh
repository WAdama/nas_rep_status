#!/bin/bash
#Version 2.0.2

mapfile -t LUNREPS < <(sqlite3 /volume1/@appconf/SnapshotReplication/replica.db "select target_id,plan_id from plan where target_type like '1'")
mapfile -t SYNODRLOGS < <( ls -1r /var/log/synolog/synodr.*[!.xz] )
echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for LUNREP in "${LUNREPS[@]}"
do
IFS="|" read -r LUNUUID PLAN <<< "$LUNREP"
LUNNAME=$(grep -wns "$LUNUUID" /volume1/@iSCSI/LUN/iscsi_lun.conf -B 1 | head -n 1 | cut -d "=" -f2)
if [ -z "$PLAN" ] 
then
  LASTRUN=""
  RUNTIME=""
  STATUS="0"
else
  STATUS="2"
  if [ -f "/volume1/@appconf/SnapshotReplication/plan/$PLAN/sync_report" ]
  then
    mapfile -t RESULT < <(jq .recent_records[-1] < /volume1/@appconf/SnapshotReplication/plan/"$PLAN"/sync_report | jq -r .begin_time,.finish_time,.is_success,.sync_size_byte)
    CONTENT=$(awk "/iSCSI LUN/ && /replication/ && /${LUNNAME}/" "${SYNODRLOGS[@]}" | tail -1)
    TIME=$(date -d "$(echo "$CONTENT" | grep -o "[0-9]\{4\}/[0-9]\{2\}/[0-9]\{2\}\ [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}")" +%s)
    case $CONTENT in
        *"completed"*) STATUS="1" ;;
        *"Created"*) STATUS="2" ;;
        *"Failed"*) STATUS="3" ;;
        *) STATUS="0" ;;
    esac
    ACTTIME=$(date +%s)
    LASTRUN=$(("$ACTTIME"-"$TIME"))
    LASTSUCCESSRUN=$(("$ACTTIME"-"${RESULT[1]}"))
    RUNTIME=$(("${RESULT[1]}"-"${RESULT[0]}"))
    SPEED=$(("${RESULT[3]}"/"$RUNTIME"))
  fi
fi
echo "<result><channel>LUN $LUNNAME: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result><result><channel>LUN $LUNNAME: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>LUN $LUNNAME: Last successful replication</channel><value>$LASTSUCCESSRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result><result><channel>LUN $LUNNAME: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result><result><channel>LUN $LUNNAME: Data replicated</channel><value>${RESULT[3]}</value><unit>BytesDisk</unit><VolumeSize>MegaByte</VolumeSize></result><result><channel>LUN $LUNNAME: Speed</channel><value>$SPEED</value><unit>SpeedDisk</unit><SpeedSize>MegaByte</SpeedSize></result>"
done
echo "</prtg>"
exit
