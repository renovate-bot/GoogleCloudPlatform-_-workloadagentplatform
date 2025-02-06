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

#DATAVOLUMEDETAILS="data:lv:/hana/data"
#LOGVOLUMEDETAILS="log1:lv:/hana/log"
#LOGBACKUPVOLMEDETAILS="logbackup:lv:/hana/logbackup"
#HANASHAREDVOLUMEDETAILS=
#USRSAPVOLMEDETAILS=

source /act/custom_apps/saphana/act_saphana_comm_func.sh

UPPERDBSID="$(echo $DBSID|tr '[a-z]' '[A-Z]')"


############## Function to stop HANA service, applicable back to source only ##############
stop_hana_process()
{
  if [[ -d "/usr/sap/$UPPERDBSID/home" ]]; then
     INSTANCENUM=`su - $osuser -c 'env | grep TINSTANCE= | cut -d"=" -f2'`

     if [ -z "$INSTANCENUM" ]; then
        INSTANCENUM=`su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
     fi
     su - $osuser -c "sapcontrol -nr $INSTANCENUM -function StopService"
     HDBRSUTILPORTS="$(ps -ef | grep "hdbrsutil  --start --port" | grep -v grep |awk -F"--port" '{print $2}' | awk '{print $1}' |xargs)"
     if [[ -z "$HDBRSUTILPORTS" ]]; then
        HDBRSUTILPORTS="$(ps -ef | grep "hdbrsutil -f -D -p" | grep -v grep |awk -F"-p" '{print $2}' | awk '{print $1}' |xargs)"
     fi
     for portno in $HDBRSUTILPORTS
     do
       su - $osuser -c "hdbrsutil --stop --port $portno"
     done
  else
     echo "/usr/sap is already unmounted"
  fi
  HDBRSUTILPORTS="$(ps -ef | grep "hdbrsutil  --start --port" | grep -v grep |awk -F"--port" '{print $2}' | awk '{print $1}' |xargs)"
  if [[ ! -z "$HDBRSUTILPORTS" ]]; then
      echo "ERRORMSG: Unable to stop the hdbrstuil process to unmount /hana/shared"
      exit 1
  fi

}

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
if [[ "$NEWTARGET" == "FALSE" ]]; then
   if [[ ! -z "$HANASHARED_VG" ]]; then
      if [[ "$HANASHARED_VG" == "$DATA_VG" ]] || [[ "$HANASHARED_VG" == "$LOG_VG" ]]; then
         HANASHARED_DATALOG_VG_SHARED="TRUE"
      fi
   fi

   if [[ "$HANASHARED_DATALOG_VG_SHARED" == "TRUE" ]]; then
      CHECKVG="$(check_vg_exists $DATA_VG)"
      if [[ ! -z "$CHECKVG" ]]; then
          stop_hana_process
          unmount_mountpt $DATAMNT
          unmount_mountpt $LOGMNT
          if [[ ! -z "$USRSAPMNT" ]]; then
             unmount_mountpt $USRSAPMNT
          fi
          unmount_mountpt $HANASHAREDMNT
          disable_vg $DATA_VG
      fi
   elif [[ "$DATA_VG" == "$LOG_VG" ]]; then
        CHECKVG="$(check_vg_exists $DATA_VG)"
        if [[ ! -z "$CHECKVG" ]]; then
           unmount_mountpt $DATAMNT
           unmount_mountpt $LOGMNT
           disable_vg $DATA_VG
        fi
   else
       CHECKVG="$(check_vg_exists $DATA_VG)"
       if [[ ! -z "$CHECKVG" ]]; then
          unmount_mountpt $DATAMNT
          disable_vg $DATA_VG
       fi
       CHECKVG="$(check_vg_exists $LOG_VG)"
       if [[ ! -z "$CHECKVG" ]]; then
          unmount_mountpt $LOGMNT
          disable_vg $LOG_VG
       fi
   fi

   if [[ ! -z "$RECOVERYTIME" ]]; then
      CHECKVG="$(check_vg_exists $LOGBACKUP_VG)"
      if [[ ! -z "$CHECKVG" ]]; then
         unmount_mountpt $LOGBACKUPMNT
         disable_vg $LOGBACKUP_VG
      fi
   fi
else  ### Collecting the information for the new target
   CONFIGFILE_LOC="/act/tmpdata/$JOBID/vg_status_$JOBID.txt"
   if [[ ! -d /act/tmpdata/$JOBID ]]; then
       mkdir -p /act/tmpdata/$JOBID
   fi
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
fi
exit 0
