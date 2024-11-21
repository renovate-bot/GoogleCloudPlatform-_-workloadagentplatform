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

set +x

#DBSID=$1
#DBUSER=$2
#HANAVERSION="$3"
#RECOVERYTIME="$4"
#LOGPATH="$5"
#DATAPATH="$6"

export DBSID
export DBUSER
export HANAVERSION
export RECOVERYTIME
export LOGPATH
export DATAPATH

rpath=$(realpath "${BASH_SOURCE:-$0}")
curr_dir=$(dirname $rpath)

source $curr_dir/act_saphana_sapcontrol_library.sh

if [ -f "$globalhanarestoredatafile" ]; then
   DEBUGMODE=`grep -i "debugmode" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ -z "$DEBUGMODE" ]; then
      DEBUGMODE="off"
   fi
else
   DEBUGMODE="off"
fi

if [ ! -z "$DEBUGMODE" ] && [ "$DEBUGMODE" = "on" ]; then
   set -x
else
   set +x
fi

shopt -s expand_aliases
if [ ! -z "$DEBUGMODE" ] && [ "$DEBUGMODE" = "on" ]; then
   set -x
else
   set +x
fi

ppid=`pstree -g -s $$ | awk -F"---" '{print $(NF-1)}' | cut -d"(" -f2 | cut -d")" -f1 | cut -d"+" -f1 | head -n1`
if [ -d "$curr_dir/$ppid" ]; then
   ppid=$ppid
else
   ppid=$((ppid + 1));
fi
sapcontrolstatefile=$curr_dir/$ppid/fake_global_data_sapcontrol.$ppid
globalhanarestoredatafile=$curr_dir/$ppid/saphana_test_data.$ppid
globalhanaarchivelogfile=$curr_dir/$ppid/saphana_test_archivelog_data.$ppid
stepsloggingfile=$curr_dir/statusstepsloggingfile

if [ -f "$globalhanarestoredatafile" ]; then
   mockswitch=`grep "mockswitch" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ -z "$mockswitch" ]; then
     mockswitch="off"
   fi
else
   mockswitch="off"
fi
export mockswitch
hanatestrecoverstatus=$curr_dir/$ppid/hana_func_test_recover_status.$ppid
faketenantdbstatus=$curr_dir/$ppid/fake_tenant_db_status.$ppid
fakebackupsnapdata=$curr_dir/$ppid/fakebackupsnapdata.$ppid

get_db_sid ()
{
   NDBSID=`grep -i "DBSID=" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $DBSID`
   if [ ! -z "$NDBSID" ]; then
      export NDBSID
   else
      return 1
   fi
}

get_dir_instance ()
{
   DIRINST=`grep -i "dirinstance=" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$DIRINST" ]; then
      export DIRINST
   fi
   APPREMOUNT=`grep -i "appremount=" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$APPREMOUNT" ]; then
      export APPREMOUNT
   fi
}

get_tinstance ()
{
   TINST=`grep -i "tinstnum=" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$TINST" ]; then
      export TINST
   fi
}

get_sslen ()
{
   sslenfor=`grep -i "sslenforce=" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$sslenfor" ]; then
      export sslenfor
   else
      sslenfor="false"
      export sslenfor
   fi
}

get_ssl_enforce_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_ssl_enforce
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         get_global_params_wrapper
         if [ $retval -eq "0" ]; then
            echo $SSLENFORCE
            export SSLENFORCE
         else
            return 1
         fi
      else
         return 1
      fi
   fi
}

check_recover_pit ()
{
   if [ "x$RECOVERYTIME" != "x" ]; then
      ipit=`grep -i "RTIME=" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i "$RECOVERYTIME"`
      if [ ! -z "$ipit" ]; then
         check_catalogpath $*
         if [ $? -ne "0" ]; then
            return 1
         fi
         if [ ! -z "$dbnames" ] && [ "x$dbnames" != "x" ]; then
            recpitcheck=`echo $* | grep -i "RECOVER DATABASE FOR " | grep -i "UNTIL TIMESTAMP " | grep -w "$ipit"`
         else
            recpitcheck=`echo $* | grep -i "RECOVER DATABASE UNTIL TIMESTAMP " | grep -w "$ipit"`
         fi
         if [ -z "$recpitcheck" ]; then
            return 1
         fi
         checkcons=`grep -iw "dbconsistencytime" $globalhanaarchivelogfile | cut -d"=" -f2 | xargs`
         hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
         if [ ! -z "$checkcons" ] && [ ! -z "$ipit" ] && [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ]; then
           if [ $(date +%s -d "$ipit") -lt $(date +%s -d "$checkcons") ]; then
               return 1
            else
               while read line
               do
                  i="$line"
                  archlogt=`echo "$i" | grep -iw "archivelogs" | cut -d";" -f3`
                  archlogn=`echo "$i" | grep -iw "archivelogs" | cut -d";" -f2`
                  if [ ! -z "$archlogt" ] && [ ! -z "$archlogn" ] && [ $(date +%s -d "$archlogt") -le $(date +%s -d "$ipit") ]; then
                     if [ -z "$archstr" ]; then
                        archstr=$archlogn","
                     else
                        archstr=$archlogn","$archstr
                     fi
                  fi
               done < $globalhanaarchivelogfile
               while read line
               do
                  i="$line"
                  archlogt=`echo "$i" | grep -iw "archivelogs" | cut -d";" -f3`
                  archlogn=`echo "$i" | grep -iw "archivelogs" | cut -d";" -f2`
                  if [ ! -z "$archlogt" ] && [ ! -z "$archlogn" ] && [ $(date +%s -d "$archlogt") -gt $(date +%s -d "$ipit") ]; then
                     archstr=$archlogn","$archstr
                     break;
                  fi
               done < $globalhanaarchivelogfile
               while read line
               do
                 j="$line"
                 lcheck=`echo "$archstr" | grep -w "$j"`
                 if [ ! -z "$lcheck" ]; then
                    return 0
                else
                   return 1
                fi
               done < $globalhanaarchivelogfile".temp"
            fi
         fi
      fi
  else
     return 0
  fi
}

check_recover_logpath ()
{
   if [ "x$LOGPATH" != "x" ]; then
      ilogpath=`grep -i "LOGPATH" $globalhanarestoredatafile | cut -f2 -d"=" | grep -w "$LOGPATH"`
      if [ ! -z "$ilogpath" ]; then
         if [ ! -z "$dbnames" ] && [ "x$dbnames" != "x" ]; then
            if [ "x$RECOVERYTIME" != "x" ]; then
               reclogcheck=`echo $* | grep -i "RECOVER DATABASE FOR " | grep -i "USING LOG PATH " | grep -w "$ilogpath"`
            else
               reclogcheck=`echo $* | grep -i "RECOVER DATA FOR " | grep -i "USING SNAPSHOT CLEAR LOG" | grep -v "$ilogpath"`
            fi
         else
           if [ "x$RECOVERYTIME" != "x" ]; then
               reclogcheck=`echo $* | grep -i "RECOVER DATABASE UNTIL TIMESTAMP " | grep -i "USING LOG PATH " | grep -w "$ilogpath"`
            else
               reclogcheck=`echo $* | grep -wi "RECOVER DATA USING SNAPSHOT CLEAR LOG" | grep -v "$ilogpath"`
            fi
         fi
         if [ ! -z "$reclogcheck" ]; then
            return 0
         else
            return 1
         fi
      fi
   else
     return 0
   fi
}

check_datapath ()
{
   idatapath=`grep -i "DATAPATH" $globalhanarestoredatafile | cut -f2 -d"=" | grep -w $DATAPATH`
   norigstring=`echo $*`
   if [ ! -z "$idatapath" ]; then
      if [ ! -z "$dbnames" ] && [ "x$dbnames" != "x" ]; then
         for i in ${dbnames}; do
            if [ $i = "DATABASE_NAME" ] || [ $TSID = "SYSTEMDB" ] || [ x"$TSID" = "x" ]; then
                  :
            else
               if [ "x$RECOVERYTIME" != "x" ]; then
                  TSID=`echo $i |awk -F '"' '{print $2}'`
                  OLDDBSID="$TSID"
                  export OLDDBSID
                  TSID=`echo $i |awk -F '"' '{print $2}'`
                  CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
                  CATALOGPATH=$CATALOGPATH"/DB_"$TSID"/"
                  set_logbkppath_wrapper $LOGPATH DB_$TSID
                  if [ -d "$CATALOGPATH" ]; then
                     CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
                     CATALOGPATH=$CATALOGPATH"/DB_"$TSID"/"
                     set_logbkppath_wrapper $LOGPATH DB_$TSID
                  else
                     CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
                     CATALOGPATH=$CATALOGPATH"/DB_"$OLDDBSID"/"
                     set_logbkppath_wrapper $LOGPATH DB_$OLDDBSID
                  fi
                  tfromstring="-U $DBUSER -a -j RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
                  torigstring=`echo $*`
                  if [[ "$torigstring" == "$tfromstring" ]]; then
                     return 0
                  else
                     return 1
                  fi
               else
                  torigstring=`echo $*`
                  tfromstring="-U $DBUSER -a -j RECOVER DATA FOR $TSID USING SNAPSHOT CLEAR LOG"
                  if [[ "$torigstring" == "$tfromstring" ]]; then
                     return 0
                  else
                     return 1
                  fi
               fi
            fi
         done
      else
        if [ "x$RECOVERYTIME" != "x" ]; then
           recdatacheck=`echo $* | grep -i "RECOVER DATABASE " | grep -i "USING DATA PATH " | grep -w "$idatapath"`
           CATALOGPATH=`echo $LOG_BKP_PATH | rev |awk -F"," '{ print $1}' |rev`
           CATALOGPATH=$CATALOGPATH"/SYSTEMDB/"
           set_logbkppath_wrapper $LOGPATH SYSTEMDB
           hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
           if [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ]; then
              fromstring="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
           else
              fromstring="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
            fi
              if [[ "$norigstring" == "$fromstring" ]]; then
                 return 0
              else
                 return 1
              fi
        else
           recdatacheck=`echo $* | grep -wi "RECOVER DATA USING SNAPSHOT CLEAR LOG" | grep -v "$idatapath"`
        fi
      fi
      if [ ! -z "$recdatacheck" ]; then
         return 0
      else
         return 1
     fi
   else
      return 1
   fi
}

