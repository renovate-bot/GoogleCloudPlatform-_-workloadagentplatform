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


DBSID=$1
HANADBKEY=$2
SOURCETENANTDBSID=$3
TARGETTENANTDBSID=$4


if [[ X$SOURCETENANTDBSID == "XSYSTEMDB" ]] || [[ X$TARGETTENANTDBSID == "XSYSTEMDB" ]]
  then
   echo "ERRORMSG: Source or Target tenant cannot be SYSTEMDB - ACT_HANADB_renamedb"
   exit 1
fi

 length=`expr length "$DBSID"`

 if [[ "$length" != 3 ]]
     then
     echo "ERRORMSG: invalid length of SID - ACT_HANADB_renamedb"
     exit 1
  else
     DBSID=`echo $DBSID | tr '[a-z]' '[A-Z]'`
     echo "INFO: The SID is $DBSID - ACT_HANADB_renamedb"
  fi

  DBSIDlow=`echo "$DBSID" | awk '{print tolower($0)}'`
  DBSIDupper=`echo "$DBSID" | awk '{print toupper($0)}'`
  HANAuser=`echo "$DBSIDlow""adm"`

  if id "$HANAuser" >/dev/null 2>&1
  then echo "INFO: User $HANAuser exists - ACT_HANADB_renamedb"
  else echo "ERRORMSG: User $HANAuser does not exist - ACT_HANADB_renamedb"
  exit 1
  fi

SAPSYSTEMNAME=`su - "$HANAuser" bash -c 'echo $SAPSYSTEMNAME'`
TINSTANCE=`su - "$HANAuser" bash -c 'echo $TINSTANCE'`
DBPORT=`echo "HDB$TINSTANCE"`
sap_path=`su - "$HANAuser" -c 'echo $DIR_INSTANCE'`
sap_path=`dirname $sap_path`

SSLENFORCE=`grep "sslenforce" $sap_path/SYS/global/hdb/custom/config/global.ini`
SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

