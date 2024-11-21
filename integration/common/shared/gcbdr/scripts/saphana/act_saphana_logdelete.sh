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

# TODO: b/352296615 - Refactor GCBDR scripts to follow go/shell-style.
DBSID=$1
DBUSER=$2
PRETDBUSER=$3
# DBPORT=$4
# PORT=$5
DELLOG=$4
HANAVERSION=$5
USESYSTEMDBKEY=$6
ENDPIT="$7"
REMOVAL_HOURS=${8}
LASTBACKEDUPDBNAMES=${9}
SNAPSHOT_TYPE=${10}
# TODO: b/350656405 - Investigate if we need PORT or DBPORT as a parameter for
# the script. Also, if we need DBPORT to excute hdbsql commands.

DATE=`date`
set +x
if [ -z "$REMOVAL_HOURS" ]; then
   REMOVAL_HOURS=2
elif [ "$REMOVAL_HOURS" = "0" ]; then
     REMOVAL_HOURS=1
fi
set -x
######## Function to check if variable is empty #########
isempty()
{
   INPUT_VAR_NAME=$1
   INPUT_VAR_VALUE=$2
   if [ -z "$INPUT_VAR_VALUE" ]; then
       echo "ERRORMSG: Parameter $INPUT_VAR_NAME is empty. Please check!!"
       exit 1
   fi
}

######### END Function  ########

isempty DBUSER $DBUSER
isempty PRETDBUSER $PRETDBUSER
# isempty DBPORT $DBPORT
# isempty PORT $PORT
isempty DELLOG $DELLOG
isempty HANAVERSION $HANAVERSION
isempty USESYSTEMDBKEY $USESYSTEMDBKEY
set +x
isempty REMOVAL_HOURS $REMOVAL_HOURS
set -x
#isempty LASTBACKEDUPDBNAMES $LASTBACKEDUPDBNAMES


USESYSTEMDBKEY=`echo $USESYSTEMDBKEY | tr '[A-Z]' '[a-z]'`

if [ -z "$HANAVERSION" ]; then
   echo "ERRORMSG: HANAVERSION is missing"
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

HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "200000" ]; then
   MULTIDB=`grep "mode=" $globalpath/SYS/global/hdb/custom/config/global.ini |awk -F"=" '{print $2}'`
   MULTIDB=`echo $MULTIDB | tr '[A-Z]' '[a-z]' | xargs`
fi

FILE_NAME=/act/touch/hanabackupdblist.log
# dbnames=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j -x "select string_agg(database_name,',')  from m_databases"`
dbnames=`$hdbsql -U $DBUSER -a -j -x "select string_agg(database_name,',')  from m_databases"`
dbnames=`echo $dbnames | sed 's/"//g'`
echo -e "backedupdbnames:$dbnames" > $FILE_NAME

if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "200000" ] && [ "$MULTIDB" != "multidb" ]; then
   SQL="SELECT TOP 1 max(to_bigint(BACKUP_ID)) FROM SYS.M_BACKUP_CATALOG where SYS_START_TIME <= ADD_DAYS(CURRENT_TIMESTAMP, -$DELLOG) and ENTRY_TYPE_NAME in ('data snapshot','complete data backup') and STATE_NAME = 'successful' "
   # ID=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL | head -n1`
   ID=`$hdbsql -U $DBUSER -a -j $SQL | head -n1`
   ID=`echo ${ID} | sed -e 's/^[ \t]*//'`

  if [ "$ID" = "?" ]
  then
      echo "********** !!! WARNING !!!: no snapshot ID found to delete the log for database older then $DELLOG *********"
      #exit
      continue
  fi

  SQL="BACKUP CATALOG DELETE ALL BEFORE BACKUP_ID $ID COMPLETE "
  # /usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL
  $hdbsql -U $DBUSER -a -j $SQL

