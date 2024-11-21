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

DBUSER=$1

   globalpath=`su - $DBUSER -c 'echo $DIR_INSTANCE'`
   globalpath=`dirname $globalpath`
   nameserverpath=$globalpath/SYS/global/hdb/custom/config/nameserver.ini

OPERATION_MODE=`su - $DBUSER -c "hdbnsutil -sr_state | grep \"operation mode:\""`
if [ -z "$OPERATION_MODE" ]; then
   OPERATION_MODE=`su - $DBUSER -c "hdbnsutil -sr_state | grep \"mode:\""`
fi
OPERATION_MODE=`echo $OPERATION_MODE | awk -F":" '{print $2}'|xargs`

if [ ! -z "$OPERATION_MODE" ]; then
   if [ "$OPERATION_MODE" = "primary" ]; then
      NOOFNODES=`su - $DBUSER -c 'HDBSettings.sh landscapeHostConfiguration.py --sapcontrol=1 | grep -i Host | awk -F "/" '"'"'{print $2}'"'"' | sort | uniq |wc -l '`
      if [ "$NOOFNODES" -lt 2 ]; then
          STATUS=`su - $DBUSER -c "hdbnsutil -sr_state | grep \"online:\""`
          STATUS=`echo $STATUS | awk -F":" '{print $2}'|xargs`
          if [ "$STATUS" = "false" ]; then
             echo "PRIMARYNODE="
             exit 0
          else
             PRIMARY_NODE=`hostname`
          fi
      fi
   elif [ "$OPERATION_MODE" = "logreplay_readaccess" ] || [ "$OPERATION_MODE" = "sync" ] || [ "$OPERATION_MODE" = "logreplay" ] || [ "$OPERATION_MODE" = "delta_datashipping" ]; then
        PRIMARY_NODE=`su - $DBUSER -c "hdbnsutil -sr_state |grep \"primary masters\""`
        retval=$?
        PRIMARY_NODE=`echo $PRIMARY_NODE | awk -F":" '{print $2}' |xargs`
   elif [ "$OPERATION_MODE" = "unknown" ]; then
        PRIMARYNODE=`su - $DBUSER -c 'HDBSettings.sh landscapeHostConfiguration.py --sapcontrol=1 | grep -i nameServerConfigRole| grep master | awk -F"/" '"'"'{print $2}'"'"' '`
        echo "PRIMARYNODE=$PRIMARYNODE"
        exit 0
   fi
fi


if [ ! -z "$PRIMARY_NODE" ]; then
    echo "PRIMARYNODE=$PRIMARY_NODE"
fi
if [ -z "$PRIMARY_NODE" ]; then
   globalpath=`su - $DBUSER -c 'echo $DIR_INSTANCE'`
   globalpath=`dirname $globalpath`
   nameserverpath=$globalpath/SYS/global/hdb/custom/config/nameserver.ini

  # MASTERNODE=`grep -w "active_master" $nameserverpath | awk -F"=" '{print $2}' | tr -d '[:space:]'`
  NOOFNODES=`su - $DBUSER -c 'HDBSettings.sh landscapeHostConfiguration.py --sapcontrol=1 | grep -i Host | awk -F "/" '"'"'{print $2}'"'"' | sort | uniq |wc -l '`
  if [ "$NOOFNODES" -gt 1 ]; then
     MASTERNODE=`su - $DBUSER -c 'HDBSettings.sh landscapeHostConfiguration.py --sapcontrol=1 | grep -i nameServerActualRole | grep master | awk -F"/" '"'"'{print $2}'"'"' '`
     PORT=`grep -w "active_master" $nameserverpath | awk -F"=" '{print $2}' |awk -F":" '{print $2}' | tr -d '[:space:]'`
     if [ -z "$MASTERNODE" ]; then
        MASTERNODE=`grep -w "active_master" $nameserverpath | awk -F"=" '{print $2}' |awk -F":" '{print $1}' | tr -d '[:space:]'`
     fi
  else
     MASTERNODE=`su - $DBUSER -c 'HDBSettings.sh landscapeHostConfiguration.py --sapcontrol=1 | grep -iw host  | awk -F"=" '"'"'{print $2}'"'"' '`
     PORT=`grep -w "active_master" $nameserverpath | awk -F"=" '{print $2}' |awk -F":" '{print $2}' | tr -d '[:space:]'`
     if [ -z "$MASTERNODE" ]; then
        MASTERNODE=`grep -w "active_master" $nameserverpath | awk -F"=" '{print $2}' |awk -F":" '{print $1}' | tr -d '[:space:]'`
     fi
  fi
   retval=$?

   if [ "$retval" -gt 0 ]; then
       echo "ERRORMSG: Failed to find the Master Node"
       exit 1
   fi

   echo "MASTERNODE=$MASTERNODE:$PORT"
fi

exit 0
