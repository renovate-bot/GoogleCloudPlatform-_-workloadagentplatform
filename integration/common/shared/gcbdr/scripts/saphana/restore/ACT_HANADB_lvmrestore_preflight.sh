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
SOURCE_BACKINT=$SOURCE_BACKINT
SOURCE_DATAVOLUME=$SRC_DATAVOL
SOURCE_LOGVOLUME=$SRC_LOGVOL

source /act/custom_apps/saphana/act_saphana_comm_func.sh

################## MAIN ##########################

if [ ! -z $RESTORE_USERSTOREKEY ]; then
   TEMP_USERSTOREKEY=$USERSTOREKEY
   USERSTOREKEY=$RESTORE_USERSTOREKEY
fi

osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
osuser="$osuser"adm
tdate=`date +"%m%d%Y%H%M"`
backupconfigfilespath=/act/tmpdata
globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`

################### Check if DBSID exists #####################
preflight_status=
check_dbsid_preflight

################### Check if global.ini file exists #####################
check_global_preflight
localhostname=`cat $nameserverini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`

############# Validate Node configuration Primary/Secondary ###########
preflight_node_role_validation

############# Check if backint is configured ###########
preflight_backint_validation $globalpath

############# Validate logbackup path #####################
preflight_validate_logbackup_path

SOURCE_DATAVOLUME=`echo $SOURCE_DATAVOLUME|awk -F":" '{print $2}'`
SOURCE_LOGVOLUME=`echo $SOURCE_LOGVOLUME|awk -F":" '{print $2}'`
preflight_check_data_log_details $SOURCE_DATAVOLUME $SOURCE_LOGVOLUME
####### Validate source and target version #####
preflight_check_version "$SOURCE_HVERSION" "$osuser"

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
preflight_check_userstorekey "$dbusername" "$password" "$USERSTOREKEY" "$PORTNO"
set -x

################### Check Database status ###############
preflight_check_database_status

set +x
echo "$preflight_status;"
set -x
echo " ===== Completed Pre-Restore checks successfully ======"
exit 0
