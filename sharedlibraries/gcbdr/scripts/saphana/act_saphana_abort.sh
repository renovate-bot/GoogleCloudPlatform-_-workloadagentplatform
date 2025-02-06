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

DBSID=$1
DBUSER=$2
DBPORT=$3
PORT=$4
HANAVERSION=$5

DATA=`date`
echo "************************** DATE:$DATE: Close UNSUCCESSFUL Snapshot $DBSID database ******************"

HCMT='ACT_'$DBSID'_SNAP'

SQL="SELECT BACKUP_ID from M_BACKUP_CATALOG WHERE COMMENT = '$HCMT' and ENTRY_TYPE_NAME = 'data snapshot' and STATE_NAME = 'prepared' and SYS_END_TIME is null "

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

ID=`/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL | head -n1`
ID=`echo ${ID} | awk '{print $1}'`
if [ "$ID" = "0" ]
then
 echo "********** !!! no snapshot ID found to close *********"
 exit 0
fi

if [ "$HANAVERSION" = "1.0" ]
then
SQL="BACKUP DATA CLOSE SNAPSHOT BACKUP_ID $ID UNSUCCESSFUL 'ActBackup_failed'"
else
SQL="BACKUP DATA FOR FULL SYSTEM CLOSE SNAPSHOT BACKUP_ID $ID UNSUCCESSFUL 'ActBackup_failed'"
fi

/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $DBUSER -a -j $SQL
retval=$?
if [ $retval -ne 0 ]; then
    echo "ERRORMSG: Failed to Close Snapshot $DBSID database: check customapp-saphana.log for details and manually close the snapshot if open"
    exit $retval
fi

exit 0
