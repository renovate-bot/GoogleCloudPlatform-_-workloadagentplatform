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

set +x
DBSID=$1
USERSTOREKEY=$2
# DBPORT=$3
# PORT=$4
HANAVERSION=$3
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
isempty USERSTOREKEY $USERSTOREKEY
# isempty DBPORT $DBPORT
# isempty PORT $PORT
isempty HANAVERSION $HANAVERSION


DATE=`date +"%m%d%Y"`

DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
DBADM=$DBADM'adm'

echo "************************** DATE:$DATE: Pre check if catalog backup path and log backup path is same  ******************"

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

#dbnames=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql_wrapper -U $USERSTOREKEY -a -j -x "select string_agg(database_name,',')  from m_databases"`
dbnames=`$hdbsql_wrapper -U $USERSTOREKEY -a -j -x "select string_agg(database_name,',')  from m_databases"`
dbnames=`echo $dbnames | sed 's/"//g'`
echo -e "backedupdbnames:$dbnames" > $FILE_NAME

globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini

get_backup_global_params ()
{
   LOGBACKUPPATH=`grep -i ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
   CATLOGBACKUPPATH=`grep -i ^basepath_catalogbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
   if [ -z "$LOGBACKUPPATH" ]; then
      echo "ERRORMSG:$dbnames-Backup Pre Check: LOGBACKUPPATH is not set in global.ini"
      exit 1
   elif [ ! -z "$LOGBACKUPPATH" ]; then
        if [ -z "$CATLOGBACKUPPATH" ]; then
           CATLOGBACKUPPATH=$LOGBACKUPPATH
           cp $globalinipath $globalinipath'.'$DATE
           echo -e "basepath_catalogbackup = $CATLOGBACKUPPATH" >> $globalinipath
    elif [ ! -z "$CATLOGBACKUPPATH" ]; then
         if [ "$LOGBACKUPPATH" != "$CATLOGBACKUPPATH" ]; then
            cp $globalinipath $globalinipath'.'$DATE
            CATLOGBACKUPPATH=$LOGBACKUPPATH
            sed -i "/basepath_catalogbackup/d" $globalinipath
            sed -i "/persistence/a basepath_catalogbackup = $CATLOGBACKUPPATH" $globalinipath
         fi
        fi
    fi
}

get_backup_global_params_wrapper

if [ $? -ne "0" ]; then
   echo "get_backup_global_params_wrapper"
   exit 1
fi

### backint check
get_lvm_backint_check ()
{
   SQL="select database_name from m_databases"
   dbnames=`$hdbsql_wrapper -U $USERSTOREKEY -a -j -x "$SQL"`
   dret=$?
   if [ "$dret" -gt 0 ]; then
      echo "ERRORMSG: Unable to connect to the database SYSTEMDB using $USERSTOREKEY!"
   else
      for j in ${dbnames}; do
         bint=""
         TSID=`echo $j |awk -F '"' '{print $2}' | xargs`
         if [ $TSID = "SYSTEMDB" ]; then
            bintsql="select value from SYS_DATABASES.M_INIFILE_CONTENTS where SECTION = 'backup' and layer_name = 'SYSTEM' and KEY = 'catalog_backup_using_backint'"
         else
            bintsql="select distinct value from SYS_DATABASES.M_INIFILE_CONTENTS where SECTION = 'backup' and layer_name = 'DATABASE' and DATABASE_NAME= '$TSID' and KEY = 'catalog_backup_using_backint'"
         fi
         HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
         if [ "$HANAVERSION_TMP" -gt "200000" ]; then
            binten=`$hdbsql_wrapper -U $USERSTOREKEY -a -j -x "$bintsql"`
            binten=`echo $binten | sed 's/"//g'`
            if [ ! -z "$binten" ] && [ "$binten" = "true" ]; then
               echo "ERRORMSG: Backup Pre Check: The target server should not have backint configured. Please remove all the backint related parameters of $TSID database "
               exit 1
            fi
         fi
      done
   fi
}

get_lvm_backint_check_wrapper
if [ $? -ne "0" ]; then
   echo "get_lvm_backint_check"
   exit 1
fi

HCMT='ACT_'$DBSID'_SNAP'
DATE=`date`
echo "************************** DATE:$DATE: Freezing $DBSID database ******************"

backup_freeze ()
{
  set -x
   HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
   if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "200000" ]
   then
      SQL="BACKUP DATA CREATE SNAPSHOT COMMENT '$HCMT'"
   else
      SQL="BACKUP DATA FOR FULL SYSTEM CREATE SNAPSHOT COMMENT '$HCMT'"
   fi
   set -o pipefail
   #/usr/sap/$DBSID/$DBPORT/exe/$hdbsql_wrapper -U $USERSTOREKEY -j $SQL 2>&1 | tee $FAIL_MSG/"$DBSID"_pre_error_msg
   $hdbsql_wrapper -U $USERSTOREKEY -j "$SQL" &> $FAIL_MSG/"$DBSID"_pre_error_msg
   retval=$?
   echo "<tenants>" >> $BACKUP_XML
   if [ $retval -ne 0 ]; then
      errorstring=`cat $FAIL_MSG/"$DBSID"_pre_error_msg | xargs |awk -F"rc=" '{print $2}'`
      if [ -z "$errorstring" ]; then
         errorstring=`tail -c100 $FAIL_MSG/"$DBSID"_pre_error_msg`
      fi
      for i in $(echo $dbnames | tr "," " ")
      do
         echo "ERRORMSG:$i-Failed to Freeze,Error:$errorstring, check customapp-saphana.log for details "
         echo -e "\t<tenant name =\"$i\" status=\"failed\" error=\"$errorstring\"/>" >> $BACKUP_XML
      done
      echo "</tenants>" >> $BACKUP_XML
      exit $retval
   fi
   if [ -d "$FAIL_MSG" ]; then
      rm -f $FAIL_MSG/*
   fi
}

backup_freeze

if [ $? -ne "0" ]; then
   echo "backup_freeze"
   exit 1
fi
#exit 0
