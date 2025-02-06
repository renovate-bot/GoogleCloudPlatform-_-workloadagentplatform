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
# DBPORT=$3
# PORT=$4
HANAVERSION=$3
JOBNAME=$4
SNAPSHOT_STATUS=$5
SNAPSHOT_TYPE=$6
# TODO: b/350656405 - Investigate if we need PORT or DBPORT as a parameter for the script.

rpath=$(realpath "${BASH_SOURCE:-$0}")
currdir=$(dirname $rpath)
source $currdir/act_saphana_wrapper_library.sh

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

isempty DBSID $DBSID
isempty DBUSER $DBUSER
# isempty DBPORT $DBPORT
# isempty PORT $PORT
isempty HANAVERSION $HANAVERSION
isempty JOBNAME $JOBNAME

DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
DBADM=$DBADM'adm'

CONFIG_FILEPATH=/tmp/$JOBNAME
UPPERDBSID=`echo $DBSID |tr '[a-z]' '[A-Z]'`
DATE=`date`

if [ ! -d "$CONFIG_FILEPATH" ]; then
   mkdir -p $CONFIG_FILEPATH
fi
if [ -z "$SNAPSHOT_STATUS" ] || [ "$SNAPSHOT_STATUS" = "TRUE" ]; then
   SNAPSHOT_STATUS=SUCCESSFUL
else
   SNAPSHOT_STATUS=UNSUCCESSFUL
fi
set -x
if [ "$SNAPSHOT_TYPE" = "PD" ]; then
    BACKUP_TYPE="PD Snapshot"
else
   BACKUP_TYPE="LVM Snapshot"
fi
get_bkp_file_path ()
{
   FILE_NAME=/act/touch/hanabackupdblist.log
   BACKUP_XML=/act/touch/backupstatus.xml
   FAIL_MSG=/act/touch/FAIL_MSG
}

get_bkp_file_path_wrapper

if [ $? -ne "0" ]; then
   echo "get_bkp_file_path"
   exit 1
fi

echo "************************** DATE:$DATE: Close Snapshot $DBSID database ******************"

get_globalpath ()
{
   globalpath=`echo $DIR_INSTANCE`
   globalpath=`dirname $globalpath`
}

get_globalpath_wrapper

if [ $? -ne "0" ]; then
   echo "get_globalpath"
   exit 1
fi

