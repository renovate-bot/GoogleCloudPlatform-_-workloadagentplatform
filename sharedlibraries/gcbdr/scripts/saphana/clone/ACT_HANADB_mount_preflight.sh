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
JOBID=$JOBID
SOURCE_HVERSION=$HANAVERSION
INTEGRITYCHECK=$INTEGRITYCHECK
DATAMNT=$DATAMNT
LOGMNT=$LOGMNT
LOGBACKUPMNT=$LOGBACKUPMNT
DATA_VGNAME=$DATA_VGNAME
LOG_VGNAME=$LOG_VGNAME
LOGBACKUP_VGNAME=$LOGBACKUP_VGNAME
NEWTARGET=$NEWTARGET

#DBSID=pdc
#JOBID=$JOBID
#SOURCE_HVERSION=$HANAVERSION
#INTEGRITY_CHECK=TRUE
#DATAMNT=/hana/data1
#LOGMNT=/hana/log1
#LOGBACKUPMNT=/hana/logbackup
#DATA_VGNAME=data2
#LOG_VGNAME=log1
#LOGBACKUP_VGNAME=logbackup

source /act/custom_apps/saphana/act_saphana_comm_func.sh

################## MAIN ##########################
osuser=
NEWTARGET="$(echo $NEWTARGET |tr '[a-z]' '[A-Z]')"
if [[ ! -z "$DBSID" ]]; then
   osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
   osuser="$osuser"adm
   su - $osuser -c 'echo $DIR_INSTANCE' 2> /dev/null
   retval=$?
   if [[ "$retval" -gt 0 ]]; then
      echo "Info: source database sid $DBSID does not exist, checking for local instance user"
      osuser=
   fi
fi
if [[ -z "$osuser" ]] && [[ "$NEWTARGET" = "TRUE" ]]; then
   hanauserlist="$(cat /etc/passwd |grep adm |grep -v sapadm |awk -F":" '{print $1}' | xargs)"
   for hanauser in ${hanauserlist}
   do
     su - $hanauser -c 'echo $DIR_INSTANCE' 2> /dev/null
     retval=$?
     if [[ "$retval" -gt 0 ]]; then
         continue;
     else
        osuser=$hanauser
        DBSID="$(echo $osuser |cut -c1-3|tr '[a-z]' '[A-Z]')"
        break;
     fi
   done
fi
if [[ -z "$osuser" ]] && [[ "$INTEGRITYCHECK" == "TRUE" ]]; then
   echo"  PRECHECK:Verify database SID, Failed, Database SID $DBSID or any other instance is not configured on the target server "$(hostname)". Please configure HANA instance the target using hdblcm tool; PRECHECK:Verify HANA Version, Failed, Skipped;PRECHECK:Verify Volume Group, Failed, Skipped;PRECHECK:Verify Mount Point, Failed, Skipped;"
   exit 0
fi

tdate=`date +"%m%d%Y%H%M"`
backupconfigfilespath=/act/tmpdata
globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`

################### Check if DBSID exists #####################
preflight_status=
if [[ "$INTEGRITYCHECK" == "TRUE" ]]; then
   check_dbsid_preflight
fi

################### Check database status for the mount process  #####################
if [[ "$NEWTARGET" = "FALSE" ]]; then
   preflight_check_database_status_mount
fi

####### Validate source and target version #####
if [[ "$INTEGRITYCHECK" == "TRUE" ]]; then
   preflight_check_target_version "$SOURCE_HVERSION" "$osuser"
fi

####### Check mount point exists or not #####
preflight_check_mountpoint_exists "$DATAMNT" "$LOGMNT" "$LOGBACKUPMNT"

####### Check if  VGNAME exists  #####

if [[ "$NEWTARGET" == "TRUE" ]]; then
   preflight_check_vg_status "$DATA_VGNAME" "$LOG_VGNAME" "$DBSID"
fi


set +x
echo "$preflight_status;"
set -x
echo " ===== Completed Pre-fligt checks successfully ======"
exit 0
