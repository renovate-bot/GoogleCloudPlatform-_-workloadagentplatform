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

DATE=`date`
#echo "$DATE"

DBSID=$1
OLDDBSID=$2
DBUSER=$3
HANAVERSION=$4
APPREMOUNT=$5
DATAPATH="$6"
LOGPATH="$7"
RECOVERYTIME="$8"

dbsid=$DBSID
#echo "tstamp:$RECOVERYTIME"

rpath=$(realpath "${BASH_SOURCE:-$0}")
currdir1=$(dirname $rpath)
currdir=$(dirname $currdir1)
source $currdir/act_saphana_comm_func.sh
source $currdir/act_saphana_wrapper_library.sh

get_pythonpath ()
{
   x=`grep_wrapper python_support $HOME/.sapenv.sh`
   x=`echo $x | awk -F"=" '{print $NF}' | awk '{print $NF}' | awk -F"'" '{print $1}'`
   PYTHONPATH=${x/\$SAPSYSTEMNAME/$SAPSYSTEMNAME}
   #echo "pythonpath is: ***** $PYTHONPATH *************"
}

get_pythonpath
retval=$?
steps_logging "Step 1: Python path"
if [ $retval -ne 0 ]; then
   #echo "ERRORMSG: Failed to get python path $dbsid!"
   exit 1
fi

if [ -z $PYTHONPATH ]; then
echo "ERRORMSG: Recovery:  PYTHONPATH-- path for recoverSys.py is not set "
exit 1
fi

DBADM=`echo $DBSID | tr '[A-Z]' '[a-z]'`
DBADM=$DBADM'adm'

DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
OLDDBSID=`echo $OLDDBSID | tr '[a-z]' '[A-Z]'`

get_globalpath ()
{
  if [ ! -z "$DIR_INSTANCE" ]; then
     globalpath=`echo $DIR_INSTANCE`
     globalpath=`dirname $globalpath`
  fi
}

get_globalpath_wrapper
retval=$?
steps_logging "Step 2: global path"
if [ $retval -ne 0 ]; then
   #echo "ERRORMSG: Failed to get globalpath $dbsid!"
   exit 1
fi

