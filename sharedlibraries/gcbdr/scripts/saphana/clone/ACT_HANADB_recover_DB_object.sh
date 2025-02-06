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

echo ""
echo "     AA          CCCCC  TTTTTTTT  IIIIII  FFFFFFF IIIIII      OOOO     /-\\"
echo "    AAAA       CC          TT       II    FF        II      OO    OO   |R|"
echo "   AA  AA     CC           TT       II    FFFF      II     OOO    OOO  \_/"
echo "  AAAAAAAA    CC           TT       II    FF        II     OOO    OOO"
echo " AAA    AAA    CC          TT       II    FF        II      OO    OO"
echo "AAAA    AAAA     CCCCC     TT     IIIIII  FF      IIIIII      OOOO "
echo ""


DBSIDSOURCE=${1}
TARGETSERVER=${2}
DBSIDTARGET=${3}
SOURCEKEY=${4}
TARGETKEY=${5}
OBJECT_TYPE=${6}
DUMP_DIR=${7}
TARGET_DUMP_DIR=${8}
SOURCE_SCHEMA_NAME=${9}
TARGET_SCHEMA_NAME=${10}
SOURCE_OBJECT_NAME=${11}
TARGET_OBJECT_NAME=${12}


LOCAL_HOST=`ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "echo ${HOSTNAME%%.*}"`
if [[ $TARGETSERVER == $LOCAL_HOST ]]
then if [[ $DUMP_DIR == $TARGET_DUMP_DIR ]]
     then echo "ERRMSG: Source and target dump directories are identical"
     exit 1
     fi
fi

if [[ "X$DBSIDSOURCE" != "X" ]]
then
length=`expr length "$DBSIDSOURCE"`
if [[ "$length" != 3 ]]
then
echo "invalid argument for Source SID"
exit 0
fi
fi

if [[ "X$DBSIDTARGET" != "X" ]]
then
length=`expr length "$DBSIDSOURCE"`
if [[ "$length" != 3 ]]
then
echo "invalid argument for Target SID"
exit 0
fi
fi

DBSIDSourcelow=`echo "$DBSIDSOURCE" | awk '{print tolower($0)}'`
DBSIDSourceupper=`echo "$DBSIDSOURCE" | awk '{print toupper($0)}'`
HANAuserSource=`echo "$DBSIDSourcelow""adm"`

if id "$HANAuserSource" >/dev/null 2>&1
 then echo "user $HANAuserSource exists"
else echo "user $HANAuserSource does not exist"
 exit 0
fi

DBSIDTargetlow=`echo "$DBSIDTARGET" | awk '{print tolower($0)}'`
DBSIDTargetupper=`echo "$DBSIDTARGET" | awk '{print toupper($0)}'`
HANAuserTarget=`echo "$DBSIDTargetlow""adm"`

if ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "id \"$HANAuserTarget\" >/dev/null 2>&1"
 then echo "user $HANAuserTarget exists"
else echo "user $HANAuserTarget does not exist"
 exit 0
fi


CHECK_KEY_VALID=`su - "$HANAuserSource" bash -c "hdbuserstore list  $DBUSER | grep ENV"`
if [[ X$CHECK_KEY_VALID == X ]]
then echo "ERRMSG: The userstore key is invalid for source System"
exit 1
fi

CHECK_KEY_VALIDTARGET=`ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"hdbuserstore list  $DBUSER | grep ENV\""`
if [[ X$CHECK_KEY_VALIDTARGET == X ]]
then echo "ERRMSG: The userstore key is invalid for Target System"
exit 1
fi

globalpathSource=`su - $HANAuserSource -c 'echo $DIR_INSTANCE'`
globalpathSource=`dirname $globalpathSource`
globalinipathSource=$globalpathSource/SYS/global/hdb/custom/config/global.ini
SSLENFORCEsource=`grep "sslenforce" $globalpathSource/SYS/global/hdb/custom/config/global.ini`
SSLENFORCEsource=`echo $SSLENFORCEsource | awk -F "=" '{print $2}'|xargs`
exepath=$globalpathSource/SYS/exe/hdb