check_catalogpath ()
{
   check_hana_version
   if [ $? -ne "0" ]; then
      return 1
   fi
   idatapath=`grep -i "DATAPATH" $globalhanarestoredatafile | cut -f2 -d"=" | grep -w $DATAPATH`
   if [ -z "$idatapath" ]; then
      return 1
   fi
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   if [ "x$hversion" != "x" ] && [ "$hversion" = "1.0" ]; then
      reccatcheck=`echo $* | grep -i "RECOVER DATABASE " | grep -i "USING DATA PATH " | grep -v "CATALOG"`
   else
      reccatcheck=`echo $* | grep -i "RECOVER DATA" | grep -i "USING CATALOG PATH"`
   fi
   if [ ! -z "$reccatcheck" ]; then
      return 0
   else
      return 1
   fi
}

check_hana_version ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION`
   if [ ! -z "$hversion" ]; then
      return 0
   else
      return 1
   fi
}

check_userstorekey ()
{
   huserstore=`grep -i "userstorekey" $globalhanarestoredatafile | cut -f2 -d"=" | grep -wi $DBUSER`
   if [ ! -z "$huserstore" ]; then
      hkeycheck=`echo $1 | grep -w $huserstore`
      if [ ! -z "$hkeycheck" ]; then
         return 0
      else
         return 1
     fi
   fi
}

set_tenantdblist ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep $HANAVERSION`
   if [ ! -z "$hversion" ]; then
      dblist=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
      if [ ! -z "$dblist" ]; then
        DBLIST=`echo $dblist | tr '[a-z]' '[A-Z]'`
        OIFS=$IFS
        IFS=','
        dbnamelist=$DBLIST
        dbnames=""
        for k in $dbnamelist; do
          if [ $k = "SYSTEMDB" ]; then
            tesystem=$k
          else
            if [ -z "$dbnames" ]; then
              dbnames='"'"$k"'"'
             else
               dbnames=$dbnames" "'"'"$k"'"'
              fi
           fi
         done
         IFS=$OIFS
      #echo $dbnames
      export dbnames
      return 0
      else
        return 1
      fi
   else
     return 1
   fi
}

