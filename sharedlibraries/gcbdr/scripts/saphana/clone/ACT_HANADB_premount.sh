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

#export ACT_JOBTYPE=unmount
#export ACT_PHASE=pre

dbsid=$1

dbsid=`echo $dbsid | tr '[A-Z]' '[a-z]'`
#/act/custom_apps/saphana/clone/HANADB_config.conf

if [ -z $dbsid ]; then
echo "ERRORMSG: Pre Mount: Database SID is not set!"
exit 1
fi

dbsidadm=$dbsid"adm"
export dbsidadm

if [ -f /act/touch/.hana_migrate_"$dbsid".conf ]; then
   PVMOVE_STATUS=`cat /act/touch/.hana_migrate_"$dbsid".conf | awk -F "=" '{print $2}'`
   if [ "$PVMOVE_STATUS" = "YES" ]; then
      exit 0
   else
      echo "ERRORMSG: PVMOVE is in progress. Unmount delete cannot be done!"
      exit 1
   fi
fi
echo "********** call HANA DB stop ************"
su - $dbsidadm -c "$WPWD/ACT_HANADB_saphana_stop.sh $dbsid"
retval=$?

if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Pre Mount: Failed to stop HANA DB services. Please check!"
    exit $retval
fi

exit 0

