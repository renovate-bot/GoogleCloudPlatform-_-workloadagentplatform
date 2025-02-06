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

WPWD=/act/custom_apps/saphana/clone

DBSID=$2
ACT_MOUNT_POINTS=$3
DBUSER=$4
HANAVERSION=$5
LOGMOUNTPATH=$6
RECOVERYTIME="$7"

PARAMETER_FILE=/act/touch/"$DBSID"_mount_params

if [ -f "/act/touch/"$ACT_JOBNAME"_mount_params" ]; then
   rm -f /act/touch/"$ACT_JOBNAME"_mount_params
fi

if [ -f "$PARAMETER_FILE" ]; then
   source $PARAMETER_FILE
else
   exit 0
fi

if [ -z "$OLDDBSID" ]; then
   OLDDBSID=$DBSID
fi
APPREMOUNT="FALSE"

if [ "$#" -lt 1 ]; then
      echo "Some required parameters are missing, Please check the usage for details!"
      echo "/act/scripts/CALL_ACT_HANADB_mountrecover.sh <DBSID> <TARGET MOUNT POINT> <DB USER> <HANA VERSION> <DATA PATH> <LOG PATH> <SOURCE LOCATION> [OLD DBSID] [LOGMOUNT PATH] [RECOVERY TIME]"
      exit 1
fi


$WPWD/ACT_HANADB_mountrecover.sh $DBSID $ACT_MOUNT_POINTS $DBUSER $HANAVERSION $DATAVOLPATH $LOGVOLPATH $OLDDBSID $LOGMOUNTPATH "$RECOVERYTIME"

retval=$?
if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Failed to recover $DBSID database: check error messages for details."
    exit $retval
fi

exit 0