get_ssl_enforce ()
{
   SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
   SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
   SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`
}

get_ssl_enforce_wrapper
retval=$?
steps_logging "Step 3: ssl enforce"
if [ $retval -ne 0 ]; then
   echo "ERRORMSG: Failed to get sslenforce $dbsid!"
   exit 1
fi

LOGBACKUPPATH=`grep -i basepath_logbackup $globalpath/SYS/global/hdb/custom/config/global.ini | cut -d"=" -f2 | sed -e 's/^[ \t]*//'`

if [ ! -d "$LOGBACKUPPATH" ]; then
   mkdir -p $LOGBACKUPPATH
fi

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql_wrapper="hdbsql_cmd_wrapper -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql_wrapper="hdbsql_cmd_wrapper"
fi

if [ "$APPREMOUNT" = "TRUE" ]; then
   #echo "************ Remount Flag: $APPREMOUNT ***************"
   steps_logging "Step 4: start application remount"
   INSTANCENUM=`getenv | grep TINSTANCE= | cut -d"=" -f2`
   sapcontrol_start_wrapper -nr $INSTANCENUM -function StartSystem HDB

   if [ "$?" -gt 0 ]; then
      echo "ERRORMSG: Failed to start database during Remount Process!"
      exit 1;
   fi

   waitforhdbnameserver_wrapper "$HANAVERSION" "$DBADM" "$DBUSER"
   steps_logging "Step 4: end application remount"
   exit 0
fi

#echo "************************** running HDB info  ******************"
HDB_wrapper info

#echo "************************** running recoverSys.py  ******************"

set_rtime_logcount ()
{
if [ ! -z $LOGPATH ]; then
   LOGPATHCHECK=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
   checklogs=`find $LOGPATHCHECK/ -name "log_backup*" | wc -l`
   if [ "$checklogs" -eq 0 ]; then
      RECOVERYTIME=''
   fi
fi
}

set_rtime_logcount_wrapper
retval=$?
steps_logging "Step 5: Set Recovery time"
if [ $retval -ne 0 ]; then
   echo "ERRORMSG: Failed to get sslenforce $dbsid!"
   exit 1
fi

set_logbkppath ()
{
   LOGPATH=$1
   LDBNAME=$2
   LOG_BKP_PATH=""
   for path in $( echo $LOGPATH | tr ',' ' ')
   do
      if [ -z "$LOG_BKP_PATH" ]; then
         LOG_BKP_PATH=\'$path/$LDBNAME\'
      else
         LOG_BKP_PATH=$LOG_BKP_PATH','\'$path/$LDBNAME\'
      fi
   done
}

systemdb_lvm_recovery ()
{
   steps_logging "Step 6: Start SystemDB recovery"
   if [ ! -z "$RECOVERYTIME" ]; then
      if [ "$HANAVERSION" = "1.0" ]; then
         set_logbkppath_wrapper $LOGPATH SYSTEMDB
         HDBSettings_wrapper $PYTHONPATH/recoverSys.py --command="RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
      else
         CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
         CATALOGPATH=$CATALOGPATH"/SYSTEMDB/"
         set_logbkppath_wrapper $LOGPATH SYSTEMDB
         HDBSettings_wrapper $PYTHONPATH/recoverSys.py --command="RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
      fi
   else
      HDBSettings_wrapper $PYTHONPATH/recoverSys.py --command="RECOVER DATA USING SNAPSHOT CLEAR LOG"
   fi
   retval=$?
   if [ $retval -ne 0 ]; then
      echo "ERRORMSG: Failed to recover database $dbsid: check check customapp-saphana.log for details!"
      exit $retval
   fi
}

systemdb_lvm_recovery
retval=$?
steps_logging "Step 6: End SystemDB recovery"
if [ $retval -ne 0 ]; then
   echo "ERRORMSG: Failed to recover database $dbsid: check check customapp-saphana.log for details!"
   exit $?
fi

waitforhdbnameserver_wrapper "$HANAVERSION" "$DBADM" "$DBUSER"

echo "************************** running HDB info  ******************"
HDB_wrapper info

SOURCE_HVERSIONTMP=`echo $HANAVERSION |sed 's/\.//g'`

recover_lvm_tenantdb ()
{
   steps_logging "Step 8: Start Teannt DB recovery"
   if [ "$SOURCE_HVERSIONTMP" -ge "200000" ] || [ "$HANAVERSION" = "2.0" ]; then
      DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
      for i in ${dbnames}; do
         TSID=`echo $i |awk -F '"' '{print $2}'`
         if [ $i = "DATABASE_NAME" ] || [ $TSID = "SYSTEMDB" ] || [ x"$TSID" = "x" ]; then
          :
         else
            if [ ! -z "$RECOVERYTIME" ]; then
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
                  if [ -d "$CATALOGPATH" ]; then
                     #echo "$CATALOGPATH for $TSID could not found. $TSID recovery will not be recovered."
                     HDB_wrapper stop
                     exit 1
                  fi
               fi

               #waitforhdbnameserver_wrapper $HANAVERSION $DBADM $DBUSER
               STOPSQL="ALTER SYSTEM STOP DATABASE $TSID"
               SQL="RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
              #echo "********** recovering HANA TENANT DB recover:DBUSER=$DBUSER and dbsid=$dbsid ************"
              $hdbsql_wrapper -U $DBUSER -a -j $STOPSQL
              retval=$?
              if [ $retval -ne 0 ]; then
                 echo "ERRORMSG: Failed to stop $TSID: check customapp-saphana.log for details."
                 exit $retval
              fi

              $hdbsql_wrapper -U $DBUSER -a -j $SQL
              retval=$?
              if [ $retval -ne 0 ]; then
                 echo "ERRORMSG: Recovery: Failed to recover Tenant database $TSID: check customapp-saphana.log for details"
                 exit $retval
              fi

           else
              STOPSQL="ALTER SYSTEM STOP DATABASE $TSID"
              SQL="RECOVER DATA FOR $TSID USING SNAPSHOT CLEAR LOG"
              #echo "********** recovering HANA TENANT DB recover:DBUSER=$DBUSER and dbsid=$dbsid ************"
              $hdbsql_wrapper -U $DBUSER -a -j $STOPSQL
              retval=$?
              if [ $retval -ne 0 ]; then
                 echo "ERRORMSG: Failed to stop $TSID: check customapp-saphana.log for details."
                 exit $retval
              fi

              $hdbsql_wrapper -U $DBUSER -a -j $SQL
              retval=$?
              if [ $retval -ne 0 ]; then
                 echo "ERRORMSG: Recovery: Failed to recover Tenant database $TSID: check customapp-saphana.log for details"
                 exit $retval
              fi
            fi
            #echo "********** starting HANA TENANT DB recover:DBUSER=$DBUSER and dbsid=$TSID ************"
            steps_logging "Step 9: Starting Tenant DB "
            SQL="alter system start database $TSID"
            $hdbsql_wrapper -U $DBUSER -a -j $SQL
            retval=$?
            if [ $retval -ne 0 ]; then
               echo "ERRORMSG: Failed to start saphana tenant database $dbsid!"
               exit 1
            fi
         fi
      done

   #echo "************************** running HDB info  ******************"
   HDB_wrapper info
   fi
   #echo "************************** Database recovery complete ******************"
}

recover_lvm_tenantdb_wrapper
retval=$?
steps_logging "Step 9: Started Tenant DB"
if [ $retval -ne 0 ]; then
   echo "ERRORMSG: Recovery: Failed to recover Tenant database $TSID: check customapp-saphana.log for details"
   exit $retval
fi
#exit 0

