#!/bin/bash
#Version 3.1.0
set -euo pipefail
IFS=$'\n\t'
API=$(which synowebapi)
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
get_type() {
    local type="$1"
    case "$type" in
        "1") echo LUN ;;
        "2") echo Share ;;
    esac
}
replace_lun_uuid_with_name() {
    declare -A LUN_MAP
    while IFS="|" read -r uuid name; do
        [[ -n "$uuid" && -n "$name" ]] && LUN_MAP["$uuid"]="$name"
    done <<< "$LUNS"
    local i target_id plan_id target_type

    for i in "${!REPS[@]}"; do
        IFS="|" read -r target_id plan_id target_type <<< "${REPS[$i]}"

        if [[ "$target_type" == "1" ]]; then
            if [[ -n "${LUN_MAP[$target_id]}" ]]; then
                target_id="${LUN_MAP[$target_id]}"
            fi
        fi

        REPS[i]="${target_id}|${plan_id}|${target_type}"
    done
}
#Get share replications and log files
mapfile -t REPS < <(sqlite3 -readonly -list -separator '|' /var/packages/SnapshotReplication/etc/replica.db "select target_id,plan_id,target_type from plan")
LUNS=$($API -s --exec api=SYNO.Core.ISCSI.LUN version=1 method=list | jq -r '.data.luns[] | "\(.uuid)|\(.name)"')
replace_lun_uuid_with_name
mapfile -t SYNODRLOGS < <( ls -1r /var/log/synolog/synodr.log* )
SOURCE=$(hostname -s)
#Getting actual time
ACTTIME=$(date +%s)
#Create sensor
echo "<?xml version=\"10.0\" encoding=\"UTF-8\" ?><prtg>"
for REP in "${REPS[@]}"
do
IFS='|' read -r NAME PLAN TARGET <<< "$REP"
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
    done | awk '(/shared folder/ || /iSCSI LUN/) && /replication/ && /\['"$SOURCE:${NAME//$/\\$}"'\]/ { line=$0 } END { print line }')
    TIME=$(date -d "$(echo "$CONTENT" | awk -F "\t" '{print $2}')" +%s)
    STATUS=$(get_status "$CONTENT")
    LASTRUN=$(("$ACTTIME"-"$TIME"))
    LASTSUCCESSRUN=$(("$ACTTIME"-"${RESULT[1]}"))
    RUNTIME=$(("${RESULT[1]}"-"${RESULT[0]}"))
    SPEED=$(("${RESULT[2]}"/"$RUNTIME"))
    TYPE=$(get_type "$TARGET")
  fi
fi
echo "<result><channel>$TYPE $NAME: Last status</channel><value>$STATUS</value><ValueLookup>prtg.standardlookups.nas.repstatus</ValueLookup><ShowChart>0</ShowChart></result>
<result><channel>$TYPE $NAME: Last run</channel><value>$LASTRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
<result><channel>$TYPE $NAME: Last successful replication</channel><value>$LASTSUCCESSRUN</value><unit>TimeSeconds</unit><LimitMode>1</LimitMode><LimitMaxWarning>129600</LimitMaxWarning><LimitMaxError>216000</LimitMaxError></result>
<result><channel>$TYPE $NAME: Runtime</channel><value>$RUNTIME</value><unit>TimeSeconds</unit></result>
<result><channel>$TYPE $NAME: Data replicated</channel><value>${RESULT[2]}</value><unit>BytesDisk</unit><VolumeSize>MegaByte</VolumeSize></result>
<result><channel>$TYPE $NAME: Speed</channel><value>$SPEED</value><unit>SpeedDisk</unit><SpeedSize>MegaByte</SpeedSize></result>"
done
echo "</prtg>"
exit