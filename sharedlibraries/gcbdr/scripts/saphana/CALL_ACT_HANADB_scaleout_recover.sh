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
DBUSER=$3
RECOVERYTIME="$4"

if [ "$#" -lt 1 ]; then
      echo "Some required parameters are missing, Please check the usage for details!"
      echo "/act/scripts/CALL_ACT_HANADB_lvmscaleout_recover.sh <DBSID> <DB USER> [RECOVERY TIME]"
      exit 1
fi
if [ -z "$DBSID" ]; then
   echo "ERRORMSG: DBSID is empty!"
   exit 1
fi


$WPWD/ACT_HANADB_saphana_scaleout_recover.sh $DBSID $DBUSER "$RECOVERYTIME"

retval=$?
if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Failed to recover $DBSID database: check error messages for details."
    exit $retval
fi

exit 0

