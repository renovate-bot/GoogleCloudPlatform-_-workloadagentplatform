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

DBSID=$1
DBUSER=$2
HANAVERSION="$3"
DATAPATH="$4"
RECOVERYTIME="$5"
LOGMOUNTPATH="$6"
JOBID=$JOBID
#source /act/custom_apps/saphana/restore/hana_restore.conf

#export ACT_JOBTYPE=mount
#export ACT_PHASE=post

if [ -z $DBSID ]; then
echo "ERRORMSG: Database SID is not set "
exit 1
fi

dbsidadm=$DBSID"adm"
export dbsidadm
tdate=`date +"%m%d%Y%H%M"`
source /act/custom_apps/saphana/act_saphana_comm_func.sh

SSF_LOCATION=`su - $dbsidadm -c "hdbuserstore list | grep \"DATA FILE\"" `
SSF_LOCATION=`echo $SSF_LOCATION | grep "DATA FILE" |awk -F ":" '{print $2}'`
SSF_LOCATION=`dirname $SSF_LOCATION`
globalpath=`su - $dbsidadm -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`
nameserverini=$globalpath/SYS/global/hdb/custom/config/nameserver.ini
localhostname=`cat $nameserverini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`
sourcehostname=`ls /act/tmpdata/$JOBID/SSFS_HDB.DAT__* |awk -F"__" '{print $2}'`

######## Added to validate global.ini DATAVOL and LOGVOL
TMP_LOGMOUNTPATH=`echo $LOGMOUNTPATH | awk -F"," '{print $1}'`
update_global_file "$DATAPATH" "$LOGPATH" "$TMP_LOGMOUNTPATH" "$BACKUP_TYPE"

DATAVOLPATH=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep "basepath_datavolumes" | awk -F"=" '{print $2}' |xargs`
LOGVOLPATH=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep "basepath_logvolumes" | awk -F"=" '{print $2}' |xargs`
UPPERDBSID="$(echo $DBSID |tr '[a-z]' '[A-Z]')"
sourcedbconfigfile=/act/tmpdata/$JOBID/configuration_"$UPPERDBSID".sql


chown -R $dbsidadm:sapsys $DATAVOLPATH
chown -R $dbsidadm:sapsys $LOGVOLPATH
#chown -R $dbsidadm:sapsys $LOGMOUNTPATH
if [[ "$BACKUP_TYPE" = "NO-PDSNAP" ]] || [[ "$NEWTARGET" == "TRUE" ]]; then
  process_multi_logmounts $LOGMOUNTPATH
fi
if [ ! -z "$LOGMOUNTPATH" ]; then
   for lgmnt in $(echo $LOGMOUNTPATH | tr ',' ' ' )
   do
     chown -R $dbsidadm:sapsys $lgmnt
   done
fi
###### Added for replication cluster recovery ######
if [ -z "$CLUSTERTYPE" ]; then
   CLUSTERTYPE=`grep CLUSTERTYPE /act/touch/"$DBSID"_mount_params | awk -F"=" '{print $2}'`
fi
#if [ "$CLUSTERTYPE" = "replication" ]; then
   if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
      CATALOGBACKUPPATH="$(echo $LOGMOUNTPATH |awk -F "," '{print $1}')"
   else
      if [ -z "$CATALOGBACKUPPATH" ]; then
         CATALOGBACKUPPATH=`grep CATALOGBACKUPPATH /act/touch/"$DBSID"_mount_params | awk -F"=" '{print $2}'`
      fi
   fi
