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
echo "$DATE"

dbsid=$1

rpath=$(realpath "${BASH_SOURCE:-$0}")
currdir1=$(dirname $rpath)
currdir=$(dirname $currdir1)
source $currdir/act_saphana_sapcontrol_library.sh

dbsid=`echo $dbsid | tr '[A-Z]' '[a-z]'`

get_instance_num ()
{
   INSTANCENUM=`getenv | grep TINSTANCE= | cut -d"=" -f2`
   if [ ! -z "$INSTANCENUM" ]; then
      export INSTANCENUM
   fi

   if [ -z "$INSTANCENUM" ] && [ ! -z "$DIR_INSTANCE" ]; then
      INSTANCENUM=`basename $DIR_INSTANCE | rev | cut -c 1-2 | rev`
   fi

   if [ -z "$INSTANCENUM" ]; then
      echo "ERRORMSG: Failed to get INSTANCE#, Please check!"
      exit 1
   fi
}

waitfordbstop() {
  #Set a timeout of 8 minutes (8*6*10)
  waitFlag=true
  timeout=0
  while $waitFlag; do
    timeout=$((timeout+1))
    if [ $timeout -gt 20 ]; then
      echo "ERRORMSG: database is still running after 10 minutes of stop command!. Please check!"
      exit 1
    fi
    dbstopcnt=`sapcontrol -nr $INSTANCENUM -function GetSystemInstanceList | grep -Ei "GREEN|YELLOW|RED" | wc -l`
    if [ $dbstopcnt -gt 0 ]; then
       echo "Waiting for database to be stop.."
       sleep 30
       continue
    else
      waitFlag=false
    fi
  done
  return 0
}

get_dbstop_status ()
{
   #echo "************************** sapcontrol GetSystemInstanceList  ******************"
   sapcontrol_status_wrapper -nr $INSTANCENUM -function GetSystemInstanceList

   #echo "************************** sapcontrol GetSystemInstanceList  ******************"
   sapcontrol_stop_wrapper -nr $INSTANCENUM -function StopSystem

   waitfordbstop_wrapper

   #echo "************************** sapcontrol GetSystemInstanceList  ******************"
   sapcontrol_status_wrapper -nr $INSTANCENUM -function GetSystemInstanceList

   #echo "************************** Database stopped ******************"
}

get_instance_num
retval=$?
if [ $retval -gt "0" ]; then
   exit 1
fi
get_dbstop_status
retval=$?
if [ $retval -gt "0" ]; then
   exit 1
fi

#exit 0

