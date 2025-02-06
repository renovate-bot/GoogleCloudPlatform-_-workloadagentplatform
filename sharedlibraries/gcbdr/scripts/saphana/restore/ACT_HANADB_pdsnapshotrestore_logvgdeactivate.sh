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
LOGBACKUP_DEVICE_MAPPINGS=$LOGBACKUP_DEVICE_MAPPINGS
LOGBACKUPMNT=$LOGBACKUPMNT
LOGBACKUP_VG=$LOGBACKUP_VG
LOGBACKUP_LV=$LOGBACKUP_LV

source /act/custom_apps/saphana/act_saphana_comm_func.sh

UPPERDBSID="$(echo $DBSID|tr '[a-z]' '[A-Z]')"

osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
osuser="$osuser"adm
tdate=`date +"%m%d%Y%H%M"`


set +x
[[ ! -z "$LOGBACKUPVOLMEDETAILS" ]]; echo "LOGBACKUPMNT: $LOGBACKUPMNT; LOGBACKUP_VG:$LOGBACKUP_VG; LOGBACKUP_LV:$LOG_LV"
set -x

#FORMAT: logbackupvol-/logbackup:pd-logbackup, pd-logbackup1,pd-logbackup2;logbackupvol-/logbackup_<1234>1;
if [[ ! -z "$LOGBACKUP_DEVICE_MAPPINGS" ]]; then
     logmntcount=1
      for devicedetails in $(echo $LOGBACKUP_DEVICE_MAPPINGS |tr ';' ' ')
      do
        CHECK_VG=
        LOGBACKUPMNT="$(echo $devicedetails | awk -F":" '{print $1}'| awk -F "-" '{print $2}')"
        ISMOUNTED="$(grep -w $LOGBACKUPMNT /proc/mounts |uniq)"
        if [[ ! -z "$LOGBACKUPMNT" ]] && [[ ! -z "$ISMOUNTED" ]]; then
           LOGBACKUPMNT_LGVOL="$(get_lgname $LOGBACKUPMNT)"
           LOGBACKUPVG="$(get_vgname $LOGBACKUPMNT_LGVOL)"
        fi
        if [[ "$logmntcount" -gt 1 ]]; then
           if [[ ! -z "$LOGBACKUPVG" ]]; then
              CHECKVG="$(check_vg_exists $LOGBACKUPVG)"
              if [[ ! -z "$CHECKVG" ]]; then
                 unmount_mountpt $LOGBACKUPMNT
                 disable_vg $LOGBACKUPVG
              fi
           fi
        fi
        logmntcount=$(($logmntcount+1))
      done
fi

exit 0
