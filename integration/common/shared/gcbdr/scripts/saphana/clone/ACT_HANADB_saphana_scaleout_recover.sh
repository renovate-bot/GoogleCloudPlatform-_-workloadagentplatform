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

dbsid=$1
DBUSER=$2
RECOVERYTIME=$3

JOBNAME=$ACT_JOBNAME

INPUTFILE=`echo /act/touch/${JOBNAME}_lvmapping`
tdate=`date +%Y%m%d%H%M%S`
DBSIDlow=`echo "$dbsid" | awk '{print tolower($0)}'`
DBSIDupper=`echo "$dbsid" | awk '{print toupper($0)}'`
HANAuser=`echo "$DBSIDlow""adm"`
SYSNUMBER=`su - "$HANAuser" bash -c 'echo $TINSTANCE'`
if [ -z "$SYSNUMBER" ]; then
   SYSNUMBER=`su - $HANAuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
fi
globalpath=`su - $HANAuser -c 'echo $DIR_INSTANCE'`
globalpath=`dirname $globalpath`
globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
TIMESTAMP=`date +%y-%m-%d`
exepath=$globalpath/SYS/exe/hdb
pythonpath=$exepath/python_support


revert_fstab() {
 set +x
 tdate=$1
 serverlist=$2
 masternode=$3
 for sname in $(echo $serverlist)
 do
   if [ "$sname" = "$masternode" ]; then
      cp /act/touch/fstab.$tdate /etc/fstab
      rm -f /act/touch/fstab.$date
      mount -a > /dev/null 2>&1
   else
      ssh -o "StrictHostKeyChecking=no" $sname "cp /act/touch/fstab.$tdate /etc/fstab"
      ssh -o "StrictHostKeyChecking=no" $sname "rm -f /act/touch/fstab.$tdate"
      ssh -o "StrictHostKeyChecking=no" $sname "mount -a > /dev/null 2>&1"
   fi
 done
 set -x
}

backup_fstab() {
 tdate=$1
 serverlist=$2
 masternode=$3
 for sname in $(echo $serverlist)
 do
   if [ "$sname" = "$masternode" ]; then
      if [ ! -d /act/touch ]; then
         mkdir -p /act/touch
      fi
      cp /etc/fstab /act/touch/fstab.$tdate
   else
       ssh -o "StrictHostKeyChecking=no" $sname "mkdir -p /act/touch"
       ssh -o "StrictHostKeyChecking=no" $sname "cp /etc/fstab /act/touch/fstab.$tdate"
   fi
 done
}

if [[ X$dbsid == X ]]
then echo "ERRORMSG: Missing argument Database SID"
  exit 1
else
  length=`expr length "$dbsid"`
  if [[ "$length" != 3 ]]
  then echo "ERRORMSG: Invalid argument for Database SID $dbsid - length is different than 3"
    exit 1
  else
    echo "INFO : Database SID is $DBSIDupper"
  fi
fi


if id "$HANAuser" >/dev/null 2>&1
then echo "INFO: user $HANAuser exists"
else echo "ERRORMSG: user $HANAuser does not exist"
  exit 1
fi

if [[ X$SYSNUMBER == X ]]
then "ERRORMSG: System number of instance $DBSIDupper was not detected"
  exit 1
fi

if [[ X$INPUTFILE == X ]]
then echo "ERRORMSG: Missing argument Input file for Volume group adaptation"
  exit 1
else
  if [[ ! -f $INPUTFILE ]]
  then echo "ERRORMSG: Input file for Volume group adaptation $INPUTFILE does not exist"
    exit 1
  else
    echo "INFO: Input file for Volume group adaptation is $INPUTFILE"
    echo "INFO: Input file contain :"
    cat $INPUTFILE
  fi
fi


if [[ X$DBUSER == X ]]
then echo "ERRORMSG: Missing argument Userstore Key"
  exit 1
else echo "INFO: the Userstore key to use is $DBUSER"
fi


#HANAISUP=`su - "$HANAuser" bash -c "HDB info" | grep nameserver | grep -v \"grep\" | wc -l`
#if [[ X$HANAISUP == X1 ]]
#then
#  KEYEXIST=`su - "$HANAuser" bash -c "hdbsql -U ${DBUSER} -a -j \"select * from dummy\"" | head -n1`
  su - $HANAuser -c "hdbuserstore list $DBUSER"
  KEYEXIST=$?
  if [ "$KEYEXIST" -gt 0 ]; then
   echo "WARNING: KEY "$DBUSER" doesn't exist or password combinaison is wrong"
   echo "WARNING: The procedure will continue without checking $DBUSER"
   exit 1
  fi
#else

#echo "The script is trying to start the database, if the Database is not ready to start it will bring up the daemon to be able to use the recovery command"
#su - $HANAuser bash -c "HDB start"

#fi
#need to add a check that KEY will be able to connect after recovery if password change

SSLENFORCE=`grep "^sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

su - $HANAuser bash -c "sapcontrol -nr $SYSNUMBER -function GetSystemInstanceList" &>/dev/null

if [ "$?" -gt 0 ]; then
   echo "ERRORMSG: Failed to run sapcontrol command. Please check and re-run the recoveryagain!"
   exit 1
fi


su - $HANAuser bash -c "sapcontrol -nr $SYSNUMBER -function StopSystem"

HANAISUP_CMD=`echo "su - \"$HANAuser\" bash -c \"sapcontrol -nr $SYSNUMBER -function GetSystemInstanceList | grep -Ei \\\\\"GREEN|YELLOW|RED\\\\\" | wc -l\""`
echo "$HANAISUP_CMD"
HANAISUP=`eval $HANAISUP_CMD | awk '{printf $1}'`

if [[ X$HANAISUP != X0 ]]
then

until [[ X$HANAISUP == X0 ]]
do
sleep 30

HANAISUP=`eval $HANAISUP_CMD | awk '{printf $1}'`
echo "HANA is still up please wait"
done
fi

ISNONSHARED=`cat $globalinipath | grep ^basepath_shared | cut -d'=' -f2-`
ISNONSHARED="$(echo -e "${ISNONSHARED}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ $ISNONSHARED != no ]]
then echo "ERRORMSG: The instance $DBSIDupper is not a non-shared cluster"
exit 1
fi

ISFCCLIENT=`cat $globalinipath | grep ^ha_provider | cut -d'=' -f2-`
ISFCCLIENT="$(echo -e "${ISFCCLIENT}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

if [[ X$ISFCCLIENT == X ]]
then SCLOUT_CONFIG=`echo NONSHARED_MOUNTED`
else SCLOUT_CONFIG=`echo NONSHARED_NOT_MOUNTED`
fi

########### Function to Check If there is any change in VGNAME after first mount and migrate ###################
function remountactmounts()
{
  set +x
  while read line
  do
    fsdevice=`echo $line | awk '{print $6}'`
    umount $fsdevice >/dev/null 2>&1
    eval $line
  done < <(grep $ACT_JOBNAME /var/act/log/UDSAgent.log | grep "mount \-t" | grep -v archivelog |awk -F"cmd:" '{print $2}')
  set -x

}

function checkvgnames() {
  INPUTFILE=$1
  globalinipath=$2
  globalpath=$3

  isnum='^[0-9]+$'
set -x
  DATAVOLUME=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2- |xargs`
  masternode=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep ^master |cut -d'=' -f2- |cut -d':' -f-1`

  servername=`cat ${globalpath}/SYS/global/hdb/custom/config/nameserver.ini | grep ^roles_ |cut -d'_' -f2- |cut -d'=' -f-1`

  mntpt=`df -P $DATAVOLUME |rev |awk 'NR==2{print $1}' |rev`
  if [ -z "$mntpt" ]; then
     echo "ERRORMSG: $DATAVOLUME is not mounted. Please mount and restart the recovery"
     exit 1
  fi

  mntdirexists=`ls -d $DATAVOLUME/mnt* |wc -l`
  if [ "$mntdirexists" -eq 0 ]; then
     echo "ERRORMSG: mnt000* directory doesnot exist. Please check!"
     exit 1
  fi

  MNT_DETECTION=`dirname $DATAVOLUME/mnt*/hdb* | head -1`
  MNT_DETECTION=`basename $MNT_DETECTION`

  if [ -z "$MNT_DETECTION" ]; then
     echo "ERRORMSG: Unable to find mnt0000* directory to identify the role!"
     revert_fstab $tdate "$servername" $masternode
     exit 1;
  fi

  for i in $(cat $INPUTFILE | grep $MNT_DETECTION)
  do
    devicename=`echo $i | awk -F":" '{print $2}'`
    ismapper=`echo $devicename | grep mapper |wc -l`
    if [ "$ismapper" -gt 0 ]; then
         vgname=`echo $devicename | awk -F"/" '{print $4}'`
    else
       vgname=`echo $devicename | awk -F"/" '{print $3}'`
    fi
    vgdisplay -v $vgname &>/dev/null
    if [ "$?" -gt 0 ]; then
       checkvgname_char=`echo $vgname | rev |cut -c1`
       if [ -n "$checkvgname_char" ] && [ "$checkvgname_char" -eq "$checkvgname_char" ] 2>/dev/null; then
          newvgname=`echo $vgname | sed 's/.$//'`
       else
          mntdir_char=`echo $MNT_DETECTION |rev | cut -c1`
          newvgname=$vgname$mntdir_char
       fi
       vgdisplay -v $newvgname &>/dev/null
       if [ "$?" -eq 0 ]; then
          newdevicename=`echo $devicename | sed "s/$vgname/$newvgname/g"`
          sed -i "s|$MNT_DETECTION:$devicename|$MNT_DETECTION:$newdevicename|g" $INPUTFILE
       else
          echo "ERRORMSG:Unable to find the Volume Group!"
          exit 1
       fi
    fi
  done
}


function mountcheck() {
set -x
globalinipath=$1
DATAVOLUME_FS_CHECK=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2-`
DATAVOLUME_FS_CHECK="$(echo -e "${DATAVOLUME_FS_CHECK}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

LOGVOLUME_FS_CHECK=`cat $globalinipath | grep ^basepath_logvolumes | cut -d'=' -f2-`
LOGVOLUME_FS_CHECK="$(echo -e "${LOGVOLUME_FS_CHECK}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

MOUNTPOINT_CMD=`echo "df -l --output=target | grep -E \"^${DATAVOLUME_FS_CHECK}|^${LOGVOLUME_FS_CHECK}\""`
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`


if [[ X$MNTPOINT_RESULT != X ]]
then
COUNT=0
until [[ X$MNTPOINT_RESULT == X ]]
do
sleep 15
COUNT=$((COUNT+1))
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`
echo "INFO: there is still at least one FS mounted please wait"
  if [[ $COUNT  == 4 ]]
  then break
  fi
done
fi


MOUNT_CHECK=`df -l | grep -E "${DATAVOLUME_FS_CHECK}|${LOGVOLUME_FS_CHECK}"  | wc -l`

if [[ X$MOUNT_CHECK == X0 ]]
  then echo "INFO: File systems are unmounted, the procedure can continue"
  else echo "WARNING: File systems are still mounted procedure will unmount it force"
fi

if [[ X$MOUNT_CHECK != X0 ]]
  then MOUNTPOINT_DATA=`df -l --output=target | grep ^${DATAVOLUME_FS_CHECK}`
   if [[ X$MOUNTPOINT_DATA != X ]] && [[ X$MOUNTPOINT_DATA != "X/dev" ]]
   then UNMOUNT_CMD_DATA=`echo "umount $MOUNTPOINT_DATA"`
          eval $UNMOUNT_CMD_DATA
   fi

        MOUNTPOINT_LOG=`df -l --output=target | grep ^${LOGVOLUME_FS_CHECK}`
        if [[ X$MOUNTPOINT_LOG != X ]] && [[ X$MOUNTPOINT_LOG != "X/dev" ]]
   then UNMOUNT_CMD_LOG=`echo "umount $MOUNTPOINT_LOG"`
          eval $UNMOUNT_CMD_LOG
   fi
fi

MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`

if [[ X$MNTPOINT_RESULT != X ]]
then
COUNT=0
until [[ X$MNTPOINT_RESULT == X ]]
do
sleep 15
COUNT=$((COUNT+1))
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`
echo "INFO: there is still at least one FS mounted please wait"
  if [[ $COUNT  == 4 ]]
  then break
  fi
done
fi

MOUNT_CHECK_FORCE=`df -l | grep -E "^${DATAVOLUME_FS_CHECK}|^${LOGVOLUME_FS_CHECK}"  | wc -l`

if [[ X$MOUNT_CHECK_FORCE == X0 ]]
  then echo "INFO: File systems are force unmounted, the procedure can continue"
  else echo "ERRORMSG: File systems are still mounted procedure abort"
  revert_fstab $tdate "$servername" $masternode
    exit 1
fi
}

function mountcheck_staging() {
set -x
globalinipath=$1
ACT_STAGINGDATA_FS_CHECK=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2-`
ACT_STAGINGDATA_FS_CHECK="$(echo -e "${ACT_STAGINGDATA_FS_CHECK}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"


ACT_STAGINGLOG_FS_CHECK=`cat $globalinipath | grep ^basepath_logvolumes | cut -d'=' -f2-`
ACT_STAGINGLOG_FS_CHECK="$(echo -e "${ACT_STAGINGLOG_FS_CHECK}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

MOUNTPOINT_CMD=`echo "df -l --output=target | grep -E \"^${ACT_STAGINGDATA_FS_CHECK}|^${ACT_STAGINGLOG_FS_CHECK}\""`
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`


if [[ X$MNTPOINT_RESULT != X ]]
then
COUNT=0
until [[ X$MNTPOINT_RESULT == X ]]
do
sleep 15
COUNT=$((COUNT+1))
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`
echo "INFO: there is still at least one FS mounted please wait"
  if [[ $COUNT  == 4 ]]
  then break
  fi
done
fi


ACT_STAGINGMOUNT_CHECK=`df -l | grep -E "^${ACT_STAGINGDATA_FS_CHECK}|^${ACT_STAGINGLOG_FS_CHECK}"  | wc -l`

if [[ X$ACT_STAGINGMOUNT_CHECK == X0 ]]
  then echo "INFO: File systems on staging disks are not mounted, the procedure can continue"
  else echo "WARNING: File systems on staging disks are mounted procedure will unmount it force"
fi

if [[ X$ACT_STAGINGMOUNT_CHECK != X0 ]]
  then ACT_STAGINGMOUNTPOINT_DATA=`df -l --output=target | grep ^${ACT_STAGINGDATA_FS_CHECK}`
    if [[ X$ACT_STAGINGMOUNTPOINT_DATA != X ]] && [[ X$ACT_STAGINGMOUNTPOINT_DATA != "X/dev" ]]
    then UNMOUNT_CMD_DATA=`echo "umount $ACT_STAGINGMOUNTPOINT_DATA"`
      eval $UNMOUNT_CMD_DATA
    fi

    ACT_STAGINGMOUNTPOINT_LOG=`df -l --output=target | grep ^${ACT_STAGINGLOG_FS_CHECK}`
    if [[ X$ACT_STAGINGMOUNTPOINT_LOG != X ]] && [[ X$ACT_STAGINGMOUNTPOINT_LOG != "X/dev" ]]
    then UNMOUNT_CMD_LOG=`echo "umount $ACT_STAGINGMOUNTPOINT_LOG"`
      eval $UNMOUNT_CMD_LOG
    fi
fi

MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`


if [[ X$MNTPOINT_RESULT != X ]]
then
COUNT=0
until [[ X$MNTPOINT_RESULT == X ]]
do
sleep 15
COUNT=$((COUNT+1))
MNTPOINT_RESULT=`eval $MOUNTPOINT_CMD`
echo "INFO: there is still at least one FS mounted please wait"
  if [[ $COUNT  == 4 ]]
  then break
  fi
done
fi


ACT_STAGING_MOUNT_CHECK_FORCE=`df -l | grep -E "^${ACT_STAGINGDATA_FS_CHECK}|^${ACT_STAGINGLOG_FS_CHECK}"  | wc -l`

if [[ X$ACT_STAGING_MOUNT_CHECK_FORCE == X0 ]]
  then echo "INFO: File systems on staging disks are force unmounted, the procedure can continue"
  else echo "ERRORMSG: File systems on staging disks are still mounted - procedure abort"
  revert_fstab $tdate "$servername" $masternode
    exit 1
fi

}

function update_mountpoint() {
set -x
globalinipath=$1
INPUTFILE=$2
TIMESTAMP=$3
dbsid=$4
#backup fstab
    echo "INFO: Backup /etc/fstab to ${INPUTFILE}_${dbsid}_fstab"

    if [[ ! -f ${INPUTFILE}_${dbsid}_fstab ]]
    then
      cp -pr /etc/fstab ${INPUTFILE}_${dbsid}_fstab
    fi

DATAVOLUME=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2-`
DATAVOLUME="$(echo -e "${DATAVOLUME}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
echo "INFO : Data volume is located on $DATAVOLUME"

LOGVOLUME=`cat $globalinipath | grep ^basepath_logvolumes | cut -d'=' -f2-`
LOGVOLUME="$(echo -e "${LOGVOLUME}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
echo "INFO : Log volume is located on $LOGVOLUME"

MNT_DETECTION=`dirname $DATAVOLUME/mnt*/hdb* | head -1`
MNT_DETECTION=`basename $MNT_DETECTION`
echo $MNT_DETECTION

INPUTFILE_EXCLUSION=`cat ${INPUTFILE} | grep -v ^$MNT_DETECTION`
#INPUTFILE_EXCLUSION=`cat ${INPUTFILE} | grep ^$MNT_DETECTION`
for i in ${INPUTFILE_EXCLUSION}
   do

   FS_EXCLUDE=`echo $i | awk -F ":" '{ printf $3 }'`
   MNT_EXCLUDE=`df $FS_EXCLUDE | sed -e 1d | head -3 | awk '{ printf $6 }'`

    PROTECT_MNT=`dirname $MNT_EXCLUDE`
    PROTECT_MNT=`dirname $PROTECT_MNT`

   if [[ X$MNT_EXCLUDE != X ]] && [[ X$MNT_EXCLUDE != X$PROTECT_MNT ]] && [[ X$MNT_EXCLUDE != "X/dev" ]]
   then
   umount $MNT_EXCLUDE
   sed -i "s:^${FS_EXCLUDE}:#&:" /etc/fstab
   fi
   done

INPUTFILE_INCLUSION=`cat ${INPUTFILE} | grep ^$MNT_DETECTION`
for i in ${INPUTFILE_INCLUSION}
   do

   FS_INCLUDE=`echo $i | awk -F ":" '{ printf $3 }'`
   MNT_INCLUDE=`df $FS_INCLUDE | sed -e 1d|head -3 | awk '{ printf $6 }'`

    PROTECT_MNT=`dirname $MNT_INCLUDE`
    PROTECT_MNT=`dirname $PROTECT_MNT`

   if [[ X$MNT_INCLUDE != X ]] && [[ X$MNT_INCLUDE != X$PROTECT_MNT ]] && [[ X$MNT_INCLUDE != "X/dev" ]]
   then
     DATAVOLUME_DIR=`dirname $DATAVOLUME`
     LOGVOLUME_DIR=`dirname $LOGVOLUME`

     if [[ X$MNT_INCLUDE != X$DATAVOLUME ]] && [[ X$MNT_INCLUDE != X$DATAVOLUME_DIR ]] && [[ X$MNT_INCLUDE != X$LOGVOLUME_DIR ]] && [[ X$MNT_INCLUDE != X$LOGVOLUME ]] && [[ X$MNT_INCLUDE != "X/dev" ]]
     then
     umount $MNT_INCLUDE
     if [ "$?" -gt 0 ]; then
        echo "ERRORMSG: Failed to unmount $MNT_INCLUDE"
        revert_fstab $tdate "$servername" $masternode
        exit 1
     fi
     sed -i "s:^${FS_INCLUDE}:#&:" /etc/fstab
     fi
   fi
   done


INPUTFILE_READ=`cat ${INPUTFILE} | grep ^$MNT_DETECTION`
for i in ${INPUTFILE_READ}
   do

   VG_TO_UPDATE=`echo $i | awk -F ":" '{ printf $2 }'`
   FS_TARGET=`echo $i | awk -F ":" '{ printf $3 }'`
   FS_FROM_VG_SRC=`lvdisplay -C -o "lv_path,lv_dm_path" | grep $VG_TO_UPDATE | awk '{ printf $2 }'`
   CHECK_FSTAB_ENTRY=`grep "^$FS_FROM_VG_SRC" /etc/fstab|grep -v grep | wc -l`
   if [ "$CHECK_FSTAB_ENTRY" -eq 0 ]; then
      CHECK_FSTAB_ENTRY=`grep "^$VG_TO_UPDATE" /etc/fstab|grep -v grep | wc -l`
      FS_FROM_VG_SRC=$VG_TO_UPDATE
   fi
   if [ "$CHECK_FSTAB_ENTRY" -eq 0 ]; then
      echo "ERRORMSG: /etc/fstab entry does not exist for $FS_FROM_VG_SRC, Please add the entry"
      revert_fstab $tdate "$servername" $masternode > /dev/null 2>&1
      remountactmounts > /dev/null 2>&1
      exit 1
   fi
    CHANGE_CMD="sed -i 's:"${FS_FROM_VG_SRC}":"${FS_TARGET}":g' /etc/fstab"
    eval $CHANGE_CMD
   echo "INFO the fstab value will be changed from $FS_FROM_VG_SRC to $FS_TARGET"
   MOUNTPOINT=`cat /etc/fstab | grep ^$FS_TARGET | awk '{ printf $2 }'`

   if [ ! -z "$MOUNTPOINT" ]; then
      MNT_CHECK_USAGE=`lsof | grep "$MOUNTPOINT"`
   else
      echo "ERRORMSG: Unable to find the mount point "
      revert_fstab $tdate "$servername" $masternode

      exit 1
   fi
   if [[ X$MNT_CHECK_USAGE != X ]]
   then echo "ERRORMSG: Mountpoint $MOUNTPOINT is currently in used - please release it and relaunch procedure"
   revert_fstab $tdate "$servername" $masternode
   remountactmounts > /dev/null 2>&1
   exit 1
   fi

   if [[ X$MOUNTPOINT != X ]] && [[ X$MOUNTPOINT != "X/dev" ]]
   then
   umount $MOUNTPOINT
   mount $MOUNTPOINT
   fi

     CHECK_MOUNT_FS=`df | grep $MOUNTPOINT`
     #if [[ "X$CHECK_MOUNT_FS" != X ]]
     if [ "X$CHECK_MOUNT_FS" = "X" ]
     then echo "ERRORMSG: The file system $MOUNTPOINT is not mounted the procedure will be aborted"
     #exit 1
     fi
   done


}

function update_mountStaging() {
set -x
globalinipath=$1
INPUTFILE=$2
dbsid=$3

DATAVOLUME=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2-`
DATAVOLUME="$(echo -e "${DATAVOLUME}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

MNT_DETECTION=`dirname $DATAVOLUME/mnt*/hdb* | head -1`
MNT_DETECTION=`basename $MNT_DETECTION`
echo $MNT_DETECTION

INPUTFILE_READ=`cat ${INPUTFILE} | grep ^$MNT_DETECTION`
for i in ${INPUTFILE_READ}
   do
      FS_TARGET=`echo $i | awk -F ":" '{ printf $3 }'`
      VGNAME=`basename $FS_TARGET`
      VGNAME=`echo $VGNAME | cut -d'-' -f-1`
      vgimport $VGNAME
      vgchange -ay $VGNAME
      systemctl daemon-reload
      mount -a
    done
}



masternode=`cat ${globalpath}/SYS/global/hdb/custom/config/nameserver.ini | grep ^master |cut -d'=' -f2- |cut -d':' -f-1`
masternode="$(echo -e "${masternode}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

servername=`cat ${globalpath}/SYS/global/hdb/custom/config/nameserver.ini | grep ^roles_ |cut -d'_' -f2- |cut -d'=' -f-1`

backup_fstab $tdate "$servername" $masternode
checkvgnames $INPUTFILE $globalinipath $globalpath

if [[ $SCLOUT_CONFIG == NONSHARED_NOT_MOUNTED ]]
then

  for i in ${servername}
   do
     NODE=`echo $i`
     NODE="$(echo -e "${NODE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [[ $NODE != $masternode ]]
    then
      ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f mountcheck);mountcheck $globalinipath"
    else mountcheck $globalinipath
    fi
   done
fi


# check if necessary to add a remote check for each node

echo "INFO: Backup $globalinipath to /var/act/log/"$dbsid"_global_ini.$TIMESTAMP"

if [[ ! -f /var/act/log/"$dbsid"_global_ini.$TIMESTAMP ]]
then
cp -pr $globalinipath /var/act/log/"$dbsid"_global_ini.$TIMESTAMP
else echo "New backup run at $(date +"%c")" >> /var/act/log/"$dbsid"_global_ini.$TIMESTAMP
     echo ""
     cat $globalinipath >> /var/act/log/"$dbsid"_global_ini.$TIMESTAMP
     echo ""
fi

if [[ $SCLOUT_CONFIG == NONSHARED_NOT_MOUNTED ]]
then
  echo "-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"
  echo ""
  echo "Update global.ini file with new VGs mounted"
  echo ""
  echo "cat $INPUTFILE"
  echo ""
  echo "-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*"

  var=`cat $INPUTFILE`

  for v in $(tr ',' '\n' <<< "$var")
  do
        Source_value=`printf "$v" | awk -F ":" '{ printf $1 }'`
        Update_value=`printf "$v" | awk -F ":" '{ printf $2 }'`
   CHANGE_CMD="sed -i 's/"$Source_value"/"$Update_value"/g' $globalinipath"

   eval $CHANGE_CMD

  echo "INFO the source value will be changed $Source_value to $Update_value"
  done

  for i in ${servername}
  do
     NODE=`echo $i`
     NODE="$(echo -e "${NODE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
   if [[ $NODE != $masternode ]]
   then
   ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f mountcheck_staging);mountcheck_staging $globalinipath"
   else mountcheck_staging $globalinipath
   fi
  done

else
  if [[ $SCLOUT_CONFIG == NONSHARED_MOUNTED ]]
  then

  for i in ${servername}
    do
     NODE=`echo $i`
     NODE="$(echo -e "${NODE}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
     NODE=`echo $NODE |xargs`
     masternode=`echo $masternode |xargs`
      if [[ $NODE != $masternode ]]
      then
   scp -pr $INPUTFILE ${NODE}:$INPUTFILE
        ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f checkvgnames);checkvgnames $INPUTFILE $globalinipath $globalpath"

     #else
      #copy transaction log to backup destination for recovery
      #FILE_PARAM=`echo $INPUTFILE | sed 's:lvmapping:mount_params:'`
      #ARCHIVELOG_MNT=`cat $FILE_PARAM | grep ^ARCHIVELOGMOUNTPATH |cut -d'=' -f2-`
      #BACKUPPATH=`cat $globalinipath | grep ^basepath_logbackup |cut -d'=' -f2-`
      #BACKUPPATH="$(echo -e "${BACKUPPATH}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      #rsync -a  $ARCHIVELOG_MNT/ $BACKUPPATH/

      fi
      #ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f update_mountpoint);update_mountpoint $globalinipath $INPUTFILE $TIMESTAMP $dbsid"
      if [ "$NODE" != "$masternode" ]
      then ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f update_mountpoint);update_mountpoint $globalinipath $INPUTFILE $TIMESTAMP $dbsid"
      if [ "$?" -gt 0 ]; then
         echo "ERRORMSG: Failed to run update mountpoints on node $NODE. Please check!"
         revert_fstab $tdate "$servername" $masternode
         remountactmounts > /dev/null 2>&1
         exit 1
      fi
      ssh -o "StrictHostKeyChecking=no" $NODE "$(declare -f update_mountStaging);update_mountStaging $globalinipath $INPUTFILE $dbsid"
      if [ "$?" -gt 0 ]; then
         echo "ERRORMSG: Failed to run update mountpoints on node $NODE. Please check!"
         revert_fstab $tdate "$servername" $masternode
         remountactmounts > /dev/null 2>&1
         exit 1
      fi
      else
          update_mountpoint $globalinipath $INPUTFILE $TIMESTAMP $dbsid
          if [ "$?" -gt 0 ]; then
             echo "ERRORMSG: Failed to run update mountpoints on node $NODE. Please check!"
             revert_fstab $tdate "$servername" $masternode
             remountactmounts > /dev/null 2>&1
             exit 1
          fi
      fi
    done


  else echo "ERRORMSG: The current scale out configuration cannot be identified for instance DBSIDupper"
    revert_fstab $tdate "$servername" $masternode
    remountactmounts > /dev/null 2>&1
    exit 1
  fi

fi


echo "************************** running recoverSys.py  ******************"

if [ ! -z "$RECOVERYTIME" ]
then
MULTIDB=`cat $globalinipath | grep -i -A 3 multidb | grep ^mode | cut -d'=' -f2-`
MULTIDB="$(echo -e "${MULTIDB}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
FILE_PARAM=`echo "/act/touch/${JOBNAME}_mount_params"`
ARCHIVELOG_MNT=`cat $FILE_PARAM | grep ^ARCHIVELOGMOUNTPATH |cut -d'=' -f2-`
DATAPATH=`cat $globalinipath | grep ^basepath_datavolumes | cut -d'=' -f2-`
DATAPATH="$(echo -e "${DATAPATH}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [ "$MULTIDB" != "multidb" ]
  then
   su - $HANAuser bash -c "$globalpath/HDB${SYSNUMBER}/HDBSettings.sh $pythonpath/recoverSys.py --command=\"RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING DATA PATH ('$DATAPATH') USING LOG PATH ('$ARCHIVELOG_MNT') USING SNAPSHOT CHECK ACCESS USING FILE\""

  else
  CATALOGPATH=$ARCHIVELOG_MNT"/SYSTEMDB/"
   su - $HANAuser bash -c "$globalpath/HDB${SYSNUMBER}/HDBSettings.sh $pythonpath/recoverSys.py --command=\"RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ('$CATALOGPATH') USING SNAPSHOT CHECK ACCESS USING FILE\""

  fi
else
su - $HANAuser bash -c "$globalpath/HDB${SYSNUMBER}/HDBSettings.sh $pythonpath/recoverSys.py --command=\"RECOVER DATA USING SNAPSHOT CLEAR LOG\""
fi

retval=$?
if [ "$retval" -eq 0 ]; then
   RECOVERSYS_TRACE_LOC=`su - $HANAuser bash -c 'echo ${DIR_INSTANCE}/${VTHOSTNAME}/trace'`
   JOB_FLAG=`tail -1 $RECOVERSYS_TRACE_LOC/recoverSys.trc | grep -i "failed" |wc -l`
fi
if [ "$JOB_FLAG" -ne 0 ]; then
    echo "ERRORMSG: Recovery:  Failed to recover database $dbsid."
    revert_fstab $tdate "$servername" $masternode
    exit 1
fi

#su - $HANAuser bash -c "$globalpath/HDB${SYSNUMBER}/HDBSettings.sh $pythonpath/recoverSys.py --command=\"RECOVER DATA USING SNAPSHOT CLEAR LOG\""

#retval=$?
if [ $retval -ne 0 ]
then
  echo "ERRORMSG: the recovery did not succeed! please consult RecoverSys.trc trace file in SAP HANA trace directory."
  revert_fstab $tdate "$servername" $masternode
  exit 1
fi

HANAISUP_CMD=`echo "su - \"$HANAuser\" bash -c \"sapcontrol -nr $SYSNUMBER -function GetSystemInstanceList | grep -Ei \\\\\"GRAY|YELLOW|RED\\\\\" | wc -l\" "`
echo "$HANAISUP_CMD"
HANAISUP=`eval $HANAISUP_CMD | awk '{printf $1}'`

if [[ X$HANAISUP != X0 ]]
then

until [[ X$HANAISUP == X0 ]]
do
sleep 15

HANAISUP=`eval $HANAISUP_CMD | awk '{printf $1}'`
echo "HANA is still down please wait"
done
fi


#extract tenant SID
dbnames=`su - $HANAuser bash -c "$exepath/$hdbsql -U $DBUSER -a -j \"select database_name from m_databases\""`
for i in ${dbnames}
 do
   TSID=`echo $i |awk -F '"' '{print $2}'`
  if [[ X$TSID != XSYSTEMDB ]] && [[ X$TSID != X ]] && [[ X$TSID != XDATABASE_NAME ]] && [ ! -z $TSID ]
  then
    if [ ! -z "$RECOVERYTIME" ]
    then
      CATALOGPATH=$ARCHIVELOG_MNT/'DB'_"$TSID"
      SQL="RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ('$CATALOGPATH') USING SNAPSHOT CHECK ACCESS USING FILE"
      su - $HANAuser bash -c "$exepath/$hdbsql -U $DBUSER -a -j \"$SQL\""
      retval=$?
    else
      su - $HANAuser bash -c "$exepath/$hdbsql -U $DBUSER -a -j \"RECOVER DATA FOR $TSID USING SNAPSHOT CLEAR LOG\""
      retval=$?
    fi
    if [ "$retval" -gt 0 ]; then
       echo "ERRORMSG: Failed to recover the tenant $TSID. Please check the logs for details!"
       exit 1
    fi
  fi
 done

if [ -f /act/touch/fstab.$tdate ]; then
   rm -f /act/touch/fstab.$tdate
fi
exit 0
