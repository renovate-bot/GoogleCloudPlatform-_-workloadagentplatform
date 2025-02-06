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

DBSID=$1
OLDDBSID=$2
ACT_MOUNT_POINTS=$3
DBUSER=$4
HANAVERSION=$5
APPREMOUNT=$6
DATAPATH="$7"
LOGMOUNTPATH="$8"
RECOVERYTIME="$9"

DBSID=`echo $DBSID | tr '[A-Z]' '[a-z]'`
#export ACT_JOBTYPE=mount
#export ACT_PHASE=post

#source /act/custom_apps/saphana/clone/mount_detail.txt
source /act/custom_apps/saphana/act_saphana_comm_func.sh

if [ -z $DBSID ]; then
echo "ERRORMSG: Post Mount: Database SID is not set "
exit 1
fi

dbsidadm=$DBSID"adm"
export dbsidadm
DATAVOLUMEOWNER=$dbsidadm":sapsys"
export DATAVOLUMEOWNER

if [ -f /act/touch/.hana_migrate_"$DBSID".conf ]; then
   rm -f /act/touch/.hana_migrate_"$DBSID".conf
fi
####################### PROCESS MULTIPLE LOG MOUNTS ######################
process_multi_logmounts $LOGMOUNTPATH

###### Added for replication cluster recovery ######
if [ -z "$CLUSTERTYPE" ]; then
   CLUSTERTYPE=`grep CLUSTERTYPE /act/touch/"$OLDDBSID"_mount_params | awk -F"=" '{print $2}'`
fi
#if [ "$CLUSTERTYPE" = "replication" ]; then
   if [ -z "$CATALOGBACKUPPATH" ]; then
      CATALOGBACKUPPATH=`grep CATALOGBACKUPPATH /act/touch/"$OLDDBSID"_mount_params | awk -F"=" '{print $2}'`
   fi
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
         chown -R $DATAVOLUMEOWNER $logdirpath/$logdir
      else
         chown -R $DATAVOLUMEOWNER $logdirpath
      fi
   fi
#fi

echo "DATAVOLUMEOWNERNEW: $DATAVOLUMEOWNER "
if [ -z $ACT_MOUNT_POINTS ]; then
 echo "ERRORMSG: Post Mount: Failed to retrieve mount points. Recovery may fail"
 exit 1
else
   chown -R $DATAVOLUMEOWNER $ACT_MOUNT_POINTS
   if [ ! -z "$LOGMOUNTPATH" ]; then
      for lgmnt in $(echo $LOGMOUNTPATH | tr ',' ' ' )
      do
       chown -R $DATAVOLUMEOWNER $lgmnt
      done
   fi
fi

echo "********** call HANA DB recovery ************"

su - $dbsidadm -c "$WPWD/ACT_HANADB_saphana_recover.sh $DBSID $OLDDBSID $DBUSER $HANAVERSION $APPREMOUNT $DATAPATH $LOGMOUNTPATH \"$RECOVERYTIME\""

retval=$?

if [ "$createdir" = "true" ]; then
   if [ ! -z "$logdirpath" ] && [ "$logdirpath" != "/" ]; then
      rm -rf $logdirpath
   fi
elif [ "$createdir" = "false" ]; then
     rm -f $logdirpath/$logdir
     mv $logdirpath/$logdir'.'$tdate $logdirpath/$logdir
fi

if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Failed to recover $DBSID database: check customapp-saphana.log for details."
    exit $retval
fi

exit 0