getSslenforce ()
{
  SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
  SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
  SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`
}

getSslenforce_wrapper

if [ $? -ne "0" ]; then
   echo "get_Sslenforce"
   exit 1
fi

# TODO: b/350656405 - Investigate if we need to use hdbsql_cmd_wrapper or hdbsql.
if [ "$SSLENFORCE" = "true" ]; then
   # hdbsql_wrapper="hdbsql_cmd_wrapper -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
   hdbsql_wrapper="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   # hdbsql_wrapper="hdbsql_cmd_wrapper"
   hdbsql_wrapper="hdbsql"
fi

dbnames=`$hdbsql_wrapper -U $DBUSER -a -j -x "select string_agg(database_name,',')  from m_databases"`
dbnames=`echo $dbnames | sed 's/"//g'`
echo -e "backedupdbnames:$dbnames" > $FILE_NAME

get_backup_id ()
{
   HCMT='ACT_'$DBSID'_SNAP'

   SQL="SELECT BACKUP_ID from M_BACKUP_CATALOG WHERE COMMENT = '$HCMT' and ENTRY_TYPE_NAME = 'data snapshot' and STATE_NAME = 'prepared' and SYS_END_TIME is null "

   ID=`$hdbsql_wrapper -U $DBUSER -a -j "$SQL"`
   ID=`echo $ID | head -n1 | cut -d" " -f1`
}

get_backup_id

if [ $? -ne "0" ]; then
   echo "get_backup_id"
   exit 1
fi

backup_unfreeze ()
{
  set -x
   HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
   if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "200000" ]
   then
      SQL="BACKUP DATA CLOSE SNAPSHOT BACKUP_ID $ID SUCCESSFUL 'ActBackup'"
   else
      SQL="BACKUP DATA FOR FULL SYSTEM CLOSE SNAPSHOT BACKUP_ID $ID $SNAPSHOT_STATUS 'ActBackup'"
   fi

   set -o pipefail
   $hdbsql_wrapper -U $DBUSER -a -j "$SQL" &> $FAIL_MSG/"$DBSID"_post_error_msg
   retval=$?
   if [ $retval -ne 0 ]; then
      errorstring=`cat $FAIL_MSG/"$DBSID"_post_error_msg | xargs |awk -F"rc=" '{print $2}'`
      if [ -z "$errorstring" ]; then
         errorstring=`tail -c100 $FAIL_MSG/"$DBSID"_post_error_msg`
      fi
      for i in $(echo $dbnames | tr "," " ")
      do
         echo "ERRORMSG:$i-Failed to Close Snapshot Error:$errorstring, check customapp-saphana.log for details (abort will try to close the snapshot)"
         echo -e "\t<tenant name =\"$i\" status=\"failed\" error=\"$errorstring\"/>" >> $BACKUP_XML
      done
      echo "</tenants>" >> $BACKUP_XML
      exit $retval
   fi
######## Write to XML ########
   for i in $(echo $dbnames | tr "," " ")
   do
      echo -e "\t<tenant name =\"$i\" status=\"success\"/>" >> $BACKUP_XML
   done
   echo "</tenants>" >> $BACKUP_XML

   BACKUPID_SQL="select ',BACKUPID: '||BACKUP_ID||', END TIME: '||SYS_END_TIME||', STATUS: '||STATE_NAME from m_backup_catalog where comment='$HCMT' and backup_id=(select max(backup_id) from m_backup_catalog where entry_type_name in ('data snapshot') and comment='$HCMT')"
   BACKUPID_STRING=`$hdbsql_wrapper -U $DBUSER -a -x -j $BACKUPID_SQL`


   if [ ! -z "$BACKUPID_SQL" ]; then
      BACKUPID_STRING=`echo $BACKUPID_STRING | sed 's/"//g'`
      echo "**************** BACKUP DETAILS => DBSID:$DBSID, BACKUPTYPE:$BACKUP_TYPE, $BACKUPID_STRING *******************"
   fi

   dbnames=`$hdbsql_wrapper -U $DBUSER -a -x "select database_name from m_databases"`
}

backup_unfreeze

if [ $? -ne "0" ]; then
   echo "get_backup_unfreeze"
   exit 1
fi

get_hana_vol_details ()
{
   HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
   if [ "$HANAVERSION" != "1.0" ] || [ "$HANAVERSION_TMP" -ge "200000" ]; then
      for tsid in ${dbnames}; do
         tsid=`echo $tsid | sed s'/"//g'`
         SQL="select subpath from SYS_DATABASES.M_VOLUMES where database_name = '$tsid'"
         FILEPATH=`$hdbsql_wrapper -U $DBUSER -a -x -j $SQL`
         FILEPATH=`echo $FILEPATH | xargs |sed 's/"//g'`
         FILEPATH=`echo $FILEPATH|sed 's/ /:/g'`
         echo "$tsid=$FILEPATH" >> $CONFIG_FILEPATH/HANA.manifest
      done
   fi
}

get_hana_vol_details_wrapper

if [ $? -ne "0" ]; then
   echo "get_hana_vol_details_wrapper"
   exit 1
fi

copy_ssfs_backup ()
{
   localhostname=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`
   if [ ! -z "$globalpath" ]; then
      cp $globalpath/SYS/global/hdb/custom/config/global.ini $CONFIG_FILEPATH/global.ini__"$localhostname"
      cp $globalpath/SYS/global/hdb/custom/config/nameserver.ini $CONFIG_FILEPATH/nameserver.ini__"$localhostname"
      if [ "$?" -gt 0 ]; then
         echo "WARNINGMSG: Failed to backup Configuration files"
      fi
   fi

   SSF_LOCATION=`hdbuserstore_wrapper list | grep "DATA FILE" | awk -F ":" '{print $2}'`
   SSF_LOCATION=`dirname $SSF_LOCATION`
   if [ ! -z "$SSF_LOCATION" ]; then
      cp $SSF_LOCATION/SSFS_HDB.KEY $CONFIG_FILEPATH/SSFS_HDB.KEY__"$localhostname"
      cp $SSF_LOCATION/SSFS_HDB.DAT $CONFIG_FILEPATH/SSFS_HDB.DAT__"$localhostname"
      cp $SSF_LOCATION/SQLDBC.shm $CONFIG_FILEPATH/SQLDBC.shm__"$localhostname"
      if [ "$?" -gt 0 ]; then
         echo "WARNINGMSG: Failed to backup SSFS HDB Configuration files"
      fi
   fi

   SSFS_SECURITY_LOCATION=`echo $DIR_INSTANCE`
   SSFS_SECURITY_LOCATION=`dirname $SSFS_SECURITY_LOCATION`

   if [ ! -z "$SSFS_SECURITY_LOCATION" ]; then
      cp $SSFS_SECURITY_LOCATION/SYS/global/hdb/security/ssfs/SSFS_$UPPERDBSID.KEY $CONFIG_FILEPATH/SSFS_$UPPERDBSID.KEY__"$localhostname"
      cp $SSFS_SECURITY_LOCATION/SYS/global/hdb/security/ssfs/SSFS_$UPPERDBSID.DAT $CONFIG_FILEPATH/SSFS_$UPPERDBSID.DAT__"$localhostname"
      if [ "$?" -gt 0 ]; then
         echo "WARNINGMSG: Failed to backup SSFS Security Configuration files"
      fi

   fi
}

copy_ssfs_backup_wrapper

if [ $? -ne "0" ]; then
   echo "copy_ssfs_backup_wrapper"
   exit 1
fi

get_database_configuration()
{
  SQL="select 'ALTER SYSTEM ALTER CONFIGURATION  ('''|| file_name ||''', '''|| case layer_name when 'SYSTEM' then layer_name  when 'DATABASE' then layer_name ||''', '''|| database_name    when 'HOST' then layer_name ||''', '''|| host  end || ''') SET ('''|| section ||''', '''|| key ||''') = '''||value ||''' WITH RECONFIGURE;' as \"Configuration File Backup\"  from sys_databases.m_inifile_contents where layer_name != 'DEFAULT'"
  $hdbsql_wrapper -U $DBUSER -a -x -j -C -o $CONFIG_FILEPATH/"configuration"_$UPPERDBSID".sql" $SQL
  if [ "$?" -gt 0 ]; then
     echo "WARNINGMSG: Unable to generate database configuration sql file."
  fi
}

get_database_configuration_wrapper

if [ $? -ne "0" ]; then
   echo "get_database_configuration_wrapper"
   exit 1
fi

if [ -d "$FAIL_MSG" ]; then
   rm -f $FAIL_MSG/*
fi