if [[ ! -z "$CATALOGBACKUPPATH" ]] && [[ "$CATALOGBACKUPPATH" != "$TMP_LOGMOUNTPATH" ]]; then
   ismountpoint="$(mountpoint $CATALOGBACKUPPATH)"
   retval=$?
   if [[ "$retval" -gt 0 ]]; then
      logdirpath=`dirname $CATALOGBACKUPPATH`
      logdir=`basename $CATALOGBACKUPPATH`
      if [ -d "$CATALOGBACKUPPATH" ] && [ ! -z "$LOGMOUNTPATH" ]; then
         tdate=`date +%Y%m%d%H%M%S`
         mv $CATALOGBACKUPPATH $logdirpath/$logdir'.'$tdate
         createdir=false
      fi
      if [ ! -d "$logdirpath" ] && [ "$logdirpath" != "/" ]; then
         createdir=true
         mkdir -p $logdirpath
      fi
      if [ ! -z "$LOGMOUNTPATH" ]; then
         LOGMOUNTPATH_LINK=`echo $LOGMOUNTPATH |awk -F "," '{print $1}'`
         ln -s $LOGMOUNTPATH_LINK $logdirpath/$logdir
         if [ "$logdirpath" = "/" ]; then
            chown -R $dbsidadm:sapsys $logdirpath/$logdir
         else
            chown -R $dbsidadm:sapsys $logdirpath
         fi
      fi
   fi
fi

echo "********** call HANA DB recovery ************"
if [[ ! -z "$RESTORE_CONFIG" ]] && [[ "$RESTORE_CONFIG" == "true" ]]; then
   cp $sourcedbconfigfile /act/touch/
   if [[ ! -z "$sourcedbconfigfile" ]]; then
      chown $dbsidadm:sapsys /act/touch/configuration_"$UPPERDBSID".sql
      sourcedbconfigfile=/act/touch/configuration_"$UPPERDBSID".sql
      SOURCE_HOST="$(ls /act/tmpdata/$JOBID/ | grep global.ini| awk -F'__' '{print $2}')"
      localhostname=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini |grep -E "worker =|worker=" |tail -1| awk -F"=" '{print $2}' |xargs`
      if [[ "$SOURCE_HOST" != "$localhostname" ]]; then
         sed -i "s/$SOURCE_HOST/$localhostname/g" $sourcedbconfigfile
      fi
   fi
fi
su - $dbsidadm -c "export sourcedbconfigfile=$sourcedbconfigfile;export RESTORE_CONFIG=$RESTORE_CONFIG;$WPWD/ACT_HANADB_RESTORE_saphana_recover.sh $DBSID $DBUSER $HANAVERSION \"$RECOVERYTIME\" $LOGMOUNTPATH $DATAPATH"

retval=$?

if [ "$createdir" = "true" ]; then
   if [ ! -z "$logdirpath" ] && [ "$logdirpath" != "/" ]; then
      rm -rf $logdirpath
   fi
elif [ "$createdir" = "false" ]; then
     rm -f $logdirpath/$logdir
     mv $logdirpath/$logdir'.'$tdate $logdirpath/$logdir
fi
if [ "$CLUSTERTYPE" = "replication" ]; then
   echo "Clearing Replication site informations....!"
   su - $dbsidadm -c "hdbnsutil -sr_disable -force"
   if [ "$?" -gt 0 ]; then
      echo "ERRORMSG: Unable to clear replicated site information!"
      exit 1
   fi
fi
if  [[ "$BACKUP_TYPE" == "PDSNAP" ]] && [[ $retval -eq 0 ]]; then
    $WPWD/ACT_HANADB_pdsnapshotrestore_logvgdeactivate.sh
    retvalvg=$?
    if [[ "$retvalvg" -ne "0" ]]; then
        echo "WARNINGMSG: Unable to deactivate additional logbackup volume groups"
    fi
fi
if [ $retval -ne 0 ]; then
   if [ -f /act/touch/."$dbsidadm"_userstorekey ]; then
      source /act/touch/."$dbsidadm"_userstorekey
      if [ "$DELETE_USERSTOREKEY" = "YES" ]; then
          su - $dbsidadm -c "hdbuserstore delete $DBUSER"
          if [ "$?" -gt 0 ]; then
             echo "WARNINGMSG:Unable to delete the userstorekey $DBUSER created as part of the restore process!"
          fi
          rm -f /act/touch/."$dbsidadm"_userstorekey
      fi
   fi
   if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
       su - $dbsidadm -c "$WPWD/ACT_HANADB_RESTORE_saphana_stop.sh $dbsid"
       $WPWD/ACT_HANADB_pdsnapshotrestore_vgdeactivate.sh
   fi
    echo "ERRORMSG: Post restore: Failed to recover database $DBSID: check customapp-saphana.log for details"
    exit $retval
fi

echo "********** end HANA DB recover with exit code: $retval ************"
exit 0
