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

DBSID=$1
ACT_MOUNT_POINTS=$2
DBUSER=$3
HANAVERSION=$4
DATAPATH=$5
LOGPATH=$6
OLDDBSID=$7
LOGMOUNTPATH=$8
RECOVERYTIME="$9"

conffile=/act/custom_apps/saphana/clone/sourcePostMount.conf

if [ -z "$OLDDBSID" ]; then
   OLDDBSID=$DBSID
fi

APPREMOUNT="FALSE"

if [ "$#" -lt 6 ]; then
   if [ -f $conffile ]; then
      source $conffile
      if [ -z "$DBSID" ] || [ -z "$ACT_MOUNT_POINTS" ] || [ -z "$DBUSER" ] || [ -z "$HANAVERSION" ] || [ -z "$DATAPATH" ] || [ -z "$LOGPATH" ]; then
         echo "Some required parameters are missing, Please check the usage for details!"
         echo "./ACT_HANADB_sourceappmount.sh <DBSID> <TARGET MOUNT POINT> <DB USER> <HANA VERSION> <DATA PATH> <LOG PATH> [OLD DBSID] [LOGMOUNT PATH] [RECOVERY TIME]"
         exit 1
      fi
   else
      echo "Some required parameters are missing, Please check the usage for details!"
      echo "./ACT_HANADB_sourceappmount.sh <DBSID> <TARGET MOUNT POINT> <DB USER> <HANA VERSION> <DATA PATH> <LOG PATH> [OLD DBSID] [LOGMOUNT PATH] [RECOVERY TIME]"
      exit 1
   fi
fi

echo "********** call HANA DB recovery ************"
$WPWD/ACT_HANADB_premount.sh $DBSID
$WPWD/ACT_premount_test.sh $DBSID $HANAVERSION $DBUSER $DATAPATH $LOGPATH
$WPWD/ACT_HANADB_postmount.sh $DBSID $OLDDBSID $ACT_MOUNT_POINTS $DBUSER $HANAVERSION $APPREMOUNT $DATAPATH $LOGMOUNTPATH "$RECOVERYTIME"

retval=$?
if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Failed to recover $DBSID database: check customapp-saphana.log for details."
    exit $retval
fi

exit 0


