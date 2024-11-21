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
set
set -x

WPWD=/act/custom_apps/saphana/restore

DBSID=$DBSID
JOBID=$JOBID
SOURCE_HVERSION=$HANAVERSION
USERSTOREKEY=$SOURCE_USERSTOREKEY
RESTORE_USERSTOREKEY=$RESTORE_USERSTOREKEY

source /act/custom_apps/saphana/act_saphana_comm_func.sh
################## MAIN ##########################

if [ ! -z $RESTORE_USERSTOREKEY ]; then
   TEMP_USERSTOREKEY=$USERSTOREKEY
   USERSTOREKEY=$RESTORE_USERSTOREKEY
fi

osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
osuser="$osuser"adm
tdate=`date +"%m%d%Y%H%M"`
backupconfigfilespath="/act/tmpdata/"$JOBID
################### Check if DBSID exists #####################
dbsidexists=`su - $osuser -c 'ls | wc -l'`
retval=$?
if [ $retval -ne 0 ]; then
  echo "ERRORMSG: HANA instance $DBSID does not exists, please check!"
  exit 1
fi

################### Check if config files created by connector #####################

if [ ! -d /act/tmpdata/$JOBID ]; then
   echo "ERRORMSG: Required configuration directory does not exist under /act/tmpdata!"
   exit 1
else
   if [ ! -f /act/tmpdata/$JOBID/global.ini__* ]; then
      echo "ERRORMSG: Required configuration files does not exist under /act/tmpdata!"
      exit 1
   fi
fi

################### Check if global.ini file exists #####################
HDBKEY_LOCATION=`su - $osuser -c "hdbuserstore list | grep \"DATA FILE\""`
HDBKEY_LOCATION=`echo $HDBKEY_LOCATION |awk -F":" '{print $2}' |xargs`
HDBKEY_LOCATION=`dirname $HDBKEY_LOCATION`
globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`
nameserverini=$globalpath/SYS/global/hdb/custom/config/nameserver.ini

if [ ! -f $globalpath/SYS/global/hdb/custom/config/global.ini ]; then
   echo "ERRORMSG: Unable to find the global.ini file under $globalpath/SYS/global/hdb/custom/config/. This file is mandatory to continue!"
   exit 1
fi

############# Validate Node configuration Primary/Secondary ###########
node_role_validation

############# Validate logbackup path #####################
validate_logbackup_path "$backupconfigfilespath"

########## Find Source node or New target node ###############
localhostname=`cat $nameserverini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`
sourcehostname=`ls /act/tmpdata/$JOBID/SSFS_HDB.DAT__* |awk -F"__" '{print $2}'`

if [ "$localhostname" = "$sourcehostname" ]; then
   NODE_TYPE="source"
else
   NODE_TYPE="newtarget"
fi

if [ -z "$sourcehostname" ]; then
   NODE_TYPE="newtarget"
fi

####### Validate source and target version #####
check_version "$SOURCE_HVERSION" "$osuser"

INSTANCENUM=`su - $osuser -c 'env | grep TINSTANCE= | cut -d"=" -f2'`
if [ -z "$INSTANCENUM" ]; then
   INSTANCENUM=`su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
fi

if [ "$TARGET_HVERSIONTMP" -lt "200000" ]; then
   PORTNO=3"$INSTANCENUM"15
else
   PORTNO=3"$INSTANCENUM"13
fi
#### Validate userstore key

echo "Analyzing USERSTORE KEY information passed!......."

set +x
update_userstorekey "$dbusername" "$password" "$USERSTOREKEY" "$PORTNO" "$backupconfigfilespath"
set -x

echo " ===== Completed Pre-Restore checks successfully ======"
exit 0
