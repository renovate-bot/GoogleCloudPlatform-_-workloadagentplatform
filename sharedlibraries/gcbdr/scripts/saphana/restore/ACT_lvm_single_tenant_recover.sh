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

TSID=$1
DBUSER=$2
DATAPATH=$3
DBADM=$4
CATALOGPATH=$5
RECOVERYTIME=$6


LOGPATH=$CATALOGPATH
x=`grep python_support $HOME/.sapenv.sh | awk -F"=" '{print $NF}' | awk '{print $NF}' | awk -F"'" '{print $1}'`
PYTHONPATH=${x/\$SAPSYSTEMNAME/$SAPSYSTEMNAME}
echo "pythonpath is: ***** $PYTHONPATH *************"


if [ -z $PYTHONPATH ]; then
   echo "ERRORMSG: Recovery:  PYTHONPATH-- path for recoverSys.py is not set "
   exit 1
fi

globalpath=`echo $DIR_INSTANCE`
globalpath=`dirname $globalpath`

SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

waitforhdbnameserver() {
  #Set a timeout of 8 minutes (8*6*10)
  waitFlag=true
  timeout=0
  while $waitFlag; do
    timeout=$((timeout+1))
    if [ $timeout -gt 30 ]; then
      echo "ERRORMSG: hdbnameserver did not come up after 10 minutes!. Please check!"
      exit 1
    fi
    nameserverProcess=`ps -ef | grep -i hdbnameserver | grep -v grep | grep -i $DBADM`
    if [ -z "$nameserverProcess" ]; then
       echo "Waiting for hdbnameserver process to be up..."
       sleep 30
       continue
    else
      hdbpreprocessorProcess=`ps -ef | grep -i hdbpreprocessor | grep -v grep | grep -i $DBADM`
      if [ -z "$hdbpreprocessorProcess" ]; then
        echo "Waiting for hdbnameserver process to be up..."
        sleep 30
        continue
      else
        sleep 30
        dbnames=`$hdbsql -U $DBUSER -a -x "select database_name from m_databases"`
        if [ $? -ne 0 ]; then
         echo "Not yet able to execute db select query on m_databases..Retry"
         waitFlag=true
        else
         waitFlag=false
        fi
      fi
      sleep 30
      #waitFlag=false
    fi
  done
  return 0
}


if [ "$TSID" = "SYSTEMDB" ]; then
   if [ -z "$RECOVERYTIME" ]; then
      HDBSettings.sh $PYTHONPATH/recoverSys.py --command="RECOVER DATA USING SNAPSHOT CLEAR LOG"
      retval=$?
      if [ "$retval" -gt 0 ]; then
         echo "ERRORMSG: Failed to recover $TSID, please check the logs!"
         exit 1
      fi
     waitforhdbnameserver
   elif [ ! -z "$RECOVERYTIME" ] && [ ! -z "$LOGPATH" ]; then
        CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
            CATALOGPATH=$CATALOGPATH/SYSTEMDB/
            LOG_BKP_PATH=""
            for path in $( echo $LOGPATH | tr ',' ' ')
            do
              if [ -z "$LOG_BKP_PATH" ]; then
                 LOG_BKP_PATH=\'$path/SYSTEMDB\'
              else
                 LOG_BKP_PATH=$LOG_BKP_PATH','\'$path/SYSTEMDB\'
              fi
           done
        HDBSettings.sh $PYTHONPATH/recoverSys.py --command="RECOVER DATABASE UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
     waitforhdbnameserver
   elif [ ! -z "$RECOVERYTIME" ] && [ -z "$LOGPATH" ]; then
        echo "ERRORMSG: ARCHIVE LOG MOUNT POINT is required for Point in time recovery!"
        exit 1
   fi

     for tsid in ${dbnames}; do
        tsid=`echo $tsid | sed s'/"//g'`
        if [ "$tsid" = "SYSTEMDB" ]; then
           :
        else
            SQL="alter system start database $tsid"
            $hdbsql -U $DBUSER -a $SQL
        fi
     done
else
   if [ -z "$RECOVERYTIME" ]; then
      STOPSQL="ALTER SYSTEM STOP DATABASE $TSID"
      SQL="RECOVER DATA FOR $TSID USING SNAPSHOT CLEAR LOG"
      $hdbsql -U $DBUSER -a $STOPSQL
      $hdbsql -U $DBUSER -a $SQL
      retval=$?
      if [ "$retval" -gt 0 ]; then
         echo "ERRORMSG: Failed to recover $TSID, please check the logs!"
         exit 1
      fi
   elif [ ! -z "$RECOVERYTIME" ] && [ ! -z "$LOGPATH" ]; then
        CATALOGPATH=`echo $LOGPATH | rev |awk -F"," '{ print $1}' |rev`
        CATALOGPATH=$CATALOGPATH"/DB_"$TSID"/"
        LOG_BKP_PATH=""
        for path in $( echo $LOGPATH | tr ',' ' ')
          do
           if [ -z "$LOG_BKP_PATH" ]; then
              LOG_BKP_PATH=\'$path/DB_$TSID\'
           else
              LOG_BKP_PATH=$LOG_BKP_PATH','\'$path/DB_$TSID\'
           fi
          done
        STOPSQL="ALTER SYSTEM STOP DATABASE $TSID"
        SQL="RECOVER DATABASE FOR $TSID UNTIL TIMESTAMP '$RECOVERYTIME' CLEAR LOG USING CATALOG PATH ('$CATALOGPATH') USING DATA PATH ('$DATAPATH') USING LOG PATH ($LOG_BKP_PATH) USING SNAPSHOT CHECK ACCESS USING FILE"
        $hdbsql -U $DBUSER -a $STOPSQL
        $hdbsql -U $DBUSER -a -j $SQL
        retval=$?
        if [ "$retval" -gt 0 ]; then
           echo "ERRORMSG: Failed to recover $TSID, please check the logs!"
           exit 1
        fi
   elif [ ! -z "$RECOVERYTIME" ] && [ -z "$LOGPATH" ]; then
        echo "ERRORMSG: ARCHIVE LOG MOUNT POINT is required for Point in time recovery!"
        exit 1
   fi
fi

