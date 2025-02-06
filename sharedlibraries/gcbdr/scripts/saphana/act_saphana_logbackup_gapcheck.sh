#!/bin/sh

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
DBSID=$DBSID
PREVLOG_BEGINTIME=$PREVLOG_BEGINTIME
PD_UPLOADTIME=$PD_UPLOADTIME
USERSTOREKEY=$DBUSER
REMOVAL_HOURS=$DELETE_LOGFILES_HOURS
PD_STARTTIME=$PD_STARTTIME

#DBSID=pds
#START_TIME='2023-07-07 10:15:00'
#END_TIME='2023-07-07 20:15:00'
#USERSTOREKEY=ACTBACKUP

LOWERDBSID=`echo $DBSID | tr '[A-Z]' '[a-z]'`
UPPERDBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
DBUSER="$LOWERDBSID"'adm'
dbuser=$DBUSER
source /act/custom_apps/saphana/act_saphana_comm_func.sh

logbackup_exists()
{
  logbackupname=$1
  if [ -f $logbackupname ]; then
     continue
  else
     #echo "ERRORMSG: $logbackupname is deleted and not available for the backup."
     #exit 1
     return 1
  fi
}

#check_logpurge_count()
#{
#  vdate=`echo $PD_STARTTIME | awk '{print $1}'`
#  vtime=`echo $PD_STARTTIME | awk '{print $2}'`
#  LOGPURGE_FROM_TIME=`date -d "$vtime $vdate -$REMOVAL_HOURS hours" +"%Y-%m-%d %H:%M:%S"`
#  LOGBACKUPPATH=`grep -iw ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
#  LOGCOUNT=`find $LOGBACKUPPATH -name "log_backup_*" -type f ! -newermt "$LOGPURGE_FROM_TIME" | wc -l`
#  echo $LOGCOUNT
#}

FILELOC="/act/touch/"
if [ ! -d "$FILELOC" ]; then
   mkdir -p $FILELOC
   chmod 755 $FILELOC
else
   chmod 755 $FILELOC
fi
if [ ! -d /act/touch/FAIL_MSG ]; then
   mkdir -p /act/touch/FAIL_MSG
   chown "$DBADM":sapsys /act/touch/FAIL_MSG