if [ "$SSLENFORCE" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

CHECK_SYSTEMDBKEY=`su - "$HANAuser" bash -c "hdbuserstore list $HANADBKEY" | grep 13$`
if [[ X$CHECK_SYSTEMDBKEY == X ]]
  then echo "ERRORMSG --  Key $HANADBKEY is not a valid SYSTEMDB KEY access"
  exit 1
fi


KEYEXIST=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY \"select * from dummy\"" | head -n1`

if [[ "X$KEYEXIST" == "XDUMMY" ]]
  then
   echo "INFO: KEY "$HANADBKEY" exists and is able to connect to database - ACT_HANADB_renamedb"
  else
   echo "ERRORMSG: KEY "HANADBKEY" doesn't exist or password combinaison is wrong - ACT_HANADB_renamedb"
   exit 1
fi

SQL_CHECK_MULTITENANT=`echo "SELECT DATABASE_NAME from \"PUBLIC\".\"M_DATABASES\" where DATABASE_NAME='SYSTEMDB'"`
CHECK_MULTITENANT=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_MULTITENANT\""`


if [[ "X$CHECK_MULTITENANT" == "X\"SYSTEMDB\"" ]]
  then
   echo "INFO: Database system $DBSID is multi tenant configured [multidb] - ACT_HANADB_renamedb"
  else
   echo "ERRORMSG: Database system $DBSID is singletenant configured [singledb] - ACT_HANADB_renamedb"
   exit 1
fi



SQL_CHECK_SRC_TDB=`echo "SELECT DATABASE_NAME from \"PUBLIC\".\"M_DATABASES\" where DATABASE_NAME='$SOURCETENANTDBSID'"`
CHECK_SRC_TDB=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_SRC_TDB\""`


if [[ "X$CHECK_SRC_TDB" == "X\"$SOURCETENANTDBSID\"" ]]
  then
   echo "INFO: Source tenant $SOURCETENANTDBSID exists - ACT_HANADB_renamedb"
  else
   echo "ERRORMSG: Source tenant $SOURCETENANTDBSID does not exist - ACT_HANADB_renamedb"
   exit 1
fi

SQL_CHECK_TGT_TDB=`echo "SELECT DATABASE_NAME from \"PUBLIC\".\"M_DATABASES\" where DATABASE_NAME='$TARGETTENANTDBSID'"`
CHECK_TGT_TDB=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_TGT_TDB\""`

if [[ "X$CHECK_TGT_TDB" == "X\"$TARGETTENANTDBSID\"" ]]
  then
   echo "ERRORMSG: Target tenant name $TARGETTENANTDBSID already exist and cannot be used for renaming - ACT_HANADB_renamedb"
   exit 1
  else
   echo "INFO: Target tenant name $TARGETTENANTDBSID is available - ACT_HANADB_renamedb"
fi



#Pre requisite checks

CURR_DBUSER=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"select CURRENT_USER from dummy\"" | head -n1`
CURR_DBUSER=`echo $CURR_DBUSER | tr -d '"'`
SQL_CHECK_PRIV=`echo "SELECT IS_VALID FROM \"PUBLIC\".\"EFFECTIVE_PRIVILEGES\" where USER_NAME='$CURR_DBUSER' and OBJECT_TYPE='SYSTEMPRIVILEGE' and PRIVILEGE='DATABASE ADMIN'"`
CHECK_PRIV=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_PRIV\""`
CHECK_PRIV=`echo $CHECK_PRIV | tr -d '"'`

if [[ "X$CHECK_PRIV" == "XTRUE" ]]
  then
   echo "INFO: The KEY $HANADBKEY is Associated to DB user $CURR_DBUSER and has DATABASE ADMIN Privileges - ACT_HANADB_renamedb"
  else
   echo "ERRORMSG: The KEY $HANADBKEY is Associated to DB user $CURR_DBUSER doesn't have DATABASE ADMIN Privileges - ACT_HANADB_renamedb"
   exit 1
fi

SQL_IS_REPL_ACTIVE=`echo "SELECT * FROM \"PUBLIC\".\"M_SERVICE_REPLICATION\""`
IS_REPL_ACTIVE=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_IS_REPL_ACTIVE\""`
IS_REPL_ACTIVE=`echo $IS_REPL_ACTIVE | tr -d '"'`

if [[ "X$IS_REPL_ACTIVE" == "XTRUE" ]]
  then
   echo "ERRORMSG: Database replication is active the $SOURCETENANTDBSID will be abort. - ACT_HANADB_renamedb"
   exit 1
  else
   echo "INFO: There is no Database Replication active for $SOURCETENANTDBSID, the tenant renaming process can continue.- ACT_HANADB_renamedb"
fi

SQL_IS_DYNTIERING_ACTIVE=`echo "SELECT * FROM \"PUBLIC\".\"M_SERVICES\" where SERVICE_NAME='esserver'"`
IS_DYNTIERING_ACTIVE=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_IS_DYNTIERING_ACTIVE\""`

if [[ "X$IS_DYNTIERING_ACTIVE" == "X" ]]
  then
   echo "INFO: No Dynamic tiering configuration was found for $SOURCETENANTDBSID - ACT_HANADB_renamedb"
  else
   echo "ERRORMSG: At lease one dynamic tiering process was found. The renaming tenant DB process is not possible. - ACT_HANADB_renamedb"
   exit 1
fi

#Stopping the tenant database

SQL_STOP_SRC_TENANT=`echo "ALTER SYSTEM STOP DATABASE $SOURCETENANTDBSID ;"`
STOP_SRC_TENANT=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_STOP_SRC_TENANT\"" &`

SQL_CHECK_TENANT_STATE=`echo "SELECT ACTIVE_STATUS from \"PUBLIC\".\"M_DATABASES\" where DATABASE_NAME='$SOURCETENANTDBSID'"`
TENANT_IS_UP=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_TENANT_STATE\""`

echo "INFO: Tenant $SOURCETENANTDBSID active status : $TENANT_IS_UP"

  if [[ X$TENANT_IS_UP == XNO ]]
  then

    until [[ X$TENANT_IS_UP != XNO ]]
    do
      sleep 5

      TENANT_IS_UP=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_TENANT_STATE\""`
      echo "INFO: Tenant $SOURCETENANTDBSID is still up please wait"
    done
  fi

if [ -d $sap_path/$DBPORT/backup/log/DB_$SOURCETENANTDBSID ]
  then
    mv $sap_path/$DBPORT/backup/log/DB_$SOURCETENANTDBSID $sap_path/$DBPORT/backup/log/DB_$SOURCETENANTDBSID_act_old_$$
    mkdir $sap_path/$DBPORT/backup/log/DB_$TARGETTENANTDBSID
    chown $HANAuser:sapsys $sap_path/$DBPORT/backup/log/DB_$TARGETTENANTDBSID
fi

if [ -d $sap_path/$DBPORT/backup/data/DB_$SOURCETENANTDBSID ]
  then
    mv $sap_path/$DBPORT/backup/data/DB_$SOURCETENANTDBSID $sap_path/$DBPORT/backup/data/DB_$SOURCETENANTDBSID_act_old_$$
    mkdir $sap_path/$DBPORT/backup/data/DB_$TARGETTENANTDBSID
    chown $HANAuser:sapsys $sap_path/$DBPORT/backup/data/DB_$TARGETTENANTDBSID
fi

if [ -d $sap_path/SYS/global/hdb/backint/DB_$SOURCETENANTDBSID ]
  then
    mv $sap_path/SYS/global/hdb/backint/DB_$SOURCETENANTDBSID $sap_path/SYS/global/hdb/backint/DB_$SOURCETENANTDBSID_act_old_$$
    mkdir $sap_path/SYS/global/hdb/backint/DB_$TARGETTENANTDBSID
    chown $HANAuser:sapsys $sap_path/SYS/global/hdb/backint/DB_$TARGETTENANTDBSID
fi


if [ -d $sap_path/SYS/global/hdb/custom/config/DB_$SOURCETENANTDBSID ]
  then
    mv $sap_path/SYS/global/hdb/custom/config/DB_$SOURCETENANTDBSID $sap_path/SYS/global/hdb/custom/config/DB_$SOURCETENANTDBSID_act_old_$$
    mkdir $sap_path/SYS/global/hdb/custom/config/DB_$TARGETTENANTDBSID
    chown $HANAuser:sapsys $sap_path/SYS/global/hdb/custom/config/DB_$TARGETTENANTDBSID
fi

if [ -d $sap_path/$DBPORT/$HOSTNAME/trace/DB_$SOURCETENANTDBSID ]
  then
    mv $sap_path/$DBPORT/$HOSTNAME/trace/DB_$SOURCETENANTDBSID $sap_path/$DBPORT/$HOSTNAME/trace/DB_$SOURCETENANTDBSID_act_old_$$
    mkdir $sap_path/$DBPORT/$HOSTNAME/trace/DB_$TARGETTENANTDBSID
    chown $HANAuser:sapsys $sap_path/$DBPORT/$HOSTNAME/trace/DB_$TARGETTENANTDBSID
fi

#rename tenant

SQL_RENAME_TENANT=`echo "RENAME DATABASE $SOURCETENANTDBSID TO $TARGETTENANTDBSID;"`
RENAME_TENANTDB=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_RENAME_TENANT\""`

#Starting the tenant database

SQL_START_TGT_TENANT=`echo "ALTER SYSTEM START DATABASE $TARGETTENANTDBSID ;"`
START_TGT_TENANT=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_START_TGT_TENANT\"" &`

SQL_CHECK_TENANT_STATE=`echo "SELECT ACTIVE_STATUS from \"PUBLIC\".\"M_DATABASES\" where DATABASE_NAME='$TARGETTENANTDBSID'"`
TENANT_IS_UP=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_TENANT_STATE\""`

echo "INFO: Tenant $SOURCETENANTDBSID active status : $TENANT_IS_UP"

  if [[ X$TENANT_IS_UP == XYES ]]
  then

    until [[ X$TENANT_IS_UP != XYES ]]
    do
      sleep 5

      TENANT_IS_UP=`su - "$HANAuser" bash -c "$hdbsql -U $HANADBKEY -a -j -x \"$SQL_CHECK_TENANT_STATE\""`
      echo "INFO: Tenant $TARGETTENANTDBSID is not yet up please wait"
    done
  fi