set_alldblist ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep $HANAVERSION`
   if [ ! -z "$hversion" ]; then
      dblist=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
      if [ ! -z "$dblist" ]; then
        DBLIST=`echo $dblist | tr '[a-z]' '[A-Z]'`
        OIFS=$IFS
        IFS=','
        dbnamelist=$DBLIST
        dbnames=""
        for k in $dbnamelist; do
           if [ -z "$dbnames" ]; then
              dbnames='"'"$k"'"'
           else
               dbnames=$dbnames" "'"'"$k"'"'
           fi
        done
        IFS=$OIFS
      #echo $dbnames
      export dbnames
      return 0
      else
        return 1
      fi
   else
     return 1
   fi
}

set_exclude_db_list ()
{
   DB_LIST=$1
   dblist=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$dblist" ]; then
      DBLIST=`echo $dblist | tr '[a-z]' '[A-Z]'`
      OIFS=$IFS
      IFS=','
      dbnamelist=$DBLIST
      dbnames=""
      for k in $dbnamelist; do
         edblist1=`echo "$DB_LIST" | grep -i "$k"`
         if [ -z "$edblist1" ]; then
            if [ -z "$dbnames" ]; then
               dbnames='"'"$k"'"'
            else
               dbnames=$dbnames" "'"'"$k"'"'
            fi
         fi
      done
      IFS=$OIFS
      #echo $dbnames
      export dbnames
      return 0
      else
         return 1
    fi
}

set_include_db_list ()
{
   DB_LIST=$1
   dblist=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ ! -z "$dblist" ]; then
      DBLIST=`echo $dblist | tr '[a-z]' '[A-Z]'`
      OIFS=$IFS
      IFS=','
      dbnamelist=$DBLIST
      dbnames=""
      for k in $dbnamelist; do
         edblist2=`echo "$DB_LIST" | grep -i "$k"`
         if [ ! -z "$edblist2" ]; then

            if [ -z "$dbnames" ]; then
               dbnames='"'"$k"'"'
            else
               dbnames=$dbnames" "'"'"$k"'"'
            fi
         fi
      done
      IFS=$OIFS
      #echo $dbnames
      export dbnames
      return 0
      else
         return 1
   fi
}

set_backint_db_parfile_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      set_backint_db_parfile $*
   else
      DDBSID=$1
      BACKINT_LOC=$globalpath/SYS/global/hdb/backint
      BACKINT_CATALOG=$HANABACKUPPATH/catalog/ACTcatalog.log
      BACKINT_PAR_FILE=$curr_dir/actifio_backint.par
      BACKINT_LOG_PAR_FILE=$curr_dir/actifio_backint_log.par

      echo "export DBTYPE=$DDBSID" > $BACKINT_PAR_FILE
      echo "export DB_BACKUP_PATH=$HANABACKUPPATH" >> $BACKINT_PAR_FILE
      echo "export BS=10M" >> $BACKINT_PAR_FILE
   fi
}

set_backint_log_parfile_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      set_backint_log_parfile $*
   else
      DDBSID=$1
      LOGPATH=$2

      BACKINT_LOG_PAR_FILE=$curr_dir/actifio_backint_log.par
      if [ ! -z "$LOGPATH" ]; then
         echo "export DBTYPE=$DDBSID" > $BACKINT_LOG_PAR_FILE
         echo "export DB_BACKUP_PATH=$LOGPATH" >> $BACKINT_LOG_PAR_FILE
         echo "export BS=10M" >> $BACKINT_LOG_PAR_FILE
      else
         echo "export DB_BACKUP_PATH=$HANABACKUPPATH" > $BACKINT_LOG_PAR_FILE
         echo "export BS=10M" >> $BACKINT_LOG_PAR_FILE
      fi
   fi

}

get_backcatalog_id_wrapper ()
{
   DDBSID=$1
   if [ $mockswitch = "off" ]; then
      get_backcatalog_id $*
   else
      BACKUPID=12345
      if [ $DDBSID = "SYSTEMDB" ]; then
         INCR_COUNT=0
         DPATH=$BACKINT_LOC/SYSTEMDB/
         CATALOGPATH=$HANABACKUPPATH/SYSTEMDB
      else
         INCR_COUNT=0
         DPATH=$BACKINT_LOC/DB_"$DBSID"/
      fi
      export BACKUPID
      export INCR_COUNT
      export DPATH
      export CATALOGPATH
   fi
}

set_rtime_logcount_wrapper ()
{
  if [ $mockswitch = "off" ]; then
      set_rtime_logcount
  else
     fake_set_rtime_logcount_wrapper
     if [ "$?" -ne "0" ]; then
       return 1
     else
       return 0
     fi
  fi
}

fake_set_rtime_logcount_wrapper ()
{
  if [ ! -z "$LOGPATH" ]; then
    ilogpath=`grep -i "LOGPATH" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $LOGPATH`
    if [ ! -z "$ilogpath" ]; then
      checklogs=10
      if [ "$checklogs" -eq 0 ]; then
         RECOVERYTIME=''
         return 0
      fi
    else
       return 1
    fi
  else
    return 0
  fi
}

set_logbkppath_wrapper ()
{
  if [ $mockswitch = "off" ]; then
      set_logbkppath $*
  else
    fake_set_logbkppath $*
    if [ "$?" -ne "0" ]; then
      return 1
    else
      return 0
    fi
  fi
}

fake_set_logbkppath ()
{
  ilogpath=`grep -i "LOGPATH" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $1`
  if [ ! -z "$ilogpath" ]; then
     LOG_BKP_PATH=$1
     export LOG_BKP_PATH
     return 0
  else
     return 1
  fi

}

grep_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      grep $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         if [ $1 = "python_support" ]; then
            PYTHONPATH="/usr/sap/$NDBSID/HDB[0-9][0-9]/exe/$1"
            echo $PYTHONPATH
            export PYTHONPATH
            return 0
         fi
         if [ $1 = "sslenforce" ]; then
            get_sslenforce
            if [ ! -z "$sslenfor" ]; then
               SSLENFORCE="$sslenfor"
            else
               SSLENFORCE="false"
            fi
            echo $SSLENFORCE
            export SSLENFORCE
            return 0
         fi
         if [ $1 = "^catalog_backup_parameter_file" ]; then
            PAR_FILE=$curr_dir/actifio_backint.par
            echo $PAR_FILE
            export PAR_FILE
         fi
         if [ $1 = "^backup" ] && [ $2 = "BACKINT_CATALOG" ]; then
            BACKUPID=12345
            INCR_COUNT=0
            echo $BACKUPID
            echo $INCR_COUNT
            export BACKUPID
            export INCR_COUNT
        fi
     fi
  fi
}

id_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      id $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         GRP_DIR=sapsys
         echo $GRP_DIR
         export GRP_DIR
         set_alldblist
         for i in $dbnames
         do
         i=`echo $i  | xargs`
         if [ $i = "SYSTEMDB" ]; then
            chmod 776 $curr_dir/$i >/dev/null 2>&1
          else
            chmod 776 $curr_dir/"DB_"$i >/dev/null 2>&1
         fi
         done
         return 0
      else
         return 1
      fi
   fi
}

chown_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      chown $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

get_globalpath_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_globalpath
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         get_dir_instance
         if [ ! -z "$DIRINST" ]; then
            globalpath=$DIRINST
            export globalpath
         fi
         if [ ! -z "$globalpath" ] && [ -d $globalpath ]; then
            return 0
         else
            return 1
         fi
      else
         return 1
      fi
   fi
}

get_bkp_file_path_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_bkp_file_path
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         FILE_NAME=$curr_dir/$ppid/hanabackupdblist.log
         BACKUP_XML=$curr_dir/$ppid/backupstatus.xml
         FAIL_MSG=$curr_dir/$ppid/FAIL_MSG
         mkdir -p $FAIL_MSG
         export FAIL_MSG
         return 0
      else
         return 1
      fi
   fi
}

get_global_params_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_global_params $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         get_globalpath_wrapper
         globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
         logbackuppath=`grep -i "logbackuppath=" $globalhanarestoredatafile | tail -n1 | cut -f2 -d"="`
         if [ ! -z "$logbackuppath" ]; then
            if [ -f $globalinipath ]; then
               rm -f $globalinipath
            else
               mkdir -p $globalpath/SYS/global/hdb/custom/config
               touch $globalpath/SYS/global/hdb/custom/config/global.ini
            fi
            echo "basepath_logbackup=$logbackuppath" >> $globalinipath
            echo "basepath_catalogbackup=$logbackuppath" >> $globalinipath
            LOGBACKUPPATH=$logbackuppath
            CATALOGBACKUPPATH=$logbackuppath
            export LOGBACKUPPATH
            export CATALOGBACKUPPATH
            return 0
         else
            return 1
         fi
         get_sslen
         if [ ! -z "$sslenfor" ]; then
            echo "sslenforce=$sslenfor" >> $globalinipath
            SSLENFORCE=$sslenfor
            export SSLENFORCE
            return 0
         else
            return 1
         fi
      else
         return 1
      fi
   fi
}

getSslenforce_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      getSslenforce
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         SSLENFORCE="false"
         return 0
      else
         return 1
      fi
   fi
}

get_backup_global_params_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_backup_global_params $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         get_globalpath_wrapper
         globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
         logbackuppath=`grep -i "logbackuppath=" $globalhanarestoredatafile | cut -f2 -d"="`
         if [ ! -z "$logbackuppath" ]; then
            if [ -f $globalinipath ]; then
               rm -f $globalinipath
            else
               mkdir -p $globalpath/SYS/global/hdb/custom/config
               touch $globalpath/SYS/global/hdb/custom/config/global.ini
            fi
            echo "basepath_logbackup=$logbackuppath" >> $globalinipath
            echo "basepath_catalogbackup=$logbackuppath" >> $globalinipath
            LOGBACKUPPATH=`grep -i ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
            CATLOGBACKUPPATH=`grep -i ^basepath_catalogbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
            if [ -z "$LOGBACKUPPATH" ]; then
               return 1
            elif [ ! -z "$LOGBACKUPPATH" ]; then
                if [ -z "$CATLOGBACKUPPATH" ]; then
                   CATLOGBACKUPPATH=$LOGBACKUPPATH
                   cp $globalinipath $globalinipath'.'$DATE
                   echo -e "basepath_catalogbackup = $CATLOGBACKUPPATH" >> $globalinipath
            elif [ ! -z "$CATLOGBACKUPPATH" ]; then
                if [ "$LOGBACKUPPATH" != "$CATLOGBACKUPPATH" ]; then
                   cp $globalinipath $globalinipath'.'$DATE
                   CATLOGBACKUPPATH=$LOGBACKUPPATH
                   sed -i "/basepath_catalogbackup/d" $globalinipath
                   sed -i "/persistence/a basepath_catalogbackup = $CATLOGBACKUPPATH" $globalinipath
                fi
              fi
            fi
            export LOGBACKUPPATH
            export CATALOGBACKUPPATH
            return 0
         else
            return 1
         fi
      else
         return 1
      fi
   fi
}

get_lvm_backint_check_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_lvm_backint_check $*
   else
      get_db_sid
      retval=$?
      if [ $retval -eq "0" ]; then
         get_globalpath_wrapper
         backint_flag=`grep -i ^backint_config $globalhanarestoredatafile | cut -d"=" -f2`
         if [ ! -z "$backint_flag" ] && [ $backint_flag = "true" ]; then
            return 1
         else
            return 0
         fi
      else
         return 1
      fi
   fi
}

hdbuserstore_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      hdbuserstore $*
   else
      fake_hdbuserstore $*
      retval=$?
      if [ $retval -eq "0" ]; then
         echo $DATABASE_USER
         return 0
      else
         return 1
      fi
   fi
}

HDB_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      HDB $*
   else
      hdb_fake_wrapper $*
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

hdb_fake_wrapper ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      if [ -f $sapcontrolstatefile ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      fi
      if [ $1 = "info" ]; then
         if [ -z "$istatus" ]; then
            echo "$NDBSID:STOPPED" > $sapcontrolstatefile
         else
            return 0
         fi
      elif [ $1 = "start" ]; then
         if [ -z "$istatus" ]; then
            return 1
         else
            if [ $istatus != "STOPPED" ]; then
               return 1
            else
               echo "$NDBSID:RUNNING" > $sapcontrolstatefile
               return 0
            fi
         fi
      elif [ $1 = "stop" ]; then
         if [ -z "$istatus" ]; then
            return 1
         else
            if [ $istatus != "RUNNING" ]; then
               return 1
            else
               echo "$NDBSID:STOPPED" > $sapcontrolstatefile
               return 0
            fi
         fi
      fi
   else
      return 1
   fi
}

waitforhdbnameserver_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      waitforhdbnameserver $*
   else
      fake_waitforhdbnameserver_status $*
      retval=$?
      if [ $retval -eq "0" ]; then
         set_tenantdblist
         #echo $dbnames
         export dbnames
         #echo "SYSTEMDB Running Status: PASSED" >> $curr_dir/functional_test_summary_results_$ppid
         return 0
      else
         #echo "SYSTEMDB Running Status: FAILED" >> $curr_dir/functional_test_summary_results_$ppid
         return 1
      fi
   fi
}

fake_waitforhdbnameserver_status ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      if [ -f $sapcontrolstatefile ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      fi
      if [ -f $hanatestrecoverstatus ]; then
         tdbs=`grep "$NDBSID" $hanatestrecoverstatus | cut -f2 -d:`
         irecoverstat=`grep "$NDBSID" $hanatestrecoverstatus | grep $tdbs | cut -f3 -d:`
      fi
      if [ -z "$istatus" ] || [ -z "$irecoverstat" ]; then
         return 0
      fi
      if [ $istatus != "STOPPED" ] && [ $irecoverstat != "NOTRECOVERED" ] && [ $tdbs = "SYSTEMDB" ]; then
         return 0
      elif [ $istatus = "STOPPED" ] && [ $irecoverstat = "RECOVERED" ] && [ $tdbs = "SYSTEMDB" ]; then
         #echo "$NDBSID:RUNNING" > $sapcontrolstatefile
         return 1
      fi
   else
      return 1
   fi
}

backint_restore_catalog ()
{
   get_db_sid
   retval=$?
   if [ $retval -ne "0" ]; then
      return 1
   fi
   infile=`echo $2`
   outfile=`echo $6`
   get_globalpath_wrapper
   if [ $? -ne "0" ]; then
      return 1
   fi
   globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
   logbackuppath=`grep -i "logbackuppath=" $globalhanarestoredatafile | tail -n1 | cut -f2 -d"="`
   PAR_FILE=`cat $globalinipath | grep ^catalog_backup_parameter_file | cut -d'=' -f2-`
   if [ -z "$PAR_FILE" ]; then
      return 1
   fi
   get_backup_id_wrapper
   backintfstr="/usr/sap/$NDBSID/SYS/global/hdb/opt/hdbbackint -p $PAR_FILE -f restore -i /tmp/.input_file_cat_extract.$BACKUP_ID -o /tmp/.catalog_backup_$BACKUP_ID.out -u $NDBSID"
   backintostr="/usr/sap/$DBSIDupper/SYS/global/hdb/opt/hdbbackint $*"
   if [[ "$backintfstr" == "$backintostr"  ]]; then
      return 0
   else
      return 1
   fi
}

hdbbackint_cmd_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      /usr/sap/$DBSID/SYS/global/hdb/opt/hdbbackint $*
   else
     hdbbackint_cmd_fake $*
     retval=$?
     if [ $retval -eq "0" ]; then
        return 0
     else
        return 1
     fi
   fi
}

hdbbackint_cmd_fake ()
{
   get_db_sid
   retval=$?
   if [ $retval -ne "0" ]; then
      return 1
   fi
   echo "$NDBSID:RUNNING" > $sapcontrolstatefile
   istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
   if [ $istatus != "RUNNING" ]; then
      return 1
   fi
   get_bkp_file_path_wrapper
   catrest=`echo $4 | grep -i "restore"`
   if [ ! -z "$catrest" ]; then
      backint_restore_catalog $*
      if [ $? -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

hdbsql_cmd_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      hdbsql $*
   else
      hdbsql_sql_fake $*
      retval=$?
      if [ $retval -eq "0" ]; then
         pcheck=`echo $* | grep -i EFFECTIVE_PRIVILEGES`
         if [ ! -z "$pcheck" ]; then
            export PRIV_COUNT
         fi
         return 0
      else
         #echo "Tenant DB Recovery Status: Fail" >> $curr_dir/functional_test_summary_results_$ppid
         return 1
      fi
   fi
}

HDBSettings_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      HDBSettings.sh $1 "$2"
   else
      HDBSettings_fake_basecmd $*
      if [ $retval -eq "0" ]; then
        #echo "SYSTEMDB Recovery Status: PASSED" > $curr_dir/functional_test_summary_results_$ppid
        return 0
      else
         #echo "SYSTEMDB Recovery Status: FAILED" > $curr_dir/functional_test_summary_results_$ppid
         return 1
      fi
   fi
}

check_backint_datapath ()
{
   obintsbstr="$*"
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   if [ "x$hversion" != "x" ] && [ "$hversion" = "1.0" ] && [ "$MULTIDB" != "multidb" ]; then
      set_backint_db_parfile_wrapper $DBSID
      DPATH=$BACKINT_LOC/DB_"$DBSID"/
      set_rtime_logcount_wrapper
      if [ -z "$LOGPATH" ]; then
         if [ -z "$RECOVERYTIME" ] && [ "$INCR_COUNT" -gt "0" ]; then
            bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '9999-01-01 00:00:00' CLEAR LOG USING LOG PATH ('$DPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
         elif [ -z "$RECOVERYTIME" ]; then
              bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATA USING BACKUP_ID $BACKUPID USING DATA PATH ('$DPATH') CLEAR LOG"
         fi
      else
         if [ -z "$RECOVERYTIME" ]; then
            LGPATH=$LOGPATH/backint
            bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '9999-01-01 00:00:00' CLEAR LOG USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
         else
            LGPATH=$LOGPATH/backint
            bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
            retval=$?
         fi
      fi
      hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
  elif [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ] || [ "$MULTIDB" = "multidb" ]; then
       set_backint_db_parfile_wrapper SYSTEMDB
       if [ "$recoverSystemDbFlag" = "YES" ]; then
          DPATH=$BACKINT_LOC/SYSTEMDB/
          CATALOGPATH=$HANABACKUPPATH/SYSTEMDB
          if [ "$HANAVERSION" = "1.0" ]; then
             DPATH=$BACKINT_LOC/$DBSID
             CATALOGPATH=$BACKINT_LOC/$DBSID
          else
             DPATH=$BACKINT_LOC/SYSTEMDB/
             CATALOGPATH=$HANABACKUPPATH/SYSTEMDB
          fi
          if [ -z "$LOGPATH" ]; then
             if [ -z "$RECOVERYTIME" ]; then
                bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATA USING BACKUP_ID $BACKUPID USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DPATH') CLEAR LOG"
             fi
          else
             if [ -z "$RECOVERYTIME" ]; then
                if [ "$HANAVERSION" = "1.0" ]; then
                   LGPATH=$LOGPATH/$DBSID
                   CATALOGPATH=$LGPATH
                else
                   LGPATH=$LOGPATH/SYSTEMDB
                   CATALOGPATH=$LGPATH
                fi
                set_backint_log_parfile_wrapper SYSTEMDB $LOGPATH
                bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '9999-01-01 00:00:00' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
         else
             LGPATH=$LOGPATH/SYSTEMDB
             CATALOGPATH=$LGPATH
             set_backint_log_parfile_wrapper SYSTEMDB $LOGPATH
             bintsbstr="$PYTHONPATH/recoverSys.py --command=RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
          fi
       fi
    fi
  fi
  if [[ "$obintsbstr" == "$bintsbstr" ]]; then
     SAP_RETRIEVAL_PATH=$curr_dir
     export SAP_RETRIEVAL_PATH
     mkdir -p $curr_dir/trace
     touch $curr_dir/trace/recoverSys.trc
     JOB_FLAG=0
     #echo $JOB_FLAG
     export JOB_FLAG
     return 0
  else
     return 1
  fi
}

check_connection_wrapper ()
{
   KEY=$1
   TDBSID=$2
  # echo "***** CHECKING DB CONNECTION for $TDBSID *****"
   if [ "$DB_LIST" = "null" ]; then
      SQL="select database_name from m_databases"
   else
       SQL="select database_name from m_databases where database_name $DB_LIST"
   fi
   dbnames=`hdbsql_cmd_wrapper -U $KEY -a -j -x $SQL`
   export dbnames
   if [ "$?" -gt 0 ]; then
     # echo "ERRORMSG: Unable to connect to the database $TDBSID using $KEY!"
      exit 1
   else
       #set_alldblist
       if [ "$HANAVERSION" != "1.0" ]; then
          if [ "$TDBSID" != "SYSTEMDB" ]; then
             #echo "checking the database name from m_databases"
             dbcheck=`echo $dbnames | grep $TDBSID | grep -v SYSTEMDB`
             if [ -z $dbcheck ]; then
                #echo "ERRORMSG: Unable to connect to the database $TDBSID using $KEY!"
                exit 1
             fi
          fi
       fi
   fi
}

check_backint_tenant_backup ()
{
  check_connection_wrapper $DBUSER SYSTEMDB
  obinttestr="$*"
  hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
  if [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ]; then
     for i in ${dbnames}; do
       TSID=`echo $i |awk -F '"' '{print $2}'`
       if [ $i = "DATABASE_NAME" ]; then
          :
       elif [ $TSID = "SYSTEMDB" ]; then
          :
       else
          set_backint_db_parfile_wrapper $TSID
          if [ -z "$LOGPATH" ]; then
             if [ -z "$RECOVERYTIME" ]; then
                binttestr="-U ACTBACKUP -a -j RECOVER DATA FOR $TSID USING BACKUP_ID $BACKUPID USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DPATH') CLEAR LOG"
             fi
          else
             if [ -z "$RECOVERYTIME" ]; then
                LGPATH=$LOGPATH/DB_"$TSID"
                CATALOGPATH=$LGPATH
                set_backint_log_parfile_wrapper $TSID $LOGPATH
                binttestr="-U ACTBACKUP -a -j RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '9999-01-01 00:00:00' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
             else
                 LGPATH=$LOGPATH/DB_"$TSID"
                 CATALOGPATH=$LGPATH
                 set_backint_log_parfile_wrapper $TSID $LOGPATH
                 binttestr="-U ACTBACKUP -a -j RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING LOG PATH ('$LGPATH') USING DATA PATH ('$DPATH') USING BACKUP_ID $BACKUPID"
             fi
          fi
      fi
   done
  fi
 if [[ "$obinttestr" == "$binttestr" ]]; then
      JOB_FLAG=0
      #echo $JOB_FLAG
      export JOB_FLAG
      return 0
   else
      return 1
   fi
}

HDBSettings_fake_basecmd ()
{
   get_db_sid
   retval=$?
   if [ $retval -ne "0" ]; then
      return 1
   fi
   lvmrestc=`echo "$*" | grep -i "SNAPSHOT" | grep -v "USING BACKUP_ID"`
   if [ ! -z "$lvmrestc" ]; then
      istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      if [ $istatus != "STOPPED" ]; then
         return 1
      fi
      if [ $istatus = "STOPPED" ]; then
         echo "$NDBSID:SYSTEMDB:NOTRECOVERED" > $hanatestrecoverstatus
         check_datapath $*
         retval=$?
         if [ $retval -ne "0" ]; then
            return 1
         fi
         check_recover_logpath $*
         retval=$?
         if [ $retval -ne "0" ]; then
            return 1
         fi
         check_recover_pit $*
         retval=$?
         if [ $retval -ne "0" ]; then
            return 1
         fi
         hdbfake_recover_status
         if [ "$?" -eq "0" ]; then
            return 0
         else
            return 1
         fi
      fi
  fi
  bintrestc=`echo "$*" | grep -i "RECOVER" | grep -i "USING BACKUP_ID"`
   if [ ! -z "$bintrestc" ]; then
      process_eidblist_wrapper
      if [ $DB_LIST = "null" ] || [ $recoverSystemDbFlag = "YES" ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
         if [ $istatus != "STOPPED" ]; then
            return 1
         fi
         echo "$NDBSID:SYSTEMDB:NOTRECOVERED" > $hanatestrecoverstatus
         check_backint_datapath $*
         retval=$?
         if [ $retval -ne "0" ]; then
            return 1
         else
            return 0
         fi
      fi
   fi
}

hdbfake_recover_status ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      tdbs=`grep "$NDBSID" $hanatestrecoverstatus | cut -f2 -d:`
      irecoverstat=`grep "$NDBSID" $hanatestrecoverstatus | grep $tdbs | cut -f3 -d:`
      if [ $irecoverstat != "NOTRECOVERED" ]; then
         return 1
      else
         if [ $tdbs != "SYSTEMDB" ]; then
            echo "$NDBSID:$tdbs:RECOVERED" > $hanatestrecoverstatus
            echo "$NDBSID:$tdbs:STOPPED" >  $faketenantdbstatus"_"$tdbs
            return 0
         else
            echo "$NDBSID:$tdbs:RECOVERED" > $hanatestrecoverstatus
            echo "$NDBSID:STOPPED" >  $sapcontrolstatefile
         fi
      fi
   else
      return 1
   fi
}

hdbsql_sql_fake ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      echo "$NDBSID:RUNNING" > $sapcontrolstatefile
      istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      if [ $istatus = "RUNNING" ]; then
         pcheck=`echo $* | grep -i EFFECTIVE_PRIVILEGES`
         if [ ! -z "$pcheck" ]; then
            PRIV_COUNT=3
            echo $PRIV_COUNT
            export PRIV_COUNT
            return 0
         fi
         dblistcheck=`echo $* | grep -i m_databases | grep -v "select active_status" | grep -v "in ("`
         if [ ! -z "$dblistcheck" ]; then
            dbnames=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
            set_alldblist
            echo $dbnames
            export dbnames
            return 0
         fi
         dblistcheck1=`echo $* | grep -i m_databases | grep -v "select active_status" | grep -i "not in ("`
         if [ ! -z "$dblistcheck1" ]; then
            dbnames=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
            set_exclude_db_list "$DB_LIST"
            echo $dbnames
            export dbnames
            return 0
         fi
         dblistcheck2=`echo $* | grep -i m_databases | grep -v "select active_status" | grep -i "in (" | grep -v "not in ("`
         if [ ! -z "$dblistcheck2" ]; then
            dbnames=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
            set_include_db_list "$DB_LIST"
            echo $dbnames
            export dbnames
            return 0
         fi
         dbtenantstatus=`echo $* | grep -i m_databases | grep -i "select active_status"`
         if [ ! -z "$dbtenantstatus" ]; then
            istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
            if [ $istatus = "RUNNING" ]; then
               TDBSTATUS='"YES"'
               echo $TDBSTATUS
               export TDBSTATUS
               return 0
            fi
         fi
         dbtenantdestpath=`echo $* | grep -i "SELECT TOP 1 DESTINATION_PATH"`
         if [ ! -z "$dbtenantdestpath" ]; then
            logbackuppath=`grep -i "logbackuppath=" $globalhanarestoredatafile | tail -n1 | cut -f2 -d"="`
            if [ ! -z "$logbackuppath" ]; then
               BCATALOG="$logbackuppath"
               echo $BCATALOG
               export BCATALOG
               return 0
            fi
         fi
         dbintdestpath=`echo $* | grep -i "SELECT DESTINATION_PATH"`
         if [ ! -z "$dbintdestpath" ]; then
            logbackuppath=`grep -i "logbackuppath=" $globalhanarestoredatafile | tail -n1 | cut -f2 -d"="`
            if [ ! -z "$logbackuppath" ]; then
               SQL_DEST_EBID="$logbackuppath"
               echo $SQL_DEST_EBID
               export SQL_DEST_EBID
               return 0
            fi
         fi
         bcheck=`echo $* | grep -i "BACKUP DATA" | grep -v "USING FILE" | grep -v "USING BACKINT"`
         if [ -z "$bcheck" ]; then
            bcheck=`echo $* | grep -i "BACKUP DATA" | grep -v "USING FILE" | grep -v "USING BACKINT"`
         fi
         if [ ! -z "$bcheck" ]; then
            check_hdbsql_backup $*
            retval=$?
            if [ $retval -eq "0" ]; then
               return 0
            else
               return 1
            fi
         fi
         bducheck=`echo $* | grep -i "BACKUP DATA" | grep -i "USING FILE"`
         if [ -z "$bducheck" ]; then
            bducheck=`echo $* | grep -i "BACKUP DATA" | grep -i "USING FILE"`
         fi
         if [ ! -z "$bducheck" ]; then
            check_hdbsql_dump_backup $*
            retval=$?
            if [ $retval -eq "0" ]; then
               return 0
            else
               return 1
            fi
         fi
         bidcheck=`echo $* | grep -i "SELECT BACKUP_ID"`
         if [ ! -z "$bidcheck" ]; then
            get_backup_id_wrapper $*
            retval=$?
            if [ $retval -eq "0" ]; then
               echo $ID
               export ID
               return 0
            else
               return 1
            fi
         fi
         dbidcheck=`echo $* | grep -i "BACKUP_ID" | grep -i "BACKUPID:"`
         if [ ! -z "$dbidcheck" ]; then
            get_dump_backup_id_wrapper $*
            retval=$?
            if [ $retval -eq "0" ]; then
               echo $ID
               export ID
               echo $BACKUP_ID
               export BACKUP_ID
               return 0
            else
               return 1
            fi
         fi
         dbindcheck=`echo $* | grep -i "select top 1 T1.BACKUP_ID"`
         if [ ! -z "$dbindcheck" ]; then
            get_dump_backup_id_wrapper $*
            retval=$?
            if [ $retval -eq "0" ]; then
               echo $ID
               export ID
               echo $BACKUP_ID
               export BACKUP_ID
               return 0
            else
               return 1
            fi
         fi
         bintdu=`echo "$*" | grep -i "USING BACKINT"`
         if [ ! -z "$bintdu" ]; then
            check_backint_dump_backup $*
            if [ $? -eq "0" ]; then
               return 0
            else
               return 1
            fi
         fi
         bischeck=`echo "$*" | grep -i "RECOVER" | grep -i "USING BACKUP_ID"`
         if [ ! -z "$bischeck" ]; then
            set_alldblist
            check_backint_tenant_backup "$*"
            if [ $? -eq "0" ]; then
               return 0
            else
               return 1
            fi
         fi
         scheck=`echo $* | grep -i "RECOVER" | grep -v "USING BACKUP_ID"`
         i="$8"
         if [ -z "$scheck" ]; then
            scheck=`echo $* | grep -i "RECOVER" | grep -v "USING BACKUP_ID"`
            i="$15"
         fi

         if [ ! -z "$scheck" ]; then
            #tdbname=`echo $i | awk -F" " '{print $4}' |xargs`
            tdbname=`echo $i`
            dbnamecheck=`echo $dbnames | grep -wi $tdbname`
            if [ ! -z "$tdbname" ] && [ x"$tdbname" != "x" ] && [ ! -z "$dbnamecheck" ]; then
               check_datapath $*
               retval1=$?
               check_recover_logpath $*
               retval=$?
               if [ $retval -eq "0" ] && [ $retval1 -eq "0" ]; then
                  check_recover_pit $*
                  retval=$?
                  if [ $retval -eq "0" ]; then
                     echo "$NDBSID:$tdbname:NOTRECOVERED" > $hanatestrecoverstatus
                     echo "$NDBSID:$tdbname:STOPPED" > $faketenantdbstatus"_"$tdbname
                     hdbfake_recover_status
                     if [ "$?" -eq "0" ]; then
                       #echo "Tenant DB $tdbname Recovery Status: PASSED" >> $curr_dir/functional_test_summary_results_$ppid
                       return 0
                     else
                       #echo "Tenant DB $tdbname Recovery Status: FAILED" >> $curr_dir/functional_test_summary_results_$ppid
                        return 1
                     fi
                  else
                     #echo "Tenant DB $tdbname Recovery Status: FAILED" >> $curr_dir/functional_test_summary_results_$ppid
                     return 1
                  fi
               else
                  #echo "Tenant DB $tdbname Recovery Status: FAILED" >> $curr_dir/functional_test_summary_results_$ppid
                  return 1
               fi
            fi
         else
            scheck=`echo $7 | grep -i "STOP"`
            i="$9"
            if [ -z "$scheck" ]; then
               scheck=`echo $14 | grep -i "STOP"`
               i="$16"
            fi
            if [ ! -z "$scheck" ]; then
               #tdbname=`echo $i | awk -F" " '{print $5}' |xargs`
               tdbname=`echo $i`
               dbnamecheck=`echo $dbnames | grep -wi $tdbname`
               if [ ! -z "$tdbname" ] && [ x"$tdbname" != "x" ] && [ ! -z "$dbnamecheck" ]; then
                  fake_tenantdb_status stop $tdbname
                  if [ $? -eq "0" ]; then
                     return 0
                  else
                     return 1
                  fi
               fi
            else
               scheck=`echo $7 | grep -i "START"`
               i="$9"
               if [ -z "$scheck" ]; then
                  scheck=`echo $14 | grep -i "STOP"`
                  i="$16"
               fi
               if [ ! -z "$scheck" ]; then
                  #tdbname=`echo $i | awk -F" " '{print $5}' |xargs`
                  tdbname=`echo $i`
                  dbnamecheck=`echo $dbnames | grep -wi $tdbname`
                  if [ ! -z "$tdbname" ] && [ x"$tdbname" != "x" ] && [ ! -z "$dbnamecheck" ]; then
                     fake_tenantdb_status start $tdbname
                     if [ "$?" -eq "0" ]; then
                        #echo "Tenant DB $tdbname Running Status: PASSED" >> $curr_dir/functional_test_summary_results_$ppid
                        return 0
                     else
                        #echo "Tenant DB $tdbname Running Status: FAILED" >> $curr_dir/functional_test_summary_results_$ppid
                        return 1
                     fi
                  fi
               fi
            fi
         fi
      else
         echo "Tenant DB $tdbname Running Status: Fail" >> $curr_dir/functional_test_summary_results_$ppid
         return 1
      fi
   else
      #echo "Tenant DB $tdbname Running Status: Fail" >> $curr_dir/functional_test_summary_results_$ppid
      return 1
   fi
}

get_hana_vol_details_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_hana_vol_details
   else
      get_db_sid
      retval=$?
      if [ $retval -ne "0" ]; then
         return 1
      fi
      dbspathcheck=`echo $* | grep -i m_volumes`
      if [ ! -z "$dbspathcheck" ]; then
         dbnames=`grep -i "dbnames" $globalhanarestoredatafile | cut -f2 -d"="`
         CONFIG_FILEPATH=/tmp/Job_123456
         for tsid in ${dbnames}; do
            tsid=`echo $tsid | sed s'/"//g'`
            FILEPATH=/hana/data/mnt00001/$tsid
            echo "$tsid=$FILEPATH" >> $CONFIG_FILEPATH/HANA.manifest
            return 0
         done
      fi
   fi
}

fake_tenantdb_status ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
       if [ ! -f $faketenantdbstatus"_"$2 ]; then
          echo "$NDBSID:$2:STOPPED" > $faketenantdbstatus"_"$2
       fi
       itenantstat=`grep "$NDBSID" $faketenantdbstatus"_"$2 | cut -f3 -d:`
       if [ $1 = "stop" ]; then
          if [ $itenantstat = "STOPPED" ]; then
             return 0
          else
              echo "$NDBSID:$2:STOPPED" > $faketenantdbstatus"_"$2
              return 0
          fi
        elif [ $1 = "start" ]; then
           if [ $itenantstat = "RUNNING" ]; then
              return 1
           else
              echo "$NDBSID:$2:RUNNING" > $faketenantdbstatus"_"$2
              return 0
           fi
       fi
   else
      return 1
   fi
}

copy_ssfs_backup_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      copy_ssfs_backup
   else
      get_db_sid
      retval=$?
      if [ $retval -ne "0" ]; then
         exit 1
      fi
      return 0
   fi
}

get_database_configuration_wrapper()
{
   if [ $mockswitch = "off" ]; then
      get_database_configuration $*
   else
      get_db_sid
      retval=$?
      if [ $retval -ne "0" ]; then
         exit 1
      fi
      return 0
   fi
}

get_backup_id_wrapper ()
{
   get_db_sid
   retval=$?
   if [ $retval -ne "0" ]; then
      exit 1
   fi
      entrytypename=`grep -i "entry_type_name" $fakebackupsnapdata | grep -i $NDBSID | cut -d: -f3`
      preparedstate=`grep -i "state_name" $fakebackupsnapdata | grep -i $NDBSID | cut -d: -f3`
      if [ ! -z "$entrytypename" ] && [ "$entrytypename"="data snapshot" ] && [ ! -z "$preparedstate" ] && [ "$preparedstate"="prepared" ]; then
          ID=123456
      else
          ID=""
      fi
      if [ -z "$ID" ]; then
         return 1
      else
         export ID
         return 0
      fi
}

get_dump_backup_id_wrapper ()
{
   get_db_sid
   retval=$?
   if [ $retval -ne "0" ]; then
      exit 1
   fi
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   if [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ] && [ "$USESYSTEMDBKEY" = "true" ]; then
      bacid_ch=`echo $* | grep -i "SYS_DATABASES."`
      if [ ! -z "$bacid_ch" ]; then
         ID=123456
         BACKUP_ID=123456
      fi
   else
      bacid_ch1=`echo $* | grep -v "SYS_DATABASES"`
      if [ ! -z "$bacid_ch1" ]; then
         ID=123456
         BACKUP_ID=123456
      fi
      if [ -z "$BACKUP_ID" ]; then
         return 1
      else
         export ID
         export BACKUP_ID
         return 0
      fi
   fi
}

check_hdbsql_backup ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
     check_backup_cmd $*
     if [ $? -eq "0" ]; then
      snpcheck=`echo "$*" | grep -i "create snapshot"`
      if [ ! -z "$snpcheck" ]; then
         if [ ! -z "$fakebackupsnapdata" ] && [ -f $fakebackupsnapdata ]; then
            rm -f $fakebackupsnapdata
         fi
         echo "$NDBSID:entry_type_name:data snapshot" >> $fakebackupsnapdata
         echo "$NDBSID:state_name:prepared" >> $fakebackupsnapdata
         echo "$NDBSID:snapshot is in progress" >> $fakebackupsnapdata
      fi
      #get_backup_id_wrapper $*
      #if [ $? -ne "0" ]; then
      #   sed -i '/entry_type_name/d' $fakebackupsnapdata
      #   sed -i '/state_name/d' $fakebackupsnapdata
      #   echo "$NDBSID:snapshot is failed" >> $fakebackupsnapdata
      #   return 1
      #fi
      snpccheck=`echo "$*" | grep -i "close snapshot"`
      if [ ! -z "$snpccheck" ]; then
         get_backup_id_wrapper $*
         if [ $? -eq "0" ] && [ ! -z "$ID" ] && [ "x$ID" != "x" ]; then
            sed -i '/entry_type_name/d' $fakebackupsnapdata
            sed -i '/state_name/d' $fakebackupsnapdata
            sed -i '/snapshot is in progress/d' $fakebackupsnapdata
            echo "$NDBSID:snapshot is succesfully completed" >> $fakebackupsnapdata
            return 0
         else
            sed -i '/entry_type_name/d' $fakebackupsnapdata
            sed -i '/state_name/d' $fakebackupsnapdata
            echo "$NDBSID:snapshot is failed" >> $fakebackupsnapdata
            return 1
         fi
      fi
     else
        return 1
     fi
   else
    return 1
   fi
   #check_backup_comment
}

check_hdbsql_dump_backup ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
     check_dump_backup_cmd $*
     if [ $? -eq "0" ]; then
        dumpcheck=`echo "$*" | grep -i "BACKUP DATA USING FILE"`
      if [ ! -z "$dumpcheck" ]; then
         return 0
      else
         return 1
      fi
    else
      return 1
    fi
  else
    return 1
  fi
}

check_backint_dump_backup ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
     check_backint_backup_cmd "$*"
     if [ $? -eq "0" ]; then
        bintcheck=`echo "$*" | grep -i "USING BACKINT"`
      if [ ! -z "$bintcheck" ]; then
         return 0
      else
         return 1
      fi
     else
        return 1
     fi
   else
    return 1
   fi
}

check_backup_cmd ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   tborigstr=`echo $*`
   snpccheck=`echo "$*" | grep -i "close snapshot"`
   if [ ! -z "$snpccheck" ]; then
      if [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ]; then
         bformstr="-U $DBUSER -a -j BACKUP DATA FOR FULL SYSTEM CLOSE SNAPSHOT BACKUP_ID $ID SUCCESSFUL 'ActBackup'"
      else
         bformstr="-U $DBUSER -a -j BACKUP DATA CLOSE SNAPSHOT BACKUP_ID $ID SUCCESSFUL 'ActBackup'"
      fi
      if [[ "$tborigstr" == "$bformstr" ]]; then
         return 0
      else
         return 1
      fi
   fi
   snpccheck=`echo "$*" | grep -i "create snapshot"`
   if [ ! -z "$snpccheck" ]; then
      if [ "x$hversion" != "x" ] && [ "$hversion" != "1.0" ]; then
         NDBSID=`echo $NDBSID | xargs`
         HCMT="ACT_"$NDBSID"_SNAP"
         bformstr="-U $DBUSER -j BACKUP DATA FOR FULL SYSTEM CREATE SNAPSHOT COMMENT '$HCMT'"
      else
         bformstr="-U $DBUSER -j BACKUP DATA CREATE SNAPSHOT COMMENT '$HCMT'"
      fi
      if [[ "$tborigstr" == "$bformstr" ]]; then
         return 0
      else
         return 1
      fi
   fi

}

get_dump_backup_types_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      get_dump_backup_types $*
   else
      get_bkp_file_path_wrapper
      if [ "$DUMPSCHEDULE" = "F" ]; then
         TYPE="F"
      elif [ "$PREVDBFULLDUMPSAMEDAY" = "TRUE" ]; then
         TYPE="I"
      else
         TYPE=${DUMPSCHEDULE:`date +%w`:1}
      fi
      set_alldblist
      export dbnames
      if [ -z "$dbnames" ]; then
         echo "ERRORMSG: Failed to get database names. Please check the Userstorekey!"
         return 1
      elif [ "$retval" -ne "0" ]; then
         echo "ERRORMSG: Failed to get database names. Please check the Userstorekey!"
         return 1
      fi

     echo "<tenants>" >> $BACKUP_XML
  fi
}

get_dump_backup_cmd_wrapper ()
{
    if [ $mockswitch = "off" ]; then
       get_dump_backup_cmd $*
    else
       get_dump_backup_types_wrapper $*
       if [ $? -gt "0" ]; then
          return 1
       fi

    case $TYPE in
    I)
        HANABACKUPPATHTDB=$HANABACKUPPATH/$TSID/INCR_DATA_BACKUP
        if [ $TSID = "SYSTEMDB" ]; then
           BACKUPSQL="BACKUP DATA INCREMENTAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
        else
            if [ "$USESYSTEMDBKEY" = "true" ]; then
               if [ "$HANAVERSION" = "1.0" ] && [ "$MULTIDB" != "multidb" ]; then
                  BACKUPSQL="BACKUP DATA INCREMENTAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
               else
                  BACKUPSQL="BACKUP DATA INCREMENTAL FOR $TSID USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
               fi
            else
               BACKUPSQL="BACKUP DATA INCREMENTAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
            fi
        fi
      ;;
    D)
        HANABACKUPPATHTDB=$HANABACKUPPATH/$TSID/DIFF_DATA_BACKUP
        if [ $TSID = "SYSTEMDB" ]; then
           BACKUPSQL="BACKUP DATA DIFFERENTIAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
        else
           if [ "$USESYSTEMDBKEY" = "true" ]; then
              if [ "$HANAVERSION" = "1.0" ] && [ "$MULTIDB" != "multidb" ]; then
                 BACKUPSQL="BACKUP DATA DIFFERENTIAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
              else
                 BACKUPSQL="BACKUP DATA DIFFERENTIAL FOR $TSID USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
              fi
           else
               BACKUPSQL="BACKUP DATA DIFFERENTIAL USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
           fi
        fi
      ;;
      F)
       if [ ! -z $HANABACKUPPATH/$TSID ]; then
           mkdir -p $HANABACKUPPATH/$TSID
       fi
       if [ $TSID = "SYSTEMDB" ]; then
          HANABACKUPPATHTDB=$HANABACKUPPATH/$TSID/COMPLETE_DATA_BACKUP
          BACKUPSQL="BACKUP DATA USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
       else
           HANABACKUPPATHTDB=$HANABACKUPPATH/$TSID/COMPLETE_DATA_BACKUP
           if [ "$USESYSTEMDBKEY" = "true" ]; then
               if [ "$HANAVERSION" = "1.0" ] && [ "$MULTIDB" != "multidb" ]; then
                  BACKUPSQL="BACKUP DATA USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
               else
                  BACKUPSQL="BACKUP DATA FOR $TSID USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
               fi
           else
               BACKUPSQL="BACKUP DATA USING FILE ('$HANABACKUPPATHTDB') $COMMENT"
           fi
      fi
      ;;
    esac
  fi
}

check_dump_backup_cmd ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   get_globalpath_wrapper
   if [ $? -ne "0" ]; then
      return 1
   fi
   if [ "$HANAVERSION" = "1.0" ]; then
      COMMENT=
      MULTIDB=`grep "mode" $globalpath/SYS/global/hdb/custom/config/global.ini | grep -iw multidb |awk -F"=" '{print $2}'`
      MULTIDB=`echo $MULTIDB | tr '[A-Z]' '[a-z]'|xargs`
   else
      COMMENT="COMMENT 'ACTIFIO_DUMP_BACKUP'"
   fi
   if [ ! -z "$dbnames" ] && [ "x$dbnames" != "x" ]; then
      get_dump_backup_cmd_wrapper $TSID $MULTIDB $COMMENT
      if [ $? -ne "0" ] || [ -z "$BACKUPSQL" ]; then
         return 1
      fi
   fi
}

get_backint_backup_cmd_wrapper ()
{
  TSID=$1
  if [ $mockswitch = "off" ]; then
     get_backint_backup_cmd $TSID
  else
     get_dump_backup_types_wrapper $*
     if [ $? -gt "0" ]; then
        return 1
     fi
     if [ $TSID = "SYSTEMDB" ]; then
          DBTYPE='SYSTEMDB'
          echo "export DBTYPE=$DBTYPE" > $curr_dir/actifio_backint.par
          HBACKUPPATH="DB_BACKUP_PATH="$HANABACKUPPATH
          echo "export $HBACKUPPATH" >> $curr_dir/actifio_backint.par
          echo "export BS=10M" >> $curr_dir/actifio_backint.par
          if [ "$NODECOUNT" -gt 1 ]; then
             scp_files_wrapper
          fi
    else
          DBTYPE=DB_"$TSID"
          echo "export DBTYPE=$DBTYPE" > $curr_dir/actifio_backint.par
          HBACKUPPATH="DB_BACKUP_PATH="$HANABACKUPPATH
          echo "export $HBACKUPPATH" >> $curr_dir/actifio_backint.par
          echo "export BS=10M" >> $curr_dir/actifio_backint.par
          if [ "$NODECOUNT" -gt 1 ]; then
             scp_files_wrapper
          fi
    fi
    if [ -d "$HANABACKUPPATH/$DBTYPE" ]; then
              CHECK_FULL_BKP=`ls $HANABACKUPPATH/$DBTYPE |grep -i "COMPLETE" | wc -l`
                if [ "$CHECK_FULL_BKP" -eq "0" ]; then
                   TYPE="F"
                   if [ "$ORIG_TYPE" != "$TYPE" ]; then
                      echo "WARNINGMSG: Performing Full backup as previous Full backup is not found for $TSID!"
                   fi
                fi
          else
              TYPE="F"
          fi
    case $TYPE in
    I)
        HANABACKUPPATHTDB=$BACKINTPATH/$DBTYPE/INCR_DATA_BACKUP
        echo "export BACKUPTYPE=INCREMENTAL" >> $curr_dir/actifio_backint.par
        if [ "$NODECOUNT" -gt 1 ]; then
           scp_files_wrapper
        fi
        if [ $TSID = "SYSTEMDB" ]; then
           BACKUPSQL="BACKUP DATA INCREMENTAL USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
        elif [ "$HANAVERSION" = "1.0" ]; then
             BACKUPSQL="BACKUP DATA INCREMENTAL USING BACKINT ('$HANABACKUPPATHTDB')"
        else
            if [ "$USESYSTEMDBKEY" = "true" ]; then
               BACKUPSQL="BACKUP DATA INCREMENTAL FOR $TSID USING BACKINT ('$HANABACKUPPATHTD') COMMENT 'ACTIFIO_DUMP_BACKUP'"
            else
               BACKUPSQL="BACKUP DATA INCREMENTAL USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
            fi
        fi
      ;;
      D)
        HANABACKUPPATHTDB=$BACKINTPATH/$DBTYPE/DIFF_DATA_BACKUP
        echo "export BACKUPTYPE=DIFFERENTIAL" >> $curr_dir/actifio_backint.par
          if [ "$NODECOUNT" -gt 1 ]; then
             scp_files_wrapper
          fi
        if [ $TSID = "SYSTEMDB" ]; then
           BACKUPSQL="BACKUP DATA DIFFERENTIAL USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
        elif [ "$HANAVERSION" = "1.0" ]; then
             BACKUPSQL="BACKUP DATA DIFFERENTIAL USING BACKINT ('$HANABACKUPPATHTDB')"
        else
           if [ "$USESYSTEMDBKEY" = "true" ]; then
              BACKUPSQL="BACKUP DATA FOR $TSID DIFFERENTIAL USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
           else
               BACKUPSQL="BACKUP DATA DIFFERENTIAL USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
           fi
        fi
      ;;
      F)
       if [ ! -z $HANABACKUPPATH/$DBTYPE ]; then
           mkdir -p $HANABACKUPPATH/$DBTYPE
       fi
       if [ $TSID = "SYSTEMDB" ]; then
          HANABACKUPPATHTDB=$BACKINTPATH/$DBTYPE/COMPLETE_DATA_BACKUP
       echo "export BACKUPTYPE=COMPLETE" >> $curr_dir/actifio_backint.par
        if [ "$NODECOUNT" -gt 1 ]; then
           scp_files_wrapper
        fi

          BACKUPSQL="BACKUP DATA USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
       elif [ "$HANAVERSION" = "1.0" ]; then
            HANABACKUPPATHTDB=$BACKINTPATH/$DBTYPE/COMPLETE_DATA_BACKUP
       echo "export BACKUPTYPE=COMPLETE" >> $curr_dir/actifio_backint.par
        if [ "$NODECOUNT" -gt 1 ]; then
           scp_files_wrapper
        fi

            BACKUPSQL="BACKUP DATA USING BACKINT ('$HANABACKUPPATHTDB')"
       else
           HANABACKUPPATHTDB=$BACKINTPATH/$DBTYPE/COMPLETE_DATA_BACKUP
       echo "export BACKUPTYPE=COMPLETE" >> $curr_dir/actifio_backint.par
        if [ "$NODECOUNT" -gt 1 ]; then
           scp_files_wrapper
        fi
       if [ "$USESYSTEMDBKEY" = "true" ]; then
               BACKUPSQL="BACKUP DATA FOR $TSID USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
           else
               BACKUPSQL="BACKUP DATA USING BACKINT ('$HANABACKUPPATHTDB') COMMENT 'ACTIFIO_DUMP_BACKUP'"
           fi
      fi
      ;;
    esac
  fi
}

check_backint_backup_cmd ()
{
   hversion=`grep -i "VERSION" $globalhanarestoredatafile | cut -f2 -d"=" | grep -i $HANAVERSION | xargs`
   get_globalpath_wrapper
   if [ $? -ne "0" ]; then
      return 1
   fi
   if [ ! -z "$dbnames" ] && [ "x$dbnames" != "x" ]; then
      get_backint_backup_cmd_wrapper $TSID
      if [ $? -ne "0" ] || [ -z "$BACKUPSQL" ]; then
         return 1
      fi
      bintostr="$*"
      bintfstr="-U ACTBACKUP -a -j $BACKUPSQL"
      if [[  "$bintostr" == "$bintfstr" ]]; then
          return 0
      else
         return 1
      fi
   fi
}


parallel_dump_backup_status_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      parallel_dump_backup_status
   else
      return 0
   fi
}

recover_lvm_tenantdb_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      recover_lvm_tenantdb
   else
      set_tenantdblist
      export dbnames
      OLDDBSID=`echo $dbnames |awk -F '"' '{print $2}'`
      export OLDDBSID
      recover_lvm_tenantdb
      if [ $? -gt "0" ]; then
         return 1
      else
         return 0
      fi
   fi
}

backint_node_details_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      backint_node_details
  else
     get_globalpath_wrapper
     if [ $? -ne "0" ]; then
        return 1
     fi
     if [ ! -f "$globalpath/SYS/global/hdb/custom/config/nameserver.ini" ]; then
        touch $globalpath/SYS/global/hdb/custom/config/nameserver.ini
     fi

     globalinipath=$globalpath/SYS/global/hdb/custom/config/global.ini
     NODECOUNT=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep roles_ | wc -l`
     MASTERNODE=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep -E "active_master =|active_master=" |awk -F"=" '{print $2}' |awk -F":" '{print $1}' |xargs`
     OTHERNODES=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep roles_ | cut -d'=' -f-1 | cut -c7- |grep -v "$MASTERNODE" |xargs`

     USESYSTEMDBKEY=`echo $USESYSTEMDBKEY | tr '[A-Z]' '[a-z]'`

     localhostname=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`

     if [ ! -d $HANABACKUPPATH/catalog ]; then
        mkdir -p $HANABACKUPPATH/catalog
     fi
     if [ ! -d $HANABACKUPPATH/INI ]; then
        mkdir -p $HANABACKUPPATH/INI
     fi

     cp $globalpath/SYS/global/hdb/custom/config/global.ini $HANABACKUPPATH/INI/global.ini__"$localhostname"
     cp $globalpath/SYS/global/hdb/custom/config/nameserver.ini $HANABACKUPPATH/INI/nameserver.ini__"$localhostname"

     BACKINTPATH="$globalpath"/SYS/global/hdb/backint
     LOGBACKUPPATH=`grep -iw ^basepath_logbackup $globalinipath | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`
     LGBACKUPPATH="DB_BACKUP_PATH="$LOGBACKUPPATH
     echo "export $LGBACKUPPATH" > $curr_dir/actifio_backint_log.par
     echo "export BS=10M" >> $curr_dir/actifio_backint_log.par
   fi
}

get_backint_rest_node_details_wrapper ()
{

  if [ $mockswitch = "off" ]; then
     get_backint_rest_node_details
  else
     get_globalpath_wrapper
     if [ $? -ne "0" ]; then
        return 1
     fi
     if [ ! -f "$globalpath/SYS/global/hdb/custom/config/nameserver.ini" ]; then
        touch $globalpath/SYS/global/hdb/custom/config/nameserver.ini
     fi

     NODECOUNT=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep roles_ | wc -l`
     MASTERNODE=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep -E "active_master =|active_master=" |awk -F"=" '{print $2}' |awk -F":" '{print $1}' |xargs`
     OTHERNODES=`cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini | grep roles_ | cut -d'=' -f-1 | cut -c7- |grep -v "$MASTERNODE" |xargs`

     MULTIDB=`grep -w "mode" $globalpath/SYS/global/hdb/custom/config/global.ini |grep -iw multidb |awk -F"=" '{print $2}'`
     MULTIDB=`echo $MULTIDB | tr '[A-Z]' '[a-z]' |xargs`
  fi
}

process_eidblist_wrapper ()
{

  if [ $mockswitch = "off" ]; then
     process_eidblist
  else
     recoverSystemDBEX=`echo $EXCLUDE_DB_LIST | grep -i SYSTEMDB |wc -l`
     recoverSystemDBIN=`echo $INCLUDE_DB_LIST | grep -i SYSTEMDB |wc -l`
     if [ $recoverSystemDBEX -gt 0 ]; then
        recoverSystemDbFlag="NO"
     elif [ $recoverSystemDBIN -gt 0 ]; then
         recoverSystemDbFlag="YES"
     elif [ "$EXCLUDE_DB_LIST" = "null" ] && [ "$INCLUDE_DB_LIST" = "null" ]; then
          recoverSystemDbFlag="YES"
     elif [ "$EXCLUDE_DB_LIST" != "null" ] && [ "$INCLUDE_DB_LIST" = "null" ]; then
        if [ $recoverSystemDBEX -eq 0 ]; then
           recoverSystemDbFlag="YES"
        fi
     fi
     if [ ! -z "$EXCLUDE_DB_LIST" ] && [ "$EXCLUDE_DB_LIST" != "null" ]; then
        DB_LIST=`echo $EXCLUDE_DB_LIST | tr '[a-z]' '[A-Z]'`
        DB_LIST=`echo $DB_LIST | sed -e "s/^/'/" -e "s/\$/'/" -e "s/,/',\'/g"`
        DB_LIST='not in ('"$DB_LIST"')'
    elif [ ! -z "$INCLUDE_DB_LIST" ] && [ "$INCLUDE_DB_LIST" != "null" ]; then
       DB_LIST=`echo $INCLUDE_DB_LIST | tr '[a-z]' '[A-Z]'`
       DB_LIST=`echo $DB_LIST | sed -e "s/^/'/" -e "s/\$/'/" -e "s/,/',\'/g"`
       DB_LIST=' in ('"$DB_LIST"')'
    else
       DB_LIST="null"
    fi
  fi
  export recoverSystemDbFlag
  export DB_LIST
}

scp_files_wrapper ()
{
  if [ $mockswitch = "off" ]; then
     scp_files
  else
     BACKINT_LOG_PAR_FILE=$curr_dir/actifio_backint_log.par
     BACKINT_PAR_FILE=$curr_dir/actifio_backint.par
     for nodename in $(echo $OTHERNODES); do
        scp -pr $BACKINT_PAR_FILE $nodename:$BACKINT_PAR_FILE
        scp -pr $BACKINT_LOG_PAR_FILE $nodename:$BACKINT_LOG_PAR_FILE
        if [ "$?" -gt "0" ]; then
           return 1
        fi
    done
  fi
}

fake_hdbuserstore ()
{
   if [ $1 = "list" ]; then
      idbuser=`grep -i "userstorekey" $globalhanarestoredatafile | cut -f2 -d= | grep $DBUSER`
      DATABASE_USER="USER:$idbuser"
      export DATABASE_USER
      return 0
   fi
}

ln_wrapper ()
{
   if [ $mockswitch = "on" ]; then
      ln $*
   else
      return 0
   fi
}

steps_logging ()
{
   if [ $mockswitch = "on" ]; then
      echo "$*" >> $stepsloggingfile
   fi
}
