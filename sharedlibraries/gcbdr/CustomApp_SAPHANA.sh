#!/bin/bash
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

BASEPATH="/etc/google-cloud-sap-agent/gcbdr"

function usage()
{
    echo "Please set environment vars ACT_NAME ACT_FRIENDLYTYPE ACT_PHASE and re-run the script"
    echo "Supported phases [prepare|freeze|unfreeze|cleanup|prerestore|postrestore|logbackup|logpurge|loggapcheck]"
    return 0;
}

function cleanup_func()
{
  echo " **** Cleanup phase started **** "
  DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
  DBADM=$DBADM'adm'
  DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
  su - $DBADM -c "$BASEPATH/act_saphana_abort.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION"
  retval=$?
  if [ $retval -ne 0 ]; then
     return $retval
  fi

  return 0;
}

function prepare_func()
{
  echo "**** Prepare phase started ****";
  $BASEPATH/act_saphana_prepare.sh $DBSID $DBUSER
  retval=$?
  if [ $retval -ne 0 ]; then
     return $retval
  fi
  return 0;
}

function freeze_func()
{
  echo "**** Freeze phase started ****"
  DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
  DBADM=$DBADM'adm'
  DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`


  su - $DBADM -c "$BASEPATH/act_saphana_pre.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION"
  retval=$?
  if [ $retval -ne 0 ]; then
      return $retval
  fi

  return 0;
}

function unfreeze_func()
{
  DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
  DBADM=$DBADM'adm'
  DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
  su - $DBADM -c "export JOBNAME=$ACT_JOBNAME;$BASEPATH/act_saphana_post.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION $JOBNAME $SNAPSHOT_STATUS"
  retval=$?
  if [ $retval -ne 0 ]; then
     return $retval
  fi

  if [ -f /tmp/$JOBNAME/HANA.manifest ]; then
     if [[ ! -d "$BASEPATH/touch$JOBNAME" ]]; then
        mkdir -p "$BASEPATH/touch/$JOBNAME"
     fi
     cp /tmp/$JOBNAME/* $BASEPATH/touch/$JOBNAME/
     rm -rf /tmp/$JOBNAME
  fi

    return 0;
}

function prerestore_func()
{
  echo "******** Pre-restore validation started ***********"
  $BASEPATH/restore/ACT_HANADB_pdsnapshotrestore_prechecks.sh
  retval=$?
  if [ $retval -ne 0 ]; then
     return $retval
  fi
  $BASEPATH/restore/ACT_HANADB_prerestore.sh $DBSID
  retval=$?
  if [ $retval -ne 0 ]; then
     return $retval
  fi
  $BASEPATH/restore/ACT_HANADB_pdsnapshotrestore_prerestore.sh
  retval=$?
  if [[ "$retval" -ne "0" ]]; then
     return $retval
  fi

  return 0;
}

function postrestoremount_func()
{
  echo "**** Postresotremount phase started ****"
  $BASEPATH/restore/ACT_HANADB_pdsnapshotrestore_vgactivate.sh
  retval=$?
  if [[ "$retval" -ne "0" ]]; then
     return $retval
  fi
  return 0
}

function postrestorecleanup_func()
{
  echo "**** Postresotrecleanup phase started ****"
  if [[ "$retval" -ne "0" ]]; then
     $BASEPATH/restore/ACT_HANADB_pdsnapshotrestore_vgdeactivate.sh
     return $retval
  fi
  return 0
}

function postrestoredboperations_func()
{
  echo "**** Postresotre phase started ****"
  if [ ! -z "$RESTORE_USERSTOREKEY" ]; then
     DBUSER=$RESTORE_USERSTOREKEY
  else
     DBUSER=$SOURCE_USERSTOREKEY
  fi
  if [ -z "$LOGMOUNTPATH" ]; then
     $BASEPATH/restore/ACT_HANADB_postrestore.sh "$DBSID" "$DBUSER" "$HANAVERSION" "$DATAPATH"
  else
     $BASEPATH/restore/ACT_HANADB_postrestore.sh "$DBSID" "$DBUSER" "$HANAVERSION" $DATAPATH "$RECOVERYTIME" $LOGMOUNTPATH
  fi
  retval=$?
  if [ $retval -ne 0 ]; then
      return $retval
  fi
  return 0;
}

function logbackup_func()
{

  echo "**** log backup started ****"
  DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
  DBADM=$DBADM'adm'
  su - $DBADM -c "mkdir /tmp/$ACT_JOBNAME"
  retval=$?
  if [[ "$retval" -gt 0 ]]; then
     echo "WARNINGMSG: Unable to create the directory /tmp/$ACT_JOBNAME"
  fi
  su - $DBADM -c "export JOBNAME=$JOBNAME;$BASEPATH/act_saphana_logbackup.sh $DBSID $DBUSER"
  retval=$?
  if [ "$retval" -gt 0 ] && [ "$retval" -ne 13 ]; then
     echo "WARNING: Please check the logs for warning errors during logbackup"
  elif [ "$retval" -eq 13 ]; then
       return 1
  fi
  globalpath=`su - $DBADM -c 'echo $DIR_INSTANCE'`
  globalpath=`dirname $globalpath`
  logbackup_path=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "^basepath_logbackup =|^basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`
  if [[ ! -z "$logbackup_path" ]]; then
     sync -f $logbackup_path
  fi
  if [[ "$(ls /tmp/$JOBNAME/*.rkb)" ]]; then
     ls -ltr /tmp/$JOBNAME/*
     cp /tmp/$JOBNAME/*.rkb /act/tmpdata/$JOBNAME/
  fi
  rm -rf /tmp/$JOBNAME
  echo "**** log backup ended ****"
  return 0;
}

function loggapcheck_func()
{
  echo "**** log gap check started ****"
  DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
  DBADM=$DBADM'adm'
  $BASEPATH/act_saphana_logbackup_gapcheck.sh $DBSID $DBUSER
  if [ "$?" -gt 0 ]; then
     echo "WARNING: Please check the logs for warning errors during loggap check"
  fi
  echo "**** log gap check ended ****"
  return 0;
}

function logpurge_func
{
   echo "**** log purge started ****"
   DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
   DBADM=$DBADM'adm'
   DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`

   if [ -z "$PRETDBUSER" ]; then
      PRETDBUSER=$DBUSER
   fi
   su - $DBADM -c "/act/custom_apps/saphana/act_saphana_logdelete.sh $DBSID $DBUSER $PRETDBUSER $DBPORT $PORT $DELLOG $HANAVERSION $USESYSTEMDBKEY \"$ENDPIT\" $DELETE_LOGFILES_HOURS $LASTBACKEDUPDBNAMES $SNAPSHOT_TYPE $NO_LOGPURGE"
   retval=$?
   if [ $retval -ne 0 ]; then
      return $retval
   fi
  return 0;
}

if [ -n $ACT_PHASE ]
then
   PARAM=$ACT_PHASE
   BASEPATH="/etc/google-cloud-sap-agent/gcbdr"
   if [[ ! -d "$BASEPATH" ]]; then
       mkdir -p $BASEPATH
   fi
   if [[ ! -d "$BASEPATH/touch" ]]; then
       mkdir -p $BASEPATH/touch
       chmod 755 $BASEPATH/touch
   else
      chmod 755 $BASEPATH/touch
   fi
   if [[ ! -d "$BASEPATH/touch/$JOBNAME" ]]; then
      mkdir -p $BASEPATH/touch/$JOBNAME
      chmod 755 $BASEPATH/touch/$JOBNAME
   fi
   case $PARAM in
     cleanup)
         echo "Executing cleanup phase of the script"
         cleanup_func
         retval=$?
         ;;
     prepare)
         echo "Executing prepare phase of the script"
         prepare_func
         retval=$?
         ;;
     freeze)
         echo "Executing freeze phase of the script"
         freeze_func
         retval=$?
         ;;
     unfreeze)
         echo "Executing unfreeze phase of the script"
         unfreeze_func
         retval=$?
         ;;
     prerestore)
         echo "Executing prerestore phase of the script"
         prerestore_func
         retval=$?
         ;;
     postrestoredboperation)
         echo "Executing postrestore phase of the script"
         postrestoredboperations_func
         retval=$?
         ;;
     postrestoremount)
         echo "Executing postrestore phase of the script"
         postrestoremount_func
         retval=$?
         ;;
     postrestorecleanup)
         echo "Executing postrestore phase of the script"
         postrestorecleanup_func
         retval=$?
         ;;
      logbackup)
         echo "Executing logbackup phase of the script"
         logbackup_func
         retval=$?
         ;;
      loggapcheck)
         echo "Executing loggapcheck phase of the script"
         loggapcheck_func
         retval=$?
         ;;
      logpurge)
        echo "Executing logpurge phase of the script"
        logpurge_func
        retval=$?
         ;;
     *)
         usage
   esac
else
    usage
fi

exit $retval;
