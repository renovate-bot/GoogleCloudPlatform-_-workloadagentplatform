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

if [ "$#" -lt 1 ]; then
   echo"ERRORMSG: Input parameters are required. Please check the usage!"
   echo "./CALL_ACT_HANADB_LVM_single_tenant_recover.sh <DBSID> <TENANT SID> <SYSTEMDB USERSTORE KEY> '<RECOVERY TIME-YYYY-MM-DD HH24:MI:SS>'"
   exit 1
fi

DBSID=$2
TSID=$3
DBUSER=$4
RECOVERYTIME="$5"

DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
dbsid=`echo $DBSID | tr '[A-Z]' '[a-z]'`
OSUSER="$dbsid"adm

TSID=`echo $TSID | tr '[a-z]' '[A-Z]'`

MOUNT_PARAMS_FILE=/act/touch/"$dbsid"_mount_params
FILE_PATH=/act/touch/"$dbsid"_HANA.manifest

globalpath=`su - $OSUSER -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`

SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi


cleanup_file() {
  fname=$1
  if [ -f "$fname" ]; then
     rm -f $fname
  fi
}

if [ -f "$MOUNT_PARAMS_FILE" ]; then
   source $MOUNT_PARAMS_FILE
else
   echo "ERRORMSG: Unable to find the configuration file $MOUNT_PARAMS_FILE. Please check!"
   exit 1
fi

if [ ! -f $FILE_PATH ]; then
   echo "ERRORMSG: Unable to find the configuration file $FILE_PATH. Please check!"
   exit 1
fi

keystore=`su - $OSUSER -c 'cd exe ; hdbuserstore list '`
retval=$?
if [ $retval -ne 0 ]; then
  echo "ERRORMSG: can not connect to check the key store!"
  exit 4
fi
keycount=`echo $keystore | grep -w $DBUSER | wc -l`
if [ $keycount -eq 0 ]; then
  echo "ERRORMSG: keystore does not exists!"
  exit 5
fi


LOGPATH=$ARCHIVELOGMOUNTPATH

##### Get the source tenant db datafile locations #####
SOURCE_DATAPATH=`echo $DATAVOLPATH |sed "s|$MOUNTPOINTROOT||g"`

DB_PATH=`grep -w $TSID $FILE_PATH`
DB_PATH=`echo $DB_PATH | awk -F"=" '{print $2}'`

OLDIFS=IFS

IFS=':'

##### Check for Snapshot File ######
FOUND=0
for path in $DB_PATH
do
  CHECK_SNAPSHOT=`ls -l $DATAVOLPATH/$path/ | grep "snapshot_databackup" | wc -l `
  if [ "$CHECK_SNAPSHOT" -gt 0 ]; then
     echo "Found Snapshot file to recover!"
     FOUND=1
     break;
  else
     :
  fi
done

if [ "$FOUND" = "0" ]; then
   echo "ERRORMSG: Unable to find Snapshot file to recover $TSID. Please check!"
   exit 1
fi

#### If TSID= SYSTEMDB, Stop the application before copying files #####

if [ "$TSID" = "SYSTEMDB" ]; then
   su - $OSUSER -c "HDB stop"
   retval=$?
   if [ "$retval" -gt 0 ]; then
      echo " ERRORMSG: Failed to stop SYSTEMDB. Please check the logs"
      exit 1
   fi
else
   SQL="alter system stop database $TSID"
   su - $OSUSER -c "$hdbsql -U $DBUSER -a -j $SQL"
fi

#### Copy the files ####

for path in $DB_PATH
do
   /bin/cp $DATAVOLPATH/$path/* $SOURCE_DATAPATH/$path/
done

chown -R $OSUSER:sapsys $SOURCE_DATAPATH

#### Call Recover script ####
su - $OSUSER -c "/act/custom_apps/saphana/restore/ACT_lvm_single_tenant_recover.sh $TSID $DBUSER $SOURCE_DATAPATH $OSUSER $LOGPATH \"$RECOVERYTIME\""
retval=$?

if [ "$retval" = "0" ]; then
   cleanup_file $FILE_PATH
   cleanup_file $MOUNT_PARAMS_FILE
fi

exit $retval
