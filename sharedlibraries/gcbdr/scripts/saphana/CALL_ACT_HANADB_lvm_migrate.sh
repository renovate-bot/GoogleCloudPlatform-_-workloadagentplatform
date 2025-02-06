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

WPWD=/act/custom_apps/saphana/lvm_migrate
JOB_PHASE=$1
DBSID=$2
PROD_DATAVOL=$3
PROD_LOGVOL=$4

echo "********* Job Phase is: $JOB_PHASE *************"

if [ ! -z "$DBSID" ] && [ ! -z "$PROD_DATAVOL" ] && [ ! -z "$PROD_LOGVOL" ]; then
   $WPWD/ACT_HANADB_lvm_migrate.sh $DBSID $PROD_DATAVOL $PROD_LOGVOL
   retval=$?
else
  echo "ERRORMSG: Required input parameters are missing. Please check the usage!"
  echo "$WPWD/ACT_HANADB_lvm_migrate.sh <dbsid> <PROD DATA VOLUME> <PROD LOG COLUME>"
   exit 1
fi

if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Migration Failed: check error messages for details."
    exit $retval
fi

exit 0