if [ "$SSLENFORCEsource" = "true" ]; then
   hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsql="hdbsql"
fi

globalpathTarget=`ssh $TARGETSERVER "su - $HANAuserTarget -c 'echo \\$DIR_INSTANCE'"`
globalpathTarget=`dirname $globalpathTarget`
globalinipathTarget=$globalpathTarget/SYS/global/hdb/custom/config/global.ini
SSLENFORCETarget=`ssh $TARGETSERVER "grep \"sslenforce\" $globalpathTarget/SYS/global/hdb/custom/config/global.ini"`
SSLENFORCETarget=`echo $SSLENFORCETarget | awk -F "=" '{print $2}'|xargs`
exepathTarget=$globalpathTarget/SYS/exe/hdb

if [ "$SSLENFORCETarget" = "true" ]; then
   hdbsqltarget="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
else
   hdbsqltarget="hdbsql"
fi


if [ $OBJECT_TYPE != SCHEMA ] && [ $OBJECT_TYPE != TABLE ]
then echo "ERRORMSG: Invalid Object Type should be SCHEMA or TABLE"
exit 1
fi

if [[ X$DUMP_DIR == X ]]
then echo "ERRMSG: The Dump export directory is not specified"
exit 1
fi

NUMBER_OF_THREAD=`nproc`
NUMBER_OF_THREAD=`expr $NUMBER_OF_THREAD / 3`

NUMBER_OF_THREAD_TARGET=`ssh $TARGETSERVER "nproc"`
NUMBER_OF_THREAD_TARGET=`expr $NUMBER_OF_THREAD_TARGET / 3`

