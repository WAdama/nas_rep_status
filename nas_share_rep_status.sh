#!/bin/bash
#Version 3.0.0
set -euo pipefail
IFS=$'\n\t'
#Functions
readlog() {
    [[ -e "$1" ]] || return
    if [[ $1 == *.xz ]]; then
        xz -dc "$1"
    else
        cat "$1"
    fi
}
get_status() {
    local result="$1"
    case "$result" in
        *"completed"*) echo 1 ;;
        *"Created"*) echo 2 ;;
        *"Failed"*) echo 3 ;;
        *) echo 0 ;;
    esac
}
#Get share replications and log files
mapfile -t SHAREREPS < <(sqlite3 -readonly -list -separator '|' /var/packages/SnapshotReplication/etc/replica.db "select target_id,plan_id from plan where target_type like 2")
mapfile -t SYNODRLOGS < <( ls -1r /var/log/synolog/synodr.log* )
SOURCE=$(hostname -s)
#Getting actual time
ACTTIME=$(date +%s)
#Create sensor
echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for SHAREREP in "${SHAREREPS[@]}"
do
IFS='|' read -r SHARENAME PLAN <<< "$SHAREREP"
LASTRUN=""
RUNTIME=""
if [ -z "$PLAN" ] 
then
  LASTRUN=""
  RUNTIME=""
  STATUS=0
else
  STATUS=2
  if [ -f "/var/packages/SnapshotReplication/etc/plan/$PLAN/sync_report" ]
  then
    mapfile -t RESULT < <(jq -r '.recent_records[-1] | .begin_time, .finish_time, .sync_size_byte' /var/packages/SnapshotReplication/etc/plan/"$PLAN"/sync_report)
    CONTENT=$(for f in "${SYNODRLOGS[@]}"; do
        readlog "$f"
    done | awk '/shared folder/ && /replication/ && /\['"$SOURCE:${SHARENAME//$/\\$}"'\]/ { line=$0 } END { print line }')
    TIME=$(date -d "$(echo "$CONTENT" | awk -F "\t" '{print $2}')" +%s)
    STATUS=$(get_status "$CONTENT")
    LASTRUN=$(("$ACTTIME"-"$TIME"))
    LASTSUCCESSRUN=$(("$ACTTIME"-"${RESULT[1]}"))
    RUNTIME=$(("${RESULT[1]}"-"${RESULT[0]}"))
    SPEED=$(("${RESULT[2]}"/"$RUNTIME"))
  fi
fi
echo "<result><channel>Share $SHARENAME: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result>
<result><channel>Share $SHARENAME: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
<result><channel>Share $SHARENAME: Last successful replication</channel><value>$LASTSUCCESSRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
<result><channel>Share $SHARENAME: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result>
<result><channel>Share $SHARENAME: Data replicated</channel><value>${RESULT[2]}</value><unit>BytesDisk</unit><VolumeSize>MegaByte</VolumeSize></result>
<result><channel>Share $SHARENAME: Speed</channel><value>$SPEED</value><unit>SpeedDisk</unit><SpeedSize>MegaByte</SpeedSize></result>"
done
echo "</prtg>"
exit