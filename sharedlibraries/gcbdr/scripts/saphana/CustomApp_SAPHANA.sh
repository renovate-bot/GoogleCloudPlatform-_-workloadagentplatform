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

function usage()
{
    echo "Please set environment vars ACT_NAME ACT_FRIENDLYTYPE ACT_PHASE and re-run the script"
    echo "Supported phases [prepare|freeze|unfreeze|predump|backintsetup|dbdump|cleanup|premount|postmount|prerestore|postrestore|predumprestore|postdumprestore|premounttest|prerestoretest|logbackup|logpurge|loggapcheck]"
    return 0;
}

function cleanup_func()
{
        DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
        DBADM=$DBADM'adm'
        DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`


        su - $DBADM -c "/act/custom_apps/saphana/act_saphana_abort.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION"
        retval=$?
        if [ $retval -ne 0 ]; then
                return $retval
        fi

    return 0;
}

function prepare_func()
{
    echo "**** Prepare phase started ****";
    /act/custom_apps/saphana/act_saphana_prepare.sh $DBSID $DBUSER
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


   su - $DBADM -c "/act/custom_apps/saphana/act_saphana_pre.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION"
   retval=$?
        if [ -f /act/touch/hanabackupdblist.log ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
        cp /act/touch/hanabackupdblist.log /act/tmpdata/$ACT_JOBNAME/
        cp /act/touch/backupstatus.xml /act/tmpdata/$ACT_JOBNAME/
        fi
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
   su - $DBADM -c "/act/custom_apps/saphana/act_saphana_post.sh $DBSID $DBUSER $DBPORT $PORT $HANAVERSION $ACT_JOBNAME $SNAPSHOT_STATUS $SNAPSHOT_TYPE"
   retval=$?
     if [ -f /act/touch/hanabackupdblist.log ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
        mv /act/touch/hanabackupdblist.log /act/tmpdata/$ACT_JOBNAME/
        mv /act/touch/backupstatus.xml /act/tmpdata/$ACT_JOBNAME/
        fi
   if [ $retval -ne 0 ]; then
      return $retval
   fi

        if [ -f /tmp/$ACT_JOBNAME/HANA.manifest ]; then
           cp /tmp/$ACT_JOBNAME/* /act/tmpdata/$ACT_JOBNAME/
           rm -rf /tmp/$ACT_JOBNAME/
        fi

    return 0;
}

function premount_func()
{
    echo "**** Premount phase started ****"
    /act/custom_apps/saphana/clone/ACT_HANADB_premount.sh $DBSID
    retval=$?
   if [ $retval -ne 0 ]; then
       return $retval
   fi
    echo "**** Premount phase ended ****"
    return 0;
}

function predump_func()
{
        echo "**** predump(file system backup) phase has started ****"
        DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
        DBADM=$DBADM'adm'
        if [ -z "$PRETDBUSER" ]; then
           PRETDBUSER=$DBUSER
        fi
   /act/custom_apps/saphana/dump/act_saphana_predump.sh $DBSID $DBUSER $USESYSTEMDBKEY $PRETDBUSER
        retval=$?
        if [ $retval -ne 0 ]; then
                 return $retval
        fi
        /act/custom_apps/saphana/dump/ACT_HANADB_getsize.sh $DBSID $DBUSER $DBPORT $HANAVERSION $USESYSTEMDBKEY $PRETDBUSER
        retval=$?
        if [ $retval -ne 0 ]; then
                 return $retval
        fi

      backintsetup_func

        echo "******* PREDUMP Computed size of DB dump area successfully *****"
        return 0
}

# TODELETE only for Backint testing

function backintsetup_func()
{
   if [ "$USEBACKINT" = "TRUE" ]; then
      DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
           DBADM=$DBADM'adm'
      globalpath=`su -l $DBADM -c env | grep DIR_INSTANCE | cut -d"=" -f2`
      globalpath=`dirname $globalpath`
      globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
           ACTIFIOPAR_FILE=`grep -iw ^catalog_backup_parameter_file $globalinipath | grep actifio_backint_log.par | wc -l`
      LOGBACKINTUSAGE=`grep -iw ^log_backup_using_backint $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
           LOGBACKINTUSAGE=`echo $LOGBACKINTUSAGE | tr '[A-Z]' '[a-z]'`
           if [[ "$LOGBACKINTUSAGE" != "true" ]] && [ "$ACTIFIOPAR_FILE" -eq 0 ]; then
        /act/custom_apps/saphana/sapbackint/setup.sh -install $DBSID KEY $DBUSER
           fi
   fi
}


