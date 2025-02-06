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
DBSID=$DBSID
DATAVOLPATH=$DATAMOUNTVOL
JOBID=$JOBID

#DBSID=pdc
#DATAVOLPATH=/testmount/hana/data/PDS

LOGLOCATION=/var/act/log

osuser=
if [[ ! -z "$DBSID" ]]; then
   osuser=`echo $DBSID | tr '[A-Z]' '[a-z]'`
   osuser="$osuser"adm
   su - $osuser -c 'echo $DIR_INSTANCE' 2> /dev/null
   retval=$?
   if [[ "$retval" -gt 0 ]]; then
      echo "Info: source database sid $DBSID does not exist, checking for local instance user"
      osuser=
   fi
fi
if [[ -z "$osuser" ]]; then
   hanauserlist="$(cat /etc/passwd |grep adm |grep -v sapadm |awk -F":" '{print $1}' | xargs)"
   for hanauser in ${hanauserlist}
   do
     su - $hanauser -c 'echo $DIR_INSTANCE' 2> /dev/null
     retval=$?
     if [[ "$retval" -gt 0 ]]; then
         continue;
     else
        osuser=$hanauser
        break;
     fi
   done
fi

add_log_footer()
{
  echo "************************************************************************************************************" >> $LOGFILE
  echo " $JOBID: Integrity check completed at $tdate " >> $LOGFILE
  echo " Trace File Loc: $traceloc/localclient.000000000.trc" >> $LOGFILE
  echo " $msg"  >> $LOGFILE
  echo "************************************************************************************************************" >> $LOGFILE
}

tdate=`date +"%m-%d%-Y %H:%M:%S"`
LOGFILE=$LOGLOCATION/"$DBSID"'_dataintegeity_check.log'

traceloc="$(su - $osuser -c "echo \$DIR_INSTANCE")"
globalpath="$(dirname $traceloc)"
nodename="$(cat $globalpath/SYS/global/hdb/custom/config/nameserver.ini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs)"

if [[ -z "$nodename" ]]; then
    nodename="$(hostname)"
fi
traceloc=$traceloc/$nodename/trace

if [[ ! -d $traceloc ]]; then
    su - $osuser -c "mkdir -p $traceloc"
fi
if [ ! -f $LOGFILE ]; then
   touch $LOGFILE
   chown $osuser:sapsys $LOGFILE
else
   chown $osuser:sapsys $LOGFILE
fi

echo " " >> $LOGFILE
echo "************************************************************************************************************" >> $LOGFILE
echo " $JOBID: Integrity check started at $tdate" >> $LOGFILE
echo "************************************************************************************************************" >> $LOGFILE

if [ ! -z "$DATAVOLPATH" ]; then
   CHECK_USAGE=`fuser -cu $DATAVOLPATH`
   if [ ! -z "$CHECK_USAGE" ]; then
      echo "ERRORMSG: Unable to perform data integrity test as the Data volume is being used by the proceses $CHECK_USAGE"
      exit 1
   fi
fi

MNT_FOLDER=`ls $DATAVOLPATH | grep mnt| grep -v grep`
MNT_FOLDER_PATH=$DATAVOLPATH/$MNT_FOLDER
DATAVOL_FOLDER_LIST=`ls $DATAVOLPATH/$MNT_FOLDER | grep hdb |grep -v grep |xargs`

for hdb in ${DATAVOL_FOLDER_LIST}
do
  curdate=`date +"%m-%d-%Y-%H:%M"`
  echo "============ hdbpersdiag for the data volume $hdb Date: $curdate ========================" >> $LOGFILE
  su - $osuser -c "hdbpersdiag -c -f 'check all' $MNT_FOLDER_PATH/$hdb --tracedir $traceloc" >> $LOGFILE
  echo " " >> $LOGFILE
done

#CHK_ERRORS=`cat $LOGFILE | grep -i error |grep -v grep |wc -l`
CHK_ERRORS=`cat $LOGFILE |awk "/$JOBID/,EOF" | grep -i error |grep -v grep |wc -l`

tdate=`date +"%m-%d-%Y %H:%M:%S"`
if [ "$CHK_ERRORS" -gt 0 ]; then
   #echo "ERRORMSG: Found errors during Data Integrity Check, please check logs $LOGFILE, $traceloc/localclient.000000000.trc for details" >> $LOGFILE
   msg="ERRORMSG: Found errors during Data Integrity Check, please refer log $traceloc/localclient.000000000.trc for details"
   add_log_footer
   echo "ERRORMSG: Found errors during Data Integrity Check, please refer logs $LOGFILE, $traceloc/localclient.000000000.trc for details"
   exit 1
else
   #echo "Data Integrity check completed successfully. Please find the logs $LOGFILE, $traceloc/localclient.000000000.trc for details" >> $LOGFILE
   msg="Data Integrity check completed successfully. Please refer the log $traceloc/localclient.000000000.trc for details"
   add_log_footer
fi
exit 0
