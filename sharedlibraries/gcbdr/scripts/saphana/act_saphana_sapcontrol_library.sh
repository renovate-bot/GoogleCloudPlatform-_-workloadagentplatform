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

DBSID=$1
export DBSID

curr_dir=`pwd`
ppid=`pstree -g -s $$ | awk -F"---" '{print $(NF-1)}' | cut -d"(" -f2 | cut -d")" -f1 | cut -d"+" -f1 | head -n1`
if [ -d "$curr_dir/$ppid" ]; then
   ppid=$ppid
else
  ppid=$((ppid + 1));
fi
globalhanarestoredatafile=$curr_dir/$ppid/saphana_test_data.$ppid
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

if [ -f "$globalhanarestoredatafile" ]; then
   mockswitch=`grep "mockswitch" $globalhanarestoredatafile | cut -f2 -d"="`
   if [ -z "$mockswitch" ]; then
      mockswitch="off"
   fi
else
   mockswitch="off"
fi
sapcontrolstatefile=$curr_dir/$ppid/fake_global_data_sapcontrol.$ppid
fakedatabaseinstance=$curr_dir/$ppid/fake_database_instance.$ppid
if [ $mockswitch != "off" ]; then
   if [ ! -d "/tmp/$$" ]; then
      mkdir -p /tmp/$$
   else
      rm -rf /tmp/$$
      mkdir -p /tmp/$$
   fi
   echo "DBSID:$DBSID" > $fakedatabaseinstance
fi

get_db_sid ()
{
   NDBSID=`grep "$DBSID" $fakedatabaseinstance | cut -f2 -d:`
   if [ ! -z "$NDBSID" ]; then
      export NDBSID
   else
      return 1
   fi
}

getenv ()
{
   if [ $mockswitch = "off" ]; then
      env
   else
      fake_env_test
      export TINSTANCE
      env
   fi
}

fake_env_test ()
{
  tinstancenum=`grep -i "instance_number" $globalhanarestoredatafile | cut -d"=" -f2 | xargs`
  if [ ! -z "$tinstancenum" ]; then
     TINSTANCE="$tinstancenum"
     export TINSTANCE
  fi
}

waitfordbstop_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      waitfordbstop
   else
      fake_waitfordbstop_status
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

fake_waitfordbstop_status ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      if [ $istatus != "STOPPED" ]; then
         return 1
      else
         return 0
      fi
   else
      return 1
   fi
}

sapcontrol_status_wrapper ()
{
   if [ $mockswitch = "off" ]; then
      sapcontrol $*
   else
      fake_sapcontrol_wrapper status
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

sapcontrol_start_wrapper ()
{
   if [ $mockswitch = "off" ]; then
       sapcontrol $*
   else
      fake_sapcontrol_wrapper start
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

sapcontrol_stop_wrapper ()
{
   if [ $mockswitch = "off" ]; then
       sapcontrol $*
   else
      fake_sapcontrol_wrapper stop
      retval=$?
      if [ $retval -eq "0" ]; then
         return 0
      else
         return 1
      fi
   fi
}

fake_sapcontrol_wrapper ()
{
   if [ $1 = "stop" ]; then
      fake_instance_stop
      retval=$?
   elif [ $1 = "start" ]; then
      fake_instance_start
      retval=$?
   else
      fake_instance_status
      retval=$?
   fi
   if [ $retval -eq "0" ]; then
      return 0
   else
      return 1
   fi
}

fake_instance_stop ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      if [ -f $sapcontrolstatefile ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      fi
      if [ $istatus != "STOPPED" ] || [ -z  "$istatus" ]; then
         echo "$NDBSID:STOPPED" > $sapcontrolstatefile
         return 0
      else
         return 1
      fi
   else
      return 1
   fi
}

fake_instance_start ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      if [ -f $sapcontrolstatefile ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      fi
      if [ -z  "$istatus" ] || [ $istatus != "RUNNING" ]; then
         echo "$NDBSID:RUNNING" > $sapcontrolstatefile
         return 0
      else
         return 1
      fi
   else
      return 1
   fi
}

fake_instance_status ()
{
   get_db_sid
   retval=$?
   if [ $retval -eq "0" ]; then
      if [ -f $sapcontrolstatefile ]; then
         istatus=`grep "$NDBSID" $sapcontrolstatefile | cut -f2 -d:`
      fi
      if [ -z "$istatus" ] || [ -z  "$istatus" ]; then
         echo "$NDBSID:RUNNING" > $sapcontrolstatefile
         return 0
      else
         return 0
      fi
   else
      return 1
   fi
}
