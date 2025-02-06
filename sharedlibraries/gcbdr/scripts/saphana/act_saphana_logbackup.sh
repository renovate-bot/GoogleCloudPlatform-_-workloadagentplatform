#!/bin/bash

# =============================================================================
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================

set -x
DBSID=$1
DBUSER=$2

dbsid=`echo $DBSID |tr '[A-Z]' '[a-z]'`
dbsidadm=$dbsid'adm'

########### Function to check if the log switch runs more than min ##################
logswitchstatus()
{
  logswitchpid=$1
  count=1

  waitflag=true
  while $waitflag
  do
    pidstatus=`ps -ef | grep -w $logswitchpid |grep -v grep | grep -ivwE "hdbindexserver|hdbnameserver|hdbcompileserver|hdbpreprocessor|hdbxsengine|hdbdiserver|hdbscriptserver|hdbdocstore|hdbrsutil" |wc -l`
    if [ "$pidstatus" -gt 0 ]; then
       echo "Log switch is still running!"
       sleep 1
       count=$(($count+1))
       if [ "$count" -ge 60 ]; then
          echo "Log switch did not complete in 1 min, killing the switch process!"
          kill -9 $logswitchpid
       fi
    else
       waitflag=false
       echo "Log switch complete!"
    fi
  done
}

########## MAIN #############
INSTANCENUM=`env | grep TINSTANCE= | cut -d"=" -f2`

if [ -z "$INSTANCENUM" ]; then
   INSTANCENUM=`basename $DIR_INSTANCE | rev | cut -c 1-2 | rev`
fi

if [ -z "$INSTANCENUM" ]; then
   echo "ERRORMSG: Failed to get INSTANCE#, Please check!"
   exit 1
fi
globalpath=`echo $DIR_INSTANCE`
globalpath=`dirname $globalpath`

SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

HVERSION=`HDB version | grep -i version: | cut -d':' -f2 | sed -e 's/^[ \t]*//'`
HVERSION=`echo $HVERSION | cut -c1-3`

############ Check logbackup disk free space ##################

logbackup_path=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_logbackup =|basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`

if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
   #ismountpoint="$(mountpoint $logbackup_path)"
   #retval=$?
   #if [[ "$retval" -gt 0 ]]; then
   #   echo "ERRORMSG: For PD based log backup, $logbackup_path must be mountpoint, should not include any sub directories"
   #   exit 13
   #fi
   if [[ "$logbackup_path" =~ "/hana/shared" ]] || [[ "$logbackup_path" =~ "/usr/sap" ]]; then
      echo "ERRORMSG: For PD based log backup, $logbackup_path should not be under /hana/shared or /usr/sap location. Please re-configure the same"
      exit 13
   fi
fi

logbackup_path_freespace=`df -kh $logbackup_path | tail -1 |awk '{print $5}' |sed 's/%//g'`


############### Check if the Instance is running ###############

dbstatus=`sapcontrol -nr $INSTANCENUM -function GetSystemInstanceList | grep -Ei "GRAY|YELLOW" | wc -l`

if [ "$dbstatus" -gt 0 ]; then
   echo "ERRORMSG: Database status is not GREEN. Please check!"
   exit 1
fi

#### Validate logbackup path in the DB and global.ini ##############
SQL="select distinct string_agg(value,',' order by value) from sys_databases.m_inifile_contents where section='persistence' and key='basepath_logbackup' and LAYER_NAME in ('SYSTEM','DATABASE')"
LOGBACKUP_PATH_LIST=`$hdbsql -U $DBUSER -a -j -x "$SQL"`
LOGBACKUP_PATH_LIST="$(echo $LOGBACKUP_PATH_LIST | sed 's/"//g')"
for path in $(echo $LOGBACKUP_PATH_LIST |tr ',' ' ')
do
  if [[ "$path" != "$logbackup_path" ]]; then
     echo "ERRORMSG: The basepath_logbackup value ($logbackup_path) in the global.ini is not matching the database parameter basepath_logbackup value ($path). Please run hdbnsutil -reconfig command to synchornize the values"
     exit 13
  fi
done

if [ "$logbackup_path_freespace" -le "98" ]; then
   processid_list=`ps -ef | grep -iwE "hdbindexserver|hdbnameserver" | grep $dbsidadm | grep -v grep |awk '{print $2}'|xargs`

   for process_id in $processid_list
   do
     if [ "$HVERSION" = "1.0" ]; then
        SQL="select ACTIVE_STATUS from m_services where PROCESS_ID='$process_id'"
     else
        SQL="select ACTIVE_STATUS from sys_databases.m_services where PROCESS_ID='$process_id'"
     fi
     ACTIVE_STATUS=`$hdbsql -U $DBUSER -a  -C -j -x "$SQL"`
     if [ "$ACTIVE_STATUS" = "YES" ]; then
        timeout 60s hdbcons 'log backup' -p $process_id &
        logswitchpid=$!
        logswitchstatus $logswitchpid
     else
        SQL="select DATABASE_NAME||'-'||ACTIVE_STATUS from sys_databases.m_services where PROCESS_ID='$process_id'"
        ACTIVE_STATUS=`$hdbsql -U $DBUSER -a -j -x "$SQL"`
        echo "WARNINGMSG: Database is not in open state. Please check. $ACTIVE_STATUS"
     fi
   done
fi
echo "************************** end log backup post script ******************"
exit 0
