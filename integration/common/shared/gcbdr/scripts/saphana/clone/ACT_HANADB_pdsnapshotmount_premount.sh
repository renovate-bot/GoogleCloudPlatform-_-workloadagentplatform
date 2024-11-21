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

DBSID=$DBSID
NEWTARGET=$NEWTARGET
DATAMNT=$DATAMNT
LOGMNT=$LOGMNT
USRSAPMNT=$USRSAPMNT
HANASHAREDMNT=$HANASHAREDMNT
LOGBACKUPMNT=$LOGBACKUPMNT
DATA_VG=$DATA_VG
HANASHARED_VG=$HANASHARED_VG
LOG_VG=$LOG_VG
USRSAP_VG=$USRSAP_VG
LOGBACKUP_VG=$LOGBACKUP_VG
JOBID=$JOBID

source /act/custom_apps/saphana/act_saphana_comm_func.sh

UPPERDBSID="$(echo $DBSID|tr '[a-z]' '[A-Z]')"

################################## MAIN ###############################
osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
osuser="$osuser"adm
tdate=`date +"%m%d%Y%H%M"`

echo "DATAMNT: $DATAMNT; DATA_VG:$DATA_VG"
echo "LOGMNT: $LOGMNT; LOG_VG:$LOG_VG"
echo "LOGBACKUPMNT: $LOGBACKUPMNT; LOGBACKUP_VG:$LOGBACKUP_VG"
[[ ! -z "$HANASHAREDMNT" ]]; echo "HANASHAREDMNT: $HANASHAREDMNT; HANASHARED_VG:$HANASHARED_VG"
[[ ! -z "$USRSAPMNT" ]]; echo "USRSAPMNT: $USRSAPMNT; USRSAP_VG:$USRSAP_VG"

set -x
if [[ ! -d /act/tmpdata/$JOBID ]]; then
    mkdir -p /act/tmpdata/$JOBID
fi
CONFIGFILE_LOC="/act/tmpdata/$JOBID/vg_status_$JOBID.txt"
if [[ -f "$CONFIGFILE_LOC" ]]; then
    rm -f $CONFIGFILE_LOC
fi
CHECKVG=
CHECKVG="$(check_vg_exists $DATA_VG)"
if [[ ! -z "$CHECKVG" ]];then
   echo "$DATA_VG:YES" >> $CONFIGFILE_LOC
fi
if [[ "$DATA_VG" != "$LOG_VG" ]]; then
   CHECKVG=
   CHECKVG="$(check_vg_exists $LOG_VG)"
   if [[ ! -z "$CHECKVG" ]];then
      echo "$LOG_VG:YES" >> $CONFIGFILE_LOC
   fi
fi
CHECKVG=
CHECKVG="$(check_vg_exists $LOGBACKUP_VG)"
if [[ ! -z "$CHECKVG" ]];then
   echo "$LOGBACKUP_VG:YES" >> $CONFIGFILE_LOC
fi

exit 0