if [ $OBJECT_TYPE == SCHEMA ]
then echo "EXPORT $SOURCE_SCHEMA_NAME."*" AS BINARY INTO '/$DUMP_DIR' WITH REPLACE THREADS $NUMBER_OF_THREAD"
su - "$HANAuserSource" bash -c "$exepath/$hdbsql -U $SOURCEKEY -x \"EXPORT $SOURCE_SCHEMA_NAME.\\\"*\\\" AS BINARY INTO '$DUMP_DIR' WITH REPLACE THREADS $NUMBER_OF_THREAD\""
    if [[ $SOURCE_SCHEMA_NAME != $TARGET_SCHEMA_NAME ]]
    then
    chown -R $HANAuserSource:sapsys $DUMP_DIR
    mv $DUMP_DIR/export/$SOURCE_SCHEMA_NAME $DUMP_DIR/export/$TARGET_SCHEMA_NAME
    sed -i  "s/\"$SOURCE_SCHEMA_NAME\".\"/\"$TARGET_SCHEMA_NAME\".\"/g" $DUMP_DIR/export/$TARGET_SCHEMA_NAME/*/*/control
    sed -i  "s/\"$SOURCE_SCHEMA_NAME\".\"/\"$TARGET_SCHEMA_NAME\".\"/g" $DUMP_DIR/export/$TARGET_SCHEMA_NAME/*/*/create.sql
    scp -pr $DUMP_DIR $TARGETSERVER:$TARGET_DUMP_DIR
    ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "chown -R \"$HANAuserTarget\":sapsys $TARGET_DUMP_DIR"

      SQL_SCHEMA_EXISTANCE=`echo "\\\\\"select SCHEMA_NAME from schemas where SCHEMA_NAME='$TARGET_SCHEMA_NAME'\\\\\""`
   echo $SQL_SCHEMA_EXISTANCE
      IS_SCHEMA_EXIST=`ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"$exepathTarget/$hdbsqltarget -U $TARGETKEY -x $SQL_SCHEMA_EXISTANCE \" | tail -n 1 "`
      if [ X$IS_SCHEMA_EXIST != X\"$TARGET_SCHEMA_NAME\" ]
      then ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"$exepathTarget/$hdbsqltarget -U $TARGETKEY -x \\\"CREATE SCHEMA $TARGET_SCHEMA_NAME\\\" \" "
      fi
    fi
    ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"$exepathTarget/$hdbsqltarget -U $TARGETKEY -x \\\"IMPORT \\\\\\\"$TARGET_SCHEMA_NAME\\\\\\\".\\\\\\\"*\\\\\\\" AS BINARY FROM '$TARGET_DUMP_DIR/export' WITH REPLACE THREADS $NUMBER_OF_THREAD_TARGET\\\" \" "
fi


if [ $OBJECT_TYPE == TABLE ]
then TARGET_OBJECT_NAME=$SOURCE_OBJECT_NAME

var=`echo $SOURCE_OBJECT_NAME`

  for tablename in $(echo $var | sed "s/,/ /g")
    do
    mkdir $DUMP_DIR/$tablename
    chown -R $HANAuserSource:sapsys $DUMP_DIR/$tablename
    su - "$HANAuserSource" bash -c "$exepath/$hdbsql -U $SOURCEKEY -x \"EXPORT $SOURCE_SCHEMA_NAME.\\\"$tablename\\\" AS BINARY INTO '$DUMP_DIR/$tablename' WITH REPLACE THREADS $NUMBER_OF_THREAD\""

    if [[ $SOURCE_SCHEMA_NAME != $TARGET_SCHEMA_NAME ]]
    then
    mkdir $DUMP_DIR/$tablename/export/$TARGET_SCHEMA_NAME
    chown -R $HANAuserSource:sapsys $DUMP_DIR/$tablename
    mv $DUMP_DIR/$tablename/export/$SOURCE_SCHEMA_NAME/* $DUMP_DIR/$tablename/export/$TARGET_SCHEMA_NAME
    sed -i  "s/\"$SOURCE_SCHEMA_NAME\".\"$tablename\"/\"$TARGET_SCHEMA_NAME\".\"$tablename\"/g" $DUMP_DIR/$tablename/export/$TARGET_SCHEMA_NAME/*/$tablename/control
    sed -i  "s/\"$SOURCE_SCHEMA_NAME\".\"$tablename\"/\"$TARGET_SCHEMA_NAME\".\"$tablename\"/g" $DUMP_DIR/$tablename/export/$TARGET_SCHEMA_NAME/*/$tablename/create.sql
    scp -pr $DUMP_DIR/$tablename $TARGETSERVER:$TARGET_DUMP_DIR/$tablename
    ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "chown -R \"$HANAuserTarget\":sapsys $TARGET_DUMP_DIR/$tablename"
    ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"$exepathTarget/$hdbsqltarget -U $TARGETKEY -x \\\"IMPORT $TARGET_SCHEMA_NAME.\\\"$tablename\\\" AS BINARY FROM '$TARGET_DUMP_DIR/$tablename' WITH REPLACE THREADS $NUMBER_OF_THREAD_TARGET\\\" \" "
    else
   scp -pr $DUMP_DIR/$tablename $TARGETSERVER:$TARGET_DUMP_DIR/$tablename
   ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "chown -R \"$HANAuserTarget\":sapsys $TARGET_DUMP_DIR/$tablename"
    ssh -o "StrictHostKeyChecking=no" $TARGETSERVER "su - \"$HANAuserTarget\" bash -c \"$exepathTarget/$hdbsqltarget -U $TARGETKEY -x \\\"IMPORT $TARGET_SCHEMA_NAME.\\\"$tablename\\\" AS BINARY FROM '$TARGET_DUMP_DIR/$tablename' WITH REPLACE THREADS $NUMBER_OF_THREAD_TARGET\\\" \" "
    fi

    done
fi

if [[ X$DUMP_DIR != X ]]
then
rm -rf $DUMP_DIR/export $TARGET_DUMP_DIR/export
fi