else
    # dbnames=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -x "select database_name from m_databases"`
    dbnames=`$hdbsql -U $DBUSER -x "select database_name from m_databases"`
    for i in ${dbnames}; do
       if [ $i = "DATABASE_NAME" ]; then
          :
       else
          TSID=`echo $i |awk -F '"' '{print $2}'`
          if [ $TSID = "SYSTEMDB" ]; then
             SQL="SELECT TOP 1 max(to_bigint(BACKUP_ID)) FROM SYS.M_BACKUP_CATALOG where SYS_START_TIME <= ADD_DAYS(CURRENT_TIMESTAMP, -$DELLOG) and ENTRY_TYPE_NAME in ('data snapshot','complete data backup') and STATE_NAME = 'successful' "
             # ID=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL | head -n1`
             ID=`$hdbsql -U $DBUSER -a -j $SQL | head -n1`
             ID=`echo ${ID} | sed -e 's/^[ \t]*//'`

             if [ "$ID" = "?" ]
             then
                echo "********** !!! WARNING !!!: no snapshot ID found to delete the log for systemdb database for older then $DELLOG *********"
                #exit
                continue
             fi
             echo "************************** delete systemdb log ******************"
             SQL="BACKUP CATALOG DELETE FOR SYSTEMDB ALL BEFORE BACKUP_ID $ID COMPLETE "
             # /usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL
             $hdbsql -U $DBUSER -a -j $SQL
             retval=$?
             if [ $retval -ne 0 ]; then
                echo "WARNINGMSG: Warning: Failed to delete the SYSTEMDB log for $DBSID database: check customapp-saphana.log for details"
             fi

          else
             if [ "$USESYSTEMDBKEY" = "true" ]; then
                TDBUSER=$DBUSER
                SQL="SELECT TOP 1 max(to_bigint(BACKUP_ID)) FROM SYS_DATABASES.M_BACKUP_CATALOG where SYS_START_TIME <= ADD_DAYS(CURRENT_TIMESTAMP, -$DELLOG) and ENTRY_TYPE_NAME in ('data snapshot','complete data backup') and DATABASE_NAME='$TSID' and STATE_NAME = 'successful'"
             else
                TDBUSER=$PRETDBUSER$TSID
                SQL="SELECT TOP 1 max(to_bigint(BACKUP_ID)) FROM SYS.M_BACKUP_CATALOG where SYS_START_TIME <= ADD_DAYS(CURRENT_TIMESTAMP, -$DELLOG) and ENTRY_TYPE_NAME in ('data snapshot','complete data backup') and STATE_NAME = 'successful' "
             fi

             echo "************************** delete tenant log ******************"
             # ID=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $TDBUSER -a -j $SQL | head -n1`
             ID=`$hdbsql -U $TDBUSER -a -j $SQL | head -n1`
             ID=`echo ${ID} | sed -e 's/^[ \t]*//'`

             if [ "$ID" = "?" ]
             then
                echo "********** !!! WARNING !!!: no snapshot ID found to delete the log for $TSID database for older then $DELLOG *********"
                #exit
                continue
             fi

             if [ "$USESYSTEMDBKEY" = "true" ]; then
                SQL="BACKUP CATALOG DELETE FOR $TSID ALL BEFORE BACKUP_ID $ID COMPLETE "
             else
                SQL="BACKUP CATALOG DELETE ALL BEFORE BACKUP_ID $ID COMPLETE "
             fi

             # /usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $TDBUSER -a -j $SQL
             $hdbsql -U $TDBUSER -a -j $SQL
             retval=$?
             if [ $retval -ne 0 ]; then
                echo "WARNINGMSG: Warning: Failed to delete the $TSID log for $DBSID database: check customapp-saphana.log for details"
             fi

          fi
       fi
    done
fi


#### Remove Log backups ####

#systemdate=`date +"%Y-%m-%d %H:%M:%S"`
   systemdate="$ENDPIT"
   globalpath=`echo $DIR_INSTANCE`
   globalpath=`dirname $globalpath`
   globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
   LOGBACKUPPATH=`grep -iw ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`

if [ "$SNAPSHOT_TYPE" = "PD" ]; then
   FROM_TIME="$ENDPIT"
else
   vdate=`echo $systemdate | awk '{print $1}'`
   vtime=`echo $systemdate | awk '{print $2}'`

   FROM_TIME=`date -d "$vtime $vdate -$REMOVAL_HOURS hours" +"%Y-%m-%d %H:%M:%S"`
fi
#set +x
for lname in $(echo $LASTBACKEDUPDBNAMES | tr ',' ' ' )
do
  for cname in $(echo $dbnames | tr ',' ' ' )
  do
    NOTFOUND=
    cname=`echo $cname | sed s'/"//g'`
    if [ "$cname" = "DATABASE_NAME" ]; then
       continue;
    elif [ "$lname" = "$cname" ]; then
         break;
    else
         NOTFOUND=YES
    fi
  done
  if [ "$NOTFOUND" = "YES" ]; then
     if [ -z "$DELETED_DBLIST" ]; then
        DELETED_DBLIST=$lname
     else
        DELETED_DBLIST=$DELETED_DBLIST','$lname
     fi
  fi
done
set -x
echo "DELETE_DB:$DELETED_DBLIST"


if [ ! -z  "$LOGBACKUPPATH" ]; then
   for tsid in $(echo $dbnames | tr ',' ' '); do
      tsid=`echo $tsid | sed s'/"//g'`
      if [ "$tsid" = "DATABASE_NAME" ]; then
           :
      elif [ "$tsid" = "SYSTEMDB" ]; then
         tsid=SYSTEMDB
         if [ -d $LOGBACKUPPATH/$tsid ]; then
            firstfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |head -1)"
            lastfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |tail -1)"
            echo "First logbackup deleted for $tsid: $firstfile"
            echo "Last logbackup deleted $tsid: $lastfile"
            find $LOGBACKUPPATH/$tsid -name "log_backup_*" -type f ! -newermt "$FROM_TIME" | xargs --no-run-if-empty rm -f
         fi
      else
         if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "200000" ]; then
            tsid=
         else
             tsid=DB_"$tsid"
         fi
         if [ -d $LOGBACKUPPATH/$tsid ]; then
            firstfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |head -1)"
            lastfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |tail -1)"
            echo "First logbackup deleted for $tsid: $firstfile"
            echo "Last logbackup deleted $tsid: $lastfile"
            find $LOGBACKUPPATH/$tsid -name "log_backup_*" -type f ! -newermt "$FROM_TIME" | xargs --no-run-if-empty rm -f
         fi
      fi
   done
   for del_tsid in $(echo $DELETED_DBLIST | tr ',' ' '); do
      tsid=DB_"$del_tsid"
      if [ -d $LOGBACKUPPATH/$tsid ]; then
            firstfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |head -1)"
            lastfile="$(find $LOGBACKUPPATH/$tsid -name 'log_backup_*' -type f '!' -newermt "$FROM_TIME" |xargs --no-run-if-empty ls -ltr |tail -1)"
            echo "First logbackup deleted for $tsid: $firstfile"
            echo "Last logbackup deleted $tsid: $lastfile"
         find $LOGBACKUPPATH/$tsid -name "log_backup_*" -type f | xargs --no-run-if-empty rm -f
      fi
   done
fi


exit
