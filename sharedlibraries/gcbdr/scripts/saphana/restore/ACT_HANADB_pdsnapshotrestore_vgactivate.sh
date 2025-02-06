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

DATA_LV=$DATA_LV
HANASHARED_LV=$HANASHARED_LV
LOG_LV=$LOG_LV
USRSAP_LV=$USRSAP_LV
LOGBACKUP_LV=$LOGBACKUP_LV
JOBID=$JOBID
DATA_PDDEVICENAMES=$DATA_PDDEVICENAMES
LOG_PDDEVICENAMES=$LOG_PDDEVICENAMES
LOGBACKUP_DEVICE_MAPPINGS=$LOGBACKUP_DEVICE_MAPPINGS

#LOGBACKUP_DEVICE_MAPPINGS="pdlogbkp1-logbackup-/hana/logbackup:pdlogbkp2-logbackup1-/hana/logbackup_1:pdlogbkp3-logbackup2-/hana/logbackup_2"
#DATAMNT=/hana/datatest
#LOGMNT=/hana/logtest

source /act/custom_apps/saphana/act_saphana_comm_func.sh
################## MAIN ##########################

UPPERDBSID="$(echo $DBSID|tr '[a-z]' '[A-Z]')"

############## Function to start HANA service, applicable back to source only ##############
start_hana_service()
{
  if [[ -d "/usr/sap/$UPPERDBSID/home" ]]; then
     INSTANCENUM=`su - $osuser -c 'env | grep TINSTANCE= | cut -d"=" -f2'`

     if [ -z "$INSTANCENUM" ]; then
        INSTANCENUM=`su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
     fi
     su - $osuser -c "sapcontrol -nr $INSTANCENUM -function StartService $UPPERDBSID"
  else
     echo "/usr/sap/$UPPERDBSID/home does not exist"
  fi
}

################################## MAIN ###############################
osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
osuser="$osuser"adm
tdate=`date +"%m%d%Y%H%M"`


set +x
echo "DATAMNT: $DATAMNT; DATA_VG:$DATA_VG; DATA_LV:$DATA_LV"
echo "LOGMNT: $LOGMNT; LOG_VG:$LOG_VG; LOG_LV:$LOG_LV"
echo "LOGBACKUPMNT: $LOGBACKUPMNT; LOGBACKUP_VG:$LOGBACKUP_VG; LOGBACKUP_LV:$LOG_LV"

[[ ! -z "$HANASHAREDMNT" ]]; echo "HANASHAREDMNT: $HANASHAREDMNT; HANASHARED_VG:$HANASHARED_VG; HANASHARED_LV:$HANASHARED_LV"
[[ ! -z "$USRSAPMNT" ]]; echo "USRSAPMNT: $USRSAPMNT; USRSAP_VG:$USRSAP_VG; USRSAP_LV:$USRSAP_LV"
set -x

CONFIGFILE_LOC="/act/tmpdata/$JOBID/vg_status_$JOBID.txt"
if [[ ! -f $CONFIGFILE_LOC ]]; then
   touch $CONFIGFILE_LOC
fi
VG_POSTFIX="$(echo $JOBID | awk -F"_" '{print $2}')"

if [[ "$NEWTARGET" == "FALSE" ]]; then
   if [[ ! -z "$HANASHARED_VG" ]]; then
      if [[ "$HANASHARED_VG" == "$DATA_VG" ]] || [[ "$HANASHARED_VG" == "$LOG_VG" ]]; then
         HANASHARED_DATALOG_VG_SHARED="TRUE"
      fi
   fi
   ########## If hanashared and usrsap is part of DATA and LOG volumes ################
   if [[ "$HANASHARED_DATALOG_VG_SHARED" == "TRUE" ]]; then
      CHECKVG="$(check_vg_exists $DATA_VG)"
      if [[ ! -z "$CHECKVG" ]]; then
         enable_vg $DATA_VG
         mount_mountpt $DATAMNT $DATA_VG $DATA_LV
         mount_mountpt $LOGMNT $LOG_VG $LOG_LV
         if [[ "$NEWTARGET" == "FALSE" ]]; then
            if [ ! -z "$USRSAPMNT" ]; then
               mount_mountpt $USRSAPMNT $USRSAP_VG $USRSAP_LV
            fi
             mount_mountpt $HANASHAREDMNT $HANASHARED_VG $HANASHARED_LV
             start_hana_service
         fi
      else
         echo "ERRORMSG: Unable to activate the volume group $DATA_VG as it does not exists"
         exit 1
      fi
   ########### If DATA and LOG are same VG ####################
   elif [[ "$DATA_VG" == "$LOG_VG" ]]; then
        CHECKVG="$(check_vg_exists $DATA_VG)"
        if [[ ! -z "$CHECKVG" ]]; then
           enable_vg $DATA_VG
           mount_mountpt $DATAMNT $DATA_VG $DATA_LV
           mount_mountpt $LOGMNT  $LOG_VG $LOG_LV
        else
           echo "ERRORMSG: Unable to activate the volume group $DATA_VG as it does not exists"
           exit 1
        fi
   else
       CHECKVG="$(check_vg_exists $DATA_VG)"
       if [[ ! -z "$CHECKVG" ]]; then
          enable_vg $DATA_VG
          mount_mountpt $DATAMNT $DATA_VG $DATA_LV
       else
          echo "ERRORMSG: Unable to activate the volume group $DATA_VG as it does not exists"
          exit 1
       fi
       CHECKVG="$(check_vg_exists $LOG_VG)"
       if [[ ! -z "$CHECKVG" ]]; then
          enable_vg $LOG_VG
          mount_mountpt $LOGMNT $LOG_VG $LOG_LV
       else
          echo "ERRORMSG: Unable to activate the volume group $LOG_VG as it does not exists"
          exit 1
       fi
   fi
else ##### NEWTARGET = TRUE
   if [[ "$DATA_VG" == "$LOG_VG" ]]; then
      CHECKVG="$(grep $DATA_VG $CONFIGFILE_LOC | awk -F":" '{print $2}')"
      if [[ -z "$CHECKVG" ]]; then
         enable_vg $DATA_VG
         mount_mountpt $DATAMNT $DATA_VG $DATA_LV
         mount_mountpt $LOGMNT  $LOG_VG $LOG_LV
      elif [[ "$CHECKVG" == "YES" ]]; then
           clone_vg $DATA_VG'_'$VG_POSTFIX $DATA_PDDEVICENAMES
           enable_vg $DATA_VG'_'$VG_POSTFIX
           mount_mountpt $DATAMNT  $DATA_VG'_'$VG_POSTFIX $DATA_LV
           mount_mountpt $LOGMNT $LOG_VG'_'$VG_POSTFIX $LOG_LV
      fi
   else
      CHECKVG="$(grep $DATA_VG $CONFIGFILE_LOC | awk -F":" '{print $2}')"
      if [[ -z "$CHECKVG" ]]; then
         enable_vg $DATA_VG
         mount_mountpt $DATAMNT $DATA_VG $DATA_LV
      elif  [[ "$CHECKVG" == "YES" ]]; then
            clone_vg $DATA_VG'_'$VG_POSTFIX $DATA_PDDEVICENAMES
            enable_vg $DATA_VG'_'$VG_POSTFIX
            mount_mountpt $DATAMNT  $DATA_VG'_'$VG_POSTFIX $DATA_LV
      fi
      CHECKVG="$(grep $LOG_VG $CONFIGFILE_LOC | awk -F":" '{print $2}')"
      if [[ -z "$CHECKVG" ]]; then
         enable_vg $LOG_VG
         mount_mountpt $LOGMNT $LOG_VG $LOG_LV
      elif  [[ "$CHECKVG" == "YES" ]]; then
            clone_vg $LOG_VG'_'$VG_POSTFIX $LOG_PDDEVICENAMES
            enable_vg $LOG_VG'_'$VG_POSTFIX
            mount_mountpt $LOGMNT $LOG_VG'_'$VG_POSTFIX $LOG_LV
      fi
   fi
   if [[ -f $CONFIGFILE_LOC ]]; then
      rm -f $CONFIGFILE_LO
   fi
fi

#FORMAT: logbackupvol-/logbackup:pd-logbackup, pd-logbackup1,pd-logbackup2;logbackupvol-/logbackup_<1234>1;
if [[ ! -z "$LOGBACKUP_DEVICE_MAPPINGS" ]]; then
   logmntcount=1
   CHECKVG=
   for devicedetails in $(echo $LOGBACKUP_DEVICE_MAPPINGS |tr ';' ' ')
   do
     LOGBACKUPMNT="$(echo $devicedetails | awk -F":" '{print $1}'| awk -F "-" '{print $2}')"
     DEVICE_NAMES_LIST="$(echo $devicedetails | awk -F':' '{print $2}')"  ## Gets the devicename list from $LOGBACKUP_DEVICE_MAPPINGS
     if [[ "$logmntcount" -eq 1 ]]; then
        CHECKVG="$(grep $LOGBACKUP_VG $CONFIGFILE_LOC | awk -F":" '{print $2}')"
        if [[ -z "$CHECKVG" ]]; then
           enable_vg $LOGBACKUP_VG
           mount_mountpt $LOGBACKUPMNT $LOGBACKUP_VG $LOGBACKUP_LV
        elif [[ "$CHECKVG" == "YES" ]]; then
             clone_vg $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount $DEVICE_NAMES_LIST
             enable_vg $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount
             mount_mountpt $LOGBACKUPMNT $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount $LOGBACKUP_LV
        fi
     else
        clone_vg $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount $DEVICE_NAMES_LIST
        enable_vg $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount
        mount_mountpt $LOGBACKUPMNT $LOGBACKUP_VG'_'$VG_POSTFIX$logmntcount $LOGBACKUP_LV
     fi
     logmntcount=$(($logmntcount+1))
    done
fi

exit 0