function dbdump_func()
{
        echo "**** dump(file system backup) phase started ****"

   DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
   DBADM=$DBADM'adm'
        DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
   chown -R $DBADM:sapsys $HANABACKUPPATH
        if [ -z "$PRETDBUSER" ]; then
           PRETDBUSER=$DBUSER
        fi
      if [ "$USEBACKINT" = "TRUE" ]; then
         su - $DBADM -c "/act/custom_apps/saphana/dumpbackint/act_saphana_dumpbrint.sh $DBSID $DBUSER $PRETDBUSER $DBPORT "$ACT_JOBNAME" $PORT $HANAVERSION $HANABACKUPPATH $DUMPSCHEDULE $USESYSTEMDBKEY $RUNTENANTPARALLEL $PREVDBFULLDUMPSAMEDAY $IGNOREPARTIALFAILURE"
        retval=$?
        if [ -f /act/touch/hanabackupdblist.log ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
           mv /act/touch/hanabackupdblist.log /act/tmpdata/$ACT_JOBNAME/
        fi
        if [ -f /act/touch/backupstatus.xml ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
           mv /act/touch/backupstatus.xml /act/tmpdata/$ACT_JOBNAME/
        fi

        if [ $retval -ne 0 ]; then
                return $retval
        fi
      else
        su - $DBADM -c "/act/custom_apps/saphana/dump/act_saphana_dump.sh $DBSID $DBUSER $PRETDBUSER $DBPORT "$ACT_JOBNAME" $PORT $HANAVERSION $HANABACKUPPATH $DUMPSCHEDULE $USESYSTEMDBKEY $RUNTENANTPARALLEL $PREVDBFULLDUMPSAMEDAY $IGNOREPARTIALFAILURE"
        retval=$?
        if [ -f /act/touch/hanabackupdblist.log ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
           mv /act/touch/hanabackupdblist.log /act/tmpdata/$ACT_JOBNAME/
        fi
        if [ -f /act/touch/backupstatus.xml ]; then
           if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
              mkdir -p /act/tmpdata/$ACT_JOBNAME
           fi
           mv /act/touch/backupstatus.xml /act/tmpdata/$ACT_JOBNAME/
        fi

        if [ $retval -ne 0 ]; then
                return $retval
        fi
      fi
        return 0;
}

function postunmount_func
{
    echo "**** Post unmount phase started ****"
    echo "**** Post unmount phase ended ****";

    return 0;
}

function postmount_func()
{
    echo "**** Postmount phase started ****"
    if [ ! -z "$RESTORE_USERSTOREKEY" ]; then
       DBUSER=$RESTORE_USERSTOREKEY
    else
       DBUSER=$SOURCE_USERSTOREKEY
    fi

    if [ -z "$LOGMOUNTPATH" ]; then
      /act/custom_apps/saphana/clone/ACT_HANADB_postmount.sh $DBSID $ACT_NAME $ACT_MOUNT_POINTS $DBUSER "$HANAVERSION" $APPREMOUNT  $DATAPATH
    else
       /act/custom_apps/saphana/clone/ACT_HANADB_postmount.sh $DBSID $ACT_NAME $ACT_MOUNT_POINTS $DBUSER "$HANAVERSION" $APPREMOUNT  $DATAPATH $LOGMOUNTPATH "$RECOVERYTIME"
    fi
   retval=$?
   if [ $retval -ne 0 ]; then
       return $retval
   fi

    return 0;
}

function premounttest_func()
{
    echo "**** Pre-mount test phase started ****"

    if [ ! -z "$RESTORE_USERSTOREKEY" ]; then
       DBUSER=$RESTORE_USERSTOREKEY
    else
       DBUSER=$SOURCE_USERSTOREKEY
    fi

    /act/custom_apps/saphana/clone/ACT_premount_test.sh $DBSID $HANAVERSION $DBUSER $DATAVOLPATH $LOGVOLPATH
    retval=$?
    if [ $retval -ne 0 ]; then
        return $retval
    fi

    echo "**** Premount test phase ended ****"
    return 0;
}

function predumprestoretest_func()
{
    echo "**** Pre-dumprestore test phase started ****"
    echo "**** Pre-dumprestore test phase ended ****";

    return 0;
}

function prerestoretest_func()
{
    echo "**** Pre-restore test phase started ****"
    echo "**** Pre-restore test phase ended ****";

    return 0;
}

function prerestore_func()
{
    echo "******** Pre-restore lvm userstorekey validation started ***********"
    /act/custom_apps/saphana/restore/ACT_HANADB_lvmrestore_prechecks.sh
    retval=$?
    if [ $retval -ne 0 ]; then
       return $retval
    fi
    echo "**** Prerestore phase started ****"
    /act/custom_apps/saphana/restore/ACT_HANADB_prerestore.sh $DBSID
    retval=$?
    if [ $retval -ne 0 ]; then
       return $retval
    fi
    if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
       /act/custom_apps/saphana/restore/ACT_HANADB_pdsnapshotrestore_prerestore.sh
       retval=$?
       if [[ "$retval" -ne "0" ]]; then
          return $retval
       fi
    fi
    echo "**** Prerestore phase ended ****"
    return 0;
}

function postrestore_func()
{
    echo "**** Postresotre phase started ****"
    if [ ! -z "$RESTORE_USERSTOREKEY" ]; then
       DBUSER=$RESTORE_USERSTOREKEY
    else
       DBUSER=$SOURCE_USERSTOREKEY
    fi
    if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
       /act/custom_apps/saphana/restore/ACT_HANADB_pdsnapshotrestore_vgactivate.sh
        retval=$?
        if [[ "$retval" -ne "0" ]]; then
            return $retval
        fi
    fi
    if [ -z "$LOGMOUNTPATH" ]; then
      /act/custom_apps/saphana/restore/ACT_HANADB_postrestore.sh "$DBSID" "$DBUSER" "$HANAVERSION" "$DATAPATH"
    else
       /act/custom_apps/saphana/restore/ACT_HANADB_postrestore.sh "$DBSID" "$DBUSER" "$HANAVERSION" $DATAPATH "$RECOVERYTIME" $LOGMOUNTPATH
    fi
   retval=$?
   if [ $retval -ne 0 ]; then
       return $retval
   fi

    echo "**** Postresotre phase ended ****"
    return 0;
}

function predumprestore_func()
{
    if [ -z "$EXCLUDE_DB_LIST" ]; then
        EXCLUDE_DB_LIST="null"
    fi
    if [ -z "$INCLUDE_DB_LIST" ]; then
        INCLUDE_DB_LIST="null"
    fi

    echo "**** PreDumpRestore phase started ****"
    /act/custom_apps/saphana/dump/ACT_HANADB_predumprestore.sh $DBSID "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST"
    retval=$?
   if [ $retval -ne 0 ]; then
       echo "******* PreDumprestore ERROR: Failed  to shutdown database $DBSID ************"
       return $retval
   fi
    echo "**** PreDumprestore phase ended ****"
    return 0;

}

function postdumprestore_func()
{
    echo "**** PostDumpResotre phase started ****"

    if [ -z "$EXCLUDE_DB_LIST" ]; then
        EXCLUDE_DB_LIST="null"
    fi
    if [ -z "$INCLUDE_DB_LIST" ]; then
        INCLUDE_DB_LIST="null"
    fi
    if [ ! -z "$RESTORE_USERSTOREKEY" ]; then
       DBUSER=$RESTORE_USERSTOREKEY
    else
       DBUSER=$SOURCE_USERSTOREKEY
    fi
    USEBACKINT=`echo $USEBACKINT | tr '[A-Z]' '[a-z]'`
    if [ "$USEBACKINT" = "true" ]; then
        /act/custom_apps/saphana/dump/ACT_HANADB_dumprestore_prechecks.sh $DBSID "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" $HANABACKUPPATH
        retval=$?
       if [ $retval -ne 0 ]; then
          echo "******* Preresotre Checks ERROR: Failed pre restore checks for database $DBSID************"
          return $retval
       fi
      if [ -z "$LOGMOUNTPATH" ]; then
        /act/custom_apps/saphana/dumpbackint/ACT_HANADB_dumprestorebrint.sh $DBSID $DBPORT $DBUSER "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" "$HANAVERSION" $HANABACKUPPATH
      else
         /act/custom_apps/saphana/dumpbackint/ACT_HANADB_dumprestorebrint.sh $DBSID $DBPORT $DBUSER "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" "$HANAVERSION" $HANABACKUPPATH "$RECOVERYTIME" $LOGMOUNTPATH
      fi
       retval=$?
       if [ $retval -ne 0 ]; then
          echo "******* Postresotre ERROR: Failed  to recover database $DBSID ************"
          return $retval
       fi
    else
       /act/custom_apps/saphana/dump/ACT_HANADB_dumprestore_prechecks.sh $DBSID "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" $HANABACKUPPATH
       retval=$?
       if [ $retval -ne 0 ]; then
          echo "******* Preresotre Checks ERROR: Failed pre restore checks for database $DBSID************"
          return $retval
       fi
       if [ -z "$LOGMOUNTPATH" ]; then
          /act/custom_apps/saphana/dump/ACT_HANADB_dumprestore.sh $DBSID $DBPORT $DBUSER "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" "$HANAVERSION" $HANABACKUPPATH
       else
          /act/custom_apps/saphana/dump/ACT_HANADB_dumprestore.sh $DBSID $DBPORT $DBUSER "$EXCLUDE_DB_LIST" "$INCLUDE_DB_LIST" "$HANAVERSION" $HANABACKUPPATH "$RECOVERYTIME" $LOGMOUNTPATH
       fi
       retval=$?
       if [ $retval -ne 0 ]; then
          echo "******* Postresotre ERROR: Failed  to recover database $DBSID ************"
          return $retval
       fi
    fi
    echo "**** Postresotre phase ended ****"
    return 0;
}

function logbackup_func()
{

    echo "**** log backup started ****"
    DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
    DBADM=$DBADM'adm'
    su - $DBADM -c "export BACKUP_TYPE=$BACKUP_TYPE;/act/custom_apps/saphana/act_saphana_logbackup.sh $DBSID $DBUSER"
    retval=$?
    if [ "$retval" -gt 0 ] && [ "$retval" -ne 13 ]; then
       echo "WARNING: Please check the /var/act/log/custom_saphana.log for warning errors during logbackup"
    elif [ "$retval" -eq 13 ]; then
         return 1
    fi
    if [[ "$BACKUP_TYPE" == "PDSNAP" ]]; then
       globalpath=`su - $DBADM -c 'echo $DIR_INSTANCE'`
       globalpath=`dirname $globalpath`
       logbackup_path=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_logbackup =|basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`
       if [[ ! -z "$logbackup_path" ]]; then
          sync -f $logbackup_path
       fi
    fi
    echo "**** log backup ended ****"
    return 0;
}

function loggapcheck_func()
{
    echo "**** log gap check started ****"
    DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
    DBADM=$DBADM'adm'
    /act/custom_apps/saphana/act_saphana_logbackup_gapcheck.sh $DBSID $DBUSER
    if [ "$?" -gt 0 ]; then
       echo "WARNING: Please check the /var/act/log/custom_saphana.log for warning errors during loggap check"
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
        FILELOC="/act/touch/"
        if [ ! -d "$FILELOC" ]; then
            mkdir -p $FILELOC
            chmod 755 $FILELOC
        fi
        FILE_NAME=$FILELOC/hanabackupdblist.log
        if [ ! -f "$FILE_NAME" ]; then
           touch $FILE_NAME
           chown "$DBADM":sapsys $FILE_NAME
           chmod 755 $FILE_NAME
        else
           chown "$DBADM":sapsys $FILE_NAME
           chmod 755 $FILE_NAME
        fi
     su - $DBADM -c "/act/custom_apps/saphana/act_saphana_logdelete.sh $DBSID $DBUSER $PRETDBUSER $DBPORT $PORT $DELLOG $HANAVERSION $USESYSTEMDBKEY \"$ENDPIT\" $DELETE_LOGFILES_HOURS $LASTBACKEDUPDBNAMES $SNAPSHOT_TYPE"
     retval=$?
     if [ -f /act/touch/hanabackupdblist.log ]; then
        if [ ! -d "/act/tmpdata/$ACT_JOBNAME/" ]; then
           mkdir -p /act/tmpdata/$ACT_JOBNAME
        fi
        mv /act/touch/hanabackupdblist.log /act/tmpdata/$ACT_JOBNAME/
     fi
     if [ $retval -ne 0 ]; then
        return $retval
     fi
    return 0;
}

function pdsnappremount_func
{
  echo " ******** Starting pdsnap premount phase ***********"
  /act/custom_apps/saphana/clone/ACT_HANADB_pdsnapshotmount_premount.sh
  if [[ "$?" -ne 0 ]]; then
     return $retval
  fi
}

function pdsnapunmount_func
{
  echo " ******** Starting pdsnap unmount phase ***********"
  if [[ "$FORGETACTIVEMOUNT" == "true" ]]; then
     /act/custom_apps/saphana/clone/ACT_HANADB_pdsnapshotmount_logvgdeactivate.sh
  else
     /act/custom_apps/saphana/clone/ACT_HANADB_pdsnapshotmount_vgdeactivate.sh
  fi
  if [[ "$?" -ne 0 ]]; then
     return $retval
  fi
}

function pdsnappostmount_func
{
   echo "******Mounting the disks started ****"
   /act/custom_apps/saphana/clone/ACT_HANADB_pdsnapshotmount_vgactivate.sh
   retval=$?
   if [ $retval -ne 0 ]; then
       return $retval
   fi
   if [[ "$INTEGRITYCHECK" == "true" ]]; then
      echo "**** Data Integrity Check started ****"
      /act/custom_apps/saphana/clone/act_saphana_dataintegrity_check.sh
      retval=$?
      if [ $retval -ne 0 ]; then
     return $retval
      fi
   fi
   return 0;
}

if [ -n $ACT_PHASE ]
then
   PARAM=$ACT_PHASE

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
     predump)
         echo "Executing predump phase of the script"
         predump_func
         retval=$?
         ;;
     backintsetup)
   echo "Executing backint setup phase of the script"
         backintsetup_func
         retval=$?
         ;;
     dbdump)
         echo "Executing dbdump phase of the script"
         dbdump_func
         retval=$?
         ;;
     predumprestoretest)
         echo "Executing predumprestore test phase of the script"
         predumprestoretest_func
         retval=$?
         ;;
     prerestoretest)
         echo "Executing prerestore test phase of the script"
         prerestoretest_func
         retval=$?
         ;;
     prerestore)
         echo "Executing prerestore phase of the script"
         prerestore_func
         retval=$?
         ;;
     postrestore)
         echo "Executing postrestore phase of the script"
         postrestore_func
         retval=$?
         ;;
     predumprestore)
         echo "Executing prerestore phase of the script"
         predumprestore_func
         retval=$?
         ;;
     postdumprestore)
         echo "Executing postrestore phase of the script"
         postdumprestore_func
         retval=$?
         ;;
     premounttest)
         echo "Executing premount test phase of the script"
         premounttest_func
         retval=$?
         ;;
     premount)
         echo "Executing premount phase of the script"
         premount_func
         retval=$?
         ;;
     postunmount)
         echo "Executing post unmount phase of the script"
         postunmount_func
         retval=$?
         ;;
     postmount)
         echo "Executing postmount phase of the script"
         postmount_func
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
      pdsnappremount)
        echo "Executing pdsnappremount phase of the script"
        pdsnappremount_func
        retval=$?
         ;;
      pdsnapunmount)
        echo "Executing pdsnapunmount phase of the script"
        pdsnapunmount_func
        retval=$?
         ;;
      pdsnappostmount)
        echo "Executing data integrity phase of the script"
        pdsnappostmount_func
        retval=$?
         ;;

     *)
         usage
   esac
else
    usage
fi

exit $retval;