else
   rm -f /act/touch/FAIL_MSG/*
   chown "$DBADM":sapsys /act/touch/FAIL_MSG
fi
FAIL_MSG=/act/touch/FAIL_MSG

globalpath=`su - $DBUSER -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`
globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
configpath=$globalpath/SYS/global/hdb/custom/config

####################### Get Log backup path ##############################
LOGBACKUP_PATH=`grep -iw ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'|sort|uniq`
LOGBACKUP_LIST=/act/touch/.logbackup_list.txt

if [ ! -f $LOGBACKUP_LIST ]; then
   touch $LOGBACKUP_LIST
   chmod 755 $LOGBACKUP_LIST
   chown $DBUSER:sapsys $LOGBACKUP_LIST
else
   chmod 755 $LOGBACKUP_LIST
   chown $DBUSER:sapsys $LOGBACKUP_LIST
fi


if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

INSTANCENUM=`su - $DBUSER -c 'env | grep TINSTANCE= | cut -d"=" -f2'`
if [ -z "$INSTANCENUM" ]; then
   INSTANCENUM=`su - $DBUSER -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
fi

if [ -z "$INSTANCENUM" ]; then
   echo "ERRORMSG: Backup Pre Check: Unable to determine the instance number from HANA environment variables (TINSTANCE/DIR_INSTANCE)."
   exit 1
fi

HVERSIONTMP=`echo $HANAVERSION |sed 's/\.//g'`
if [ "$HVERSIONTMP" -lt "200000" ]; then
   PORTNO=3"$INSTANCENUM"15
else
   PORTNO=3"$INSTANCENUM"13
fi
if [ ! -z "$PORTNO" ]; then
   backup_check_connection "$USERSTOREKEY" "$DBSID" "$PORTNO" "$FAIL_MSG"
fi

##################### Get list of Tenant databases ########################
SQL="select string_agg(database_name,',')  from m_databases"
DBNAMES=`su - $DBUSER -c "$hdbsql -U $USERSTOREKEY -a -j -x \"$SQL\""`

DBNAMES=`echo $DBNAMES | sed 's/"//g'`

#################### Log gap check window ################################
SQL="select days_between('$PREVLOG_BEGINTIME','$PD_UPLOADTIME') from dummy"
DURATION_OF_LOGGAPCHECK=`su - $DBUSER -c "$hdbsql -U $USERSTOREKEY -a -j -x -C \"$SQL\""`

#################### Check catalog data retention #########################
SQL="select days_between(min(SYS_START_TIME),max(SYS_START_TIME)) from sys_databases.m_backup_catalog;"
DURATION_OF_CATALOG=`su - $DBUSER -c "$hdbsql -U $USERSTOREKEY -a -j -x -C \"$SQL\""`

#################### Check if catalog has enough data to check log gap #################
if [ "$DURATION_OF_CATALOG" -lt "$DURATION_OF_LOGGAPCHECK" ]; then
   echo "WARNINGMSG: Unable to check the log gap as the catalog information is purged"
   exit 0
fi

####################################################################################
# Check the log gap for each tenant
# and capture minimum commit time as recovery range
####################################################################################
RECOVERYRANGE=
LOGGAP=0

if [ -z "$DBNAMES" ]; then
   echo "ERROMSG: Unable to query the Database names due to the error $errormsg"
   exit 1
else
   for TSID in $(echo $DBNAMES | tr ',' ' ' )
   do
     # SQL="select UTC_LAST_COMMIT_TIME,DESTINATION_PATH from sys_databases.m_backup_catalog_files a, sys_databases.m_backup_catalog b where b.ENTRY_TYPE_NAME='log backup' and UTC_LAST_COMMIT_TIME > '$START_TIME' and a.backup_id=b.backup_id and b.state_name='successful' and a.DATABASE_NAME='$TSID'"

     ############ SQL to get the log backup details from backup catalog ###################
     SQL="select UTC_LAST_COMMIT_TIME,DESTINATION_PATH from sys_databases.m_backup_catalog_files a, sys_databases.m_backup_catalog b where b.ENTRY_TYPE_NAME='log backup' and UTC_LAST_COMMIT_TIME is not null and b.SYS_START_TIME between '$PREVLOG_BEGINTIME' and '$PD_STARTTIME' and a.backup_id=b.backup_id and b.state_name='successful' and a.DATABASE_NAME='$TSID' order by UTC_LAST_COMMIT_TIME"

     su - $DBUSER -c "$hdbsql -U $USERSTOREKEY -a -j -x \"$SQL\"" > $LOGBACKUP_LIST
     sed -i 's/"//g' $LOGBACKUP_LIST
     set +x
     while read line
     do
       COMMIT_TIME=`echo $line | awk -F"," '{print $1}'`
       logbackup_fname=`echo $line | awk -F"," '{print $2}'`
       echo "Checking if $line exists for the backup"
       logbackup_exists $logbackup_fname
       if [ "$?" -gt 0 ]; then      ######## If not found ########
          echo "Log backup $logbackup_fname does not exists: Recovery Range: $PREV_COMMIT_TIME"
          echo "NEWRECOVERYRANGE:$PREV_COMMIT_TIME"
         # exit 1
          LOGGAP=1
          break;
       else
          PREV_COMMIT_TIME="$COMMIT_TIME"
       fi
     done < $LOGBACKUP_LIST
     set -x
     if [ ! -z "$RECOVERYRANGE" ] && [ ! -z "$PREV_COMMIT_TIME" ]; then
        EPOC_COMMIT_TIME=`date -d "$PREV_COMMIT_TIME" +"%s"`
        EPOC_RECOVERYRANGE=`date -d "$RECOVERYRANGE" +"%s"`
        echo "EPOC_COMMIT_TIME :$EPOC_COMMIT_TIME"
        echo "EPOC_RECOVERYRANGE:$EPOC_RECOVERYRANGE"
        if [ "$EPOC_COMMIT_TIME" -lt "$EPOC_RECOVERYRANGE" ]; then
           RECOVERYRANGE=$PREV_COMMIT_TIME
        fi
     else
        RECOVERYRANGE=$PREV_COMMIT_TIME
     fi
     if [[ "$LOGGAP" == "1" ]]; then
        break;
     fi
   done
fi
if [[ ! -z "$RECOVERYRANGE" ]]; then
   RECOVERYRANGE=`date -d "$RECOVERYRANGE" +"%s"`
fi

#LOGPURGECOUNT="$(check_logpurge_count)"
#if [ "$LOGPURGECOUNT" -gt 0 ]; then
##   LOGPURGE=1
#else
#   LOGPURGE=0
#fi

echo "RECOVERYRANGE=$RECOVERYRANGE"
echo "LOGGAPFLAG=$LOGGAP"
#echo "LOGPURGE=$LOGPURGE"

if [ -f $LOGBACKUP_LIST ]; then
   rm -f $LOGBACKUP_LIST
fi

exit 0
