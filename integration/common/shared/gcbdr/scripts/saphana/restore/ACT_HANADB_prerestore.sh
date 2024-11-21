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

WPWD=/act/custom_apps/saphana/restore

#export ACT_JOBTYPE=unmount
#export ACT_PHASE=pre

dbsid=$1

if [ -z $dbsid ]; then
echo "ERRORMSG: Database SID is not set "
exit 1
fi

dbsidadm=$dbsid"adm"
export dbsidadm

if [ ! -z $RESTORE_USERSTOREKEY ]; then
   USERSTOREKEY=$RESTORE_USERSTOREKEY
else
   USERSTOREKEY=$SOURCE_USERSTOREKEY
fi

usercount=`su - $dbsidadm -c 'ls | wc -l'`
retval=$?
if [ $retval -ne 0 ]; then
  echo "ERRORMSG: $dbsid does not exists, please check!"
  exit 1
fi

keystore=`su - $dbsidadm -c 'cd exe ; hdbuserstore list '`
retval=$?
if [ $retval -ne 0 ]; then
  echo "ERRORMSG: can not connect to check the key store!"
  exit 1
fi

keycount=`echo $keystore | grep -iw $USERSTOREKEY | wc -l`
if [ $keycount -eq 0 ]; then
  echo "ERRORMSG: USERSTOREKEY does not exists!"
  exit 1
fi

echo "********** call HANA DB stop ************"
su - $dbsidadm -c "$WPWD/ACT_HANADB_RESTORE_saphana_stop.sh $dbsid"
retval=$?

if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Pre restore: Failed to stop $dbsid: Please check logs for details!"
    exit $retval
fi

exit 0
