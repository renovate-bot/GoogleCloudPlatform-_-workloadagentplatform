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

copy_userstorekey_files()
{
  backupconfigfilespath=$1
  cp $backupconfigfilespath/$JOBID/SSFS_HDB.DAT__* $HDBKEY_LOCATION/SSFS_HDB.DAT
  cp $backupconfigfilespath/$JOBID/SSFS_HDB.KEY__* $HDBKEY_LOCATION/SSFS_HDB.KEY
  chown $osuser:sapsys $HDBKEY_LOCATION/SSFS_HDB.DAT
  chown $osuser:sapsys $HDBKEY_LOCATION/SSFS_HDB.KEY
}



preflight_check_userstorekey()
{
   dbusername=$1
   dbuserpassword=$2
   userstorekey=$3
   portno=$4


   if [ -z "$userstorekey" ]; then
      if [  -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
         echo "ERRORMSG: Database username and password or hdbuserstore key is required to continue!"
         preflight_message "Verify hdbuserstore key, Failed, Database username and password or hdbuserstore key are required"
      fi
   fi

   if [ ! -z "$userstorekey" ]; then
      #### USECASE when username and password are empty but userstorekey is passed
      if [ -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
         su - $osuser -c "hdbuserstore list $userstorekey"
         if [ "$?" -gt 0 ]; then
            echo "ERRORMSG: Unable to find the USERSTORE KEY:$userstorekey!"
            preflight_message "Verify hdbuserstore key, Failed, Unable to find hdbuserstore key $userstorekey on target server"
         else
            #### Check the ENV matches with hostname ###
            userstorekeyhost=`su - $osuser -c "hdbuserstore list $userstorekey| grep -w ENV"`
            userstorekeyport=`echo $userstorekeyhost | awk -F":" '{print $3}' |xargs`
            userstorekeyhost=`echo $userstorekeyhost | awk -F":" '{print $2}' |xargs`
            physicalhostname=`hostname`
            if [[ ! "$userstorekeyhost" =~ "$physicalhostname" ]] && [[ ! "$userstorekeyhost" =~ "$localhostname" ]]; then
               echo "WARNINGMSG: hdbuserstore key - $userstorekey passed does not have valid hostname configured!"
               #preflight_message "verify hdbuserstore key, Failed, $userstorekey passed does not have valid hostname configured"
            elif [ $userstorekeyport != $portno ]; then
                 echo "ERRORMSG: hdbuserstore key - $userstorekey passed does not have valid port# configured!"
                 preflight_message "Verify hdbuserstore key, Failed, $userstorekey passed does not have valid port# configured. Expected $portno configured $userstorekeyport."
            else
               preflight_message "Verify hdbuserstore key, OK, "
            fi
         fi
      fi
   fi
}

preflight_check_tenant_userstorekey()
{
   dbusername=$1
   set +x
   dbuserpassword=$2
   set -x
   userstorekey=$3
   portno=$4
   set +x
   if [ -z "$userstorekey" ]; then
      if [  -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
         echo "ERRORMSG: Database username and password or USERSTORE KEY is required to continue!"
         preflight_message "Verify USERSTORE KEY, Failed, Database username and password or USERSTORE KEY are required"
      fi
   fi

   if [ ! -z "$userstorekey" ]; then
      if [ -z "$dbusername" ] && [ -z "$dbuserpassword" ]; then
         su - $osuser -c "hdbuserstore list $userstorekey"
         if [ "$?" -gt 0 ]; then
            echo "ERRORMSG: Unable to find the USERSTORE KEY:$userstorekey!"
            preflight_message "Verify USERSTORE KEY for Tenant DB, Failed, Unable to find USERSTOREKEY $userstorekey"
         else
            #### Check the ENV matches with hostname ###
            userstorekeyhost=`su - $osuser -c "hdbuserstore list $userstorekey| grep -w ENV"`
            userstorekeyport=`echo $userstorekeyhost | awk -F":" '{print $3}' |xargs`
            userstorekeyhost=`echo $userstorekeyhost | awk -F":" '{print $2}' |xargs`
            physicalhostname=`hostname`
            if [[ ! "$userstorekeyhost" =~ "$physicalhostname" ]] && [[ ! "$userstorekeyhost" =~ "$localhostname" ]]; then
               echo "WARNINGMSG: USERSTORE KEY - $userstorekey passed does not have valid hostname configured!"
               #preflight_message "verify USERSTORE KEY for Tenant DB, Failed, $userstorekey passed does not have valid hostname configured"
            elif [ $userstorekeyport != $portno ]; then
                echo "ERRORMSG: USERSTORE KEY - $userstorekey passed does not have valid port# configured!"
                preflight_message "Verify USERSTORE KEY for Tenant DB, Failed, $userstorekey passed does not have valid port# configured"
            else
               preflight_message "Verify USERSTORE KEY for Tenant DB, OK, "
            fi
         fi
      fi
   fi
}

update_userstorekey()
{
   dbusername=$1
   dbuserpassword=$2
   userstorekey=$3
   portno=$4
   backupconfigfilespath=$5

   if [ -z "$userstorekey" ]; then
      if [  -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
         echo "ERRORMSG: Database username and password or USERSTORE KEY is required to continue!"
         exit 1
      fi
   fi

   #### USECASE when username, password and userstorekey is not empty
   if [ ! -z "$userstorekey" ]; then
      if [ ! -z "$dbusername" ] && [ ! -z  "$dbuserpassword" ]; then
         if [ "$NODE_TYPE" = "newtarget" ]; then
            su - $osuser -c "hdbuserstore list $userstorekey"
            if [ "$?" -gt 0 ]; then
               echo "DELETE_USERSTOREKEY=YES" >/act/touch/."$osuser"_userstorekey
            fi
            su - $osuser -c "hdbuserstore set $userstorekey $localhostname:$portno $dbusername $dbuserpassword"
         elif [ "$NODE_TYPE" = "source" ]; then
             copy_userstorekey_files $backupconfigfilespath
             su - $osuser -c "hdbuserstore list $userstorekey"
             if [ "$?" -gt 0 ]; then
                if [ ! -d /act/touch ]; then
                   mkdir -p /act/touch
                fi
                echo "DELETE_USERSTOREKEY=YES" >/act/touch/."$osuser"_userstorekey
             fi
             su - $osuser -c "hdbuserstore set $userstorekey $localhostname:$portno $dbusername $dbuserpassword"
         fi
   #### USECASE when username and password are empty but userstorekey is passed
      elif [ -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
          if [ "$NODE_TYPE" = "source" ]; then
             copy_userstorekey_files $backupconfigfilespath
             su - $osuser -c "hdbuserstore list $userstorekey"
             if [ "$?" -gt 0 ]; then
                echo "ERRORMSG: Unable to find the USERSTORE KEY:$userstorekey!"
                exit 1
             fi
          elif [ "$NODE_TYPE" = "newtarget" ]; then
               su - $osuser -c "hdbuserstore list $userstorekey"
               if [ "$?" -gt 0 ]; then
                  echo "ERRORMSG: Unable to find the USERSTORE KEY:$userstorekey!"
                  exit 1
               else
                  #### Check the ENV matches with hostname ###
                  userstorekeyhost=`su - $osuser -c "hdbuserstore list $userstorekey| grep -w ENV"`
                  userstorekeyport=`echo $userstorekeyhost | awk -F":" '{print $3}' |xargs`
                  userstorekeyhost=`echo $userstorekeyhost | awk -F":" '{print $2}' |xargs`
                  physicalhostname=`hostname`
                  if [ "$userstorekeyhost" != "$physicalhostname" ] && [ "$userstorekeyhost" != "$localhostname" ]; then
                     echo "WARNINGMSG: USERSTORE KEY - $userstorekey passed does not have valid hostname configured!"
                  fi
                  if [ $userstorekeyport != $portno ]; then
                     echo "ERRORMSG: USERSTORE KEY - $userstorekey passed does not have valid port# configured!"
                     exit 1
                  fi
               fi
          fi
      fi
   fi
}


check_connection()
{
   KEY=$1
   TDBSID=$2
   echo "***** CHECKING DB CONNECTION for $TDBSID *****"
   SQL="select database_name from m_databases"
   dbnames=`su - $osuser -c "$hdbsql -U $KEY -a -j -x $SQL"`
   if [ "$?" -gt 0 ]; then
      echo "ERRORMSG: Unable to connect to the database $TDBSID using $KEY!"
      exit 1
    else
      if [ "$HANAVERSION" != "1.0" ]; then
       if [ "$TDBSID" != "SYSTEMDB" ]; then
        echo "checking the database name from m_databases"
        dbcheck=`echo $dbnames | grep $TDBSID | grep -v SYSTEMDB`
        if [ -z $dbcheck ]; then
           echo "ERRORMSG: Unable to connect to the database $TDBSID using $KEY!"
           exit 1
        fi
       fi
      fi
   fi
}

check_recovery_privs()
{
   KEY=$1
   TDBSID=$2

   echo "***** CHECKING DB PRIVILEGES for $TDBSID *****"
   DATABASE_USER=`su - $osuser -c "hdbuserstore list $KEY | grep -w USER"`
   DATABASE_USER=`echo $DATABASE_USER | awk -F":" '{print $2}' |xargs`
   DATABASE_USER=`echo $DATABASE_USER | tr '[a-z]' '[A-Z]'`

   SQL="select count(*) from PUBLIC.EFFECTIVE_PRIVILEGES where USER_NAME = '$DATABASE_USER' and PRIVILEGE in ('DATABASE RECOVERY OPERATOR','DATABASE START', 'DATABASE STOP')"
   echo $SQL
   PRIV_COUNT=`su - $osuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
   if [ $PRIV_COUNT -lt 3 ]; then
      SQL="select count(*) from PUBLIC.EFFECTIVE_PRIVILEGES where USER_NAME = '$DATABASE_USER' and PRIVILEGE in ('DATABASE ADMIN')"
      PRIV_COUNT=`su - $osuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
      if [ $PRIV_COUNT -lt 1 ]; then
         echo "ERRORMSG: Userstore key $KEY do not have required privileges (DATABASE RECOVERY OPERATOR or DATABASE ADMIN)  on database $TDBSID, Please check!"
         exit 1
      fi
   fi
}



waitforhdbnameserver() {
  #Set a timeout of 8 minutes (8*6*10)
  HANAVERSION=$1
  DBADM=$2
  DBUSER=$3

  FAIL_MSG=/tmp/.error_$DBADM.out
  globalpath=`echo $DIR_INSTANCE`
  globalpath=`dirname $globalpath`
  passwordexpirycnt=1
  SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
  SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
  SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

  if [ "$SSLENFORCE" = "true" ]; then
     hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
  else
     hdbsql="hdbsql"
  fi
  if [ -f $FAIL_MSG ]; then
     rm -f $FAIL_MSG
  fi

  HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
  waitFlag=true
  timeout=0
  count=30
  if [ "$HANAVERSION" = "1.0" ] || [ "$HANAVERSION_TMP" -lt "20000" ]; then
     count=90
  fi
  while $waitFlag; do
    timeout=$((timeout+1))
    if [ $timeout -gt $count ]; then
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
         SQL="select database_name from m_databases"
         set -o pipefail
         $hdbsql -U $DBUSER -j -x $SQL 2>&1 | tee $FAIL_MSG
         if [ "$?" -gt 0 ]; then
            auth_errorstring_cnt=`cat $FAIL_MSG | grep -i "authentication failed" | wc -l`
            license_errorstring_cnt=`cat $FAIL_MSG | grep -i "license handling" | wc -l`
            passwordexpired=`cat $FAIL_MSG | grep -i "user is forced to change password" | wc -l`
            if [ "$auth_errorstring_cnt" -gt 0 ]; then
               errorstring=`cat $FAIL_MSG`
               echo "ERRORMSG: Unable to get Tenant database names due to Authentication Error(invalid username and password). Please check the logs for details. ERROR:$errorstring"
               exit 1
            elif [ "$license_errorstring_cnt" -gt 0 ]; then
                 errorstring=`cat $FAIL_MSG`
                 echo "ERRORMSG: Unable to get Tenant database names due to Invalid License. Ensure source image has permanent license.(Refer SAP License requirements). Please check the logs for details. ERROR:$errorstring"
                 exit 1
            elif [ "$passwordexpired" -gt 0 ]; then
                 if [ $passwordexpirycnt -gt 6 ]; then
                    errorstring=`cat $FAIL_MSG`
                    echo "ERRORMSG: Unable to get Tenant database names due to the error: $errorstring, Please check the logs for details"
                    exit 1
                 else
                    echo "Unable to get Tenant database names due to the error: $errorstring, Please reset the password, if not job will fail in 3 mins!"
                    passwordexpirycnt=$(($passwordexpirycnt+1))
                 fi
            fi
         fi
         dbnames=`$hdbsql -U $DBUSER -x "select database_name from m_databases"`
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
  if [ -f $FAIL_MSG ]; then
     rm -f $FAIL_MSG
  fi
  return 0
}

check_version()
{
   sourceversion=$1
   osuser=$2

   len=${#sourceversion}

   TARGET_HVERSION=`su - $osuser -c "HDB version | grep -i version: | cut -d':' -f2 |xargs"`
   TARGET_HVERSION=`echo $TARGET_HVERSION | cut -c1-$len`

   TARGET_HVERSIONTMP=`echo $TARGET_HVERSION |sed 's/\.//g'`
   SOURCE_HVERSIONTMP=`echo $sourceversion |sed 's/\.//g'`

   if [ "$TARGET_HVERSIONTMP" -lt "$SOURCE_HVERSIONTMP" ] || [ "$sourceversion" != "$TARGET_HVERSION" ]; then
      echo " Target HANA Version ($TARGET_HVERSION)  is less than Source HANA Version ($SOURCE_HVERSION)!"
      exit 1
   fi

}
preflight_check_version()
{
   sourceversion=$1
   osuser=$2

   len=${#sourceversion}

   TARGET_HVERSION=`su - $osuser -c "HDB version | grep -i version: | cut -d':' -f2 |xargs"`
   TARGET_HVERSION=`echo $TARGET_HVERSION | cut -c1-$len`

   TARGET_HVERSIONTMP=`echo $TARGET_HVERSION |sed 's/\.//g'`
   SOURCE_HVERSIONTMP=`echo $sourceversion |sed 's/\.//g'`

   if [ "$TARGET_HVERSIONTMP" -lt "$SOURCE_HVERSIONTMP" ] || [ "$sourceversion" != "$TARGET_HVERSION" ]; then
      echo " Target HANA Version ($TARGET_HVERSION)  is less than Source HANA Version ($SOURCE_HVERSION)!"
      preflight_message "Verify HANA Version, Failed, Target HANA Version ($TARGET_HVERSION)  is less than Source HANA Version ($SOURCE_HVERSION). Target HANA version is required to be equal to or greater than the source version"
   else
      preflight_message "Verify HANA Version, OK, Target HANA Version ($TARGET_HVERSION)  is equal or greater than Source HANA Version ($SOURCE_HVERSION)"
   fi

}

################# PREFLIGHT Function to validate node role #######################
preflight_node_role_validation()
{
  role=`cat $globalpath/SYS/global/hdb/custom/config/global.ini |grep -E "actual_mode =|actual_mode=" |awk -F"=" '{print $2}' |xargs`
  clusternodecount=0
  if [ ! -z "$role" ]; then
     clusternodecount=`su - $osuser -c "hdbnsutil -sr_state | awk '/Site Mappings:/{f=0} f; /Host Mappings:/{f=2}' |awk -F"]" '{print \\$2}' |xargs |wc -w"`
  fi
  if [ "$role" != "primary" ] && [ ! -z "$role" ]; then
     if [ "$clusternodecount" -ge 1 ] || [ ! -z "$role" ]; then
        echo "ERRORMSG: Target server is Replication enabled secondary node with 1 or more primary or secondary site(s) attached. Please run hdbnsutil -sr_unregister command on all secondary to unregister the secondary sites to proceed with restore."
        preflight_message "Verify Node Status, Failed, Target server is Replication enabled secondary node with 1 or more primary or secondary site(s) attached. Please run hdbnsutil -sr_unregister command on all secondary to unregister the secondary sites to proceed with restore"
     fi
  elif [ "$role" = "primary" ] && [ "$clusternodecount" -gt 1 ]; then
       echo "ERRORMSG: Target server is Replication enabled cluster with 1 or more secondary site(s) attached. Please run hdbnsutil -sr_unregister/sr_takeover command on secondary nodes to unregister the secondary sites to proceed with restore."
       preflight_message "Verify Node Status, Failed, Target server is Replication enabled cluster with 1 or more secondary site(s) attached. Please run hdbnsutil -sr_unregister/sr_takeover command on secondary nodes to unregister the secondary sites to proceed with restore"
  else
      preflight_message "Verify Node Status, OK, "
  fi
}

################# PRERESTORE Function to validate node role and take necessary actions #######################
node_role_validation()
{
  role=`cat $globalpath/SYS/global/hdb/custom/config/global.ini |grep -E "actual_mode =|actual_mode=" |awk -F"=" '{print $2}' |xargs`
  clusternodecount=0
  if [ ! -z "$role" ]; then
     clusternodecount=`su - $osuser -c "hdbnsutil -sr_state | awk '/Site Mappings:/{f=0} f; /Host Mappings:/{f=2}' |awk -F"]" '{print \\$2}' |xargs |wc -w"`
  fi
  if [ "$role" != "primary" ] && [ ! -z "$role" ]; then
     if [ "$clusternodecount" -ge 1 ]; then
        echo "Running unregister command as the selected target is secondary node!"
        su - $osuser -c "hdbnsutil -sr_unregister"
        if [ "$?" -gt 0 ]; then
           echo "WARNINGMSG: Ungregister command has warnings! Proceeding with Restore..."
        fi
     fi
  elif [ "$role" = "primary" ] && [ "$clusternodecount" -gt 1 ]; then
       echo "Running unregister command as the selected target node is with one or more secondary sites attached!"
       su - $osuser -c "hdbnsutil -sr_disable"
       if [ "$?" -gt 0 ]; then
          echo "WARNINGMSG: Disabling replication has warnings! Proceeding with Restore...!"
       fi
  fi
}

preflight_backint_validation()
{
  globalpath=$1
  SOURCE_BACKINT=$2

  if [ ! -z "$SOURCE_BACKINT" ] && [ $SOURCE_BACKINT = "TRUE" ] || [ "$CUSTOMAPP_BACKUPTYPE" = "CustomAppDBBackup" ]; then
     bint=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -iw catalog_backup_using_backint | grep -i true`
     if [ -z "$bint" ]; then
         if [ "$CUSTOMAPP_BACKUPTYPE" = "CustomAppDBBackup" ]; then
            echo "The target server is not configured with backint backup configuration. Restore will proceed"
            preflight_message "Verify no  Backint is configured, OK, "
         else
            echo "The target server is not configured with backint backup configuration. configure the target server with backint configuration to run the restore."
            preflight_message "Verify Backint configuration: The target server is not configured with backint. Backint will be configured during restore, OK, The target server is not configured with backint backup configuration"
         fi
     else
         if [ "$CUSTOMAPP_BACKUPTYPE" = "CustomAppDBBackup" ]; then
            preflight_message "Verify Backint configuration, Failed, The target server should not have backint configured. Please remove all the backint related entries from $globalpath/SYS/global/hdb/custom/config/global.ini file "
         else
            preflight_message "Verify Backint configuration, OK, "
         fi
     fi
  fi
}

backint_config_validation()
{
  HANABACKUPPATH=$1
  osuser=$2
  globalpath=$3
  SOURCE_BACKINT=$4
  if [ ! -z "$SOURCE_BACKINT" ] && [ $SOURCE_BACKINT = "true" ]; then
      bint=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -iw catalog_backup_using_backint | grep -i true`
      if [ -z "$bint" ]; then
         echo "The target server is not configured with backint backup configuration. configure the target server with backint configuration to run the restore."
         nameserverini=$globalpath/SYS/global/hdb/custom/config/nameserver.ini
         localhostname=`cat $nameserverini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`
         cp $HANABACKUPPATH/INI/global.ini* $globalpath/SYS/global/hdb/custom/config/global.ini
         chown "$osuser":"sapsys" $globalpath/SYS/global/hdb/custom/config/global.ini
         SAPSYSTEMNAME=`su - "$osuser" bash -c 'echo $SAPSYSTEMNAME'`
         BACKUPLOGDIR=`grep -wi "^basepath_logbackup" /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/custom/config/global.ini |awk -F"=" '{print $2}' | xargs`
         SERVERS_NODE=`cat $nameserverini | grep roles_ | cut -d'=' -f-1 | cut -c7- | xargs`

         echo "Backint will be installed on this server(s) node(s) : "
         echo "$SERVERS_NODE"

         NUMBER_OF_NODE=`echo "$SERVERS_NODE" | wc -l`

         if [[ $NUMBER_OF_NODE == 0 ]]; then
            echo "ERRORMSG -- The server node is not detected - abort"
            exit 1
         else
            if [[ ! -d /act/custom_apps/saphana/backintlog ]]; then
               mkdir /act/custom_apps/saphana/backintlog
            else
               echo "directory /act/custom_apps/saphana/backintlog already exist"
            fi
         fi
         chown "$osuser":"sapsys" /act/custom_apps/saphana/backintlog
         chown "$osuser":"sapsys" /act/custom_apps/saphana/sapbackint/Bfunction
         chown "$osuser":"sapsys" /act/custom_apps/saphana/sapbackint/Rfunction
         chown "$osuser":"sapsys" /act/custom_apps/saphana/sapbackint/backint

         chmod +x /act/custom_apps/saphana/sapbackint/Bfunction
         chmod +x /act/custom_apps/saphana/sapbackint/Rfunction
         chmod +x /act/custom_apps/saphana/sapbackint/backint

         echo "export DB_BACKUP_PATH="$BACKUPLOGDIR"" > /act/custom_apps/saphana/sapbackint/actifio_backint.par
         echo "export DB_BACKUP_PATH="$BACKUPLOGDIR"" > /act/custom_apps/saphana/sapbackint/actifio_backint_log.par
         echo "export BS=10M" >> /act/custom_apps/saphana/sapbackint/actifio_backint_log.par
         chown $osuser:sapsys /act/custom_apps/saphana/sapbackint/actifio_backint_log.par
         chown $osuser:sapsys /act/custom_apps/saphana/sapbackint/actifio_backint.par

         if [ ! -d /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt ]; then
             su - "$osuser" -c "mkdir -p /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt"
         fi

         if [[ ! -f /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/hdbbackint ]]; then
            su - "$osuser" -c "ln -s /act/custom_apps/saphana/sapbackint/backint /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/hdbbackint"
        else
            echo "link /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/hdbbackint already exist"
        fi

        if [[ ! -f /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint.par ]]; then
           su - "$osuser" -c "ln -s /act/custom_apps/saphana/sapbackint/actifio_backint.par /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint.par"
        else
           echo "link /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint.par already exist"
        fi

        if [[ ! -f /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint_log.par ]]; then
           su - "$osuser" -c "ln -s /act/custom_apps/saphana/sapbackint/actifio_backint_log.par /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint_log.par"
        else
           echo "link /usr/sap/$SAPSYSTEMNAME/SYS/global/hdb/opt/actifio_backint_log.par already exist"
        fi
        bint1=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -iw catalog_backup_using_backint | grep -i true`
        if [ ! -z "$bint1" ]; then
           echo "backint configuration is completed on target server"
        fi
    fi
 fi
}

################# PREFLIGHT Function to validate Log Backup path #######################
preflight_validate_logbackup_path()
{
  tdate=`date +"%m%d%Y%H%M"`

  locallogbackup_path=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_logbackup =|basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`

  if [ -z $locallogbackup_path ]; then
     echo "ERRORMSG:Logbackup path $locallogbackup_path does not exists. Please set the logbackup path to proceed!"
     preflight_message "Verify Log Backup Path, Failed, basepath_logbackup path $locallogbackup_pathis not set in $globalpath/SYS/global/hdb/custom/config/global.ini. Please set the basepath_logbackup path to proceed"
  elif [ ! -d $locallogbackup_path ]; then
       preflight_message "Verify Log Backup Path, Failed, basepath_logbackup directory $locallogbackup_path does not exist. Please create the directory to proceed."
  else
     preflight_message "Verify Log Backup Path, OK, "
  fi
}

################# PRERESTORE Function to validate Log Backup path and take necessary actions #######################
validate_logbackup_path()
{
  backupconfigfilespath=$1
  tdate=`date +"%m%d%Y%H%M"`

  locallogbackup_path=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_logbackup =|basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`
  sourcelogbackup_path=`cat $backupconfigfilespath/$JOBID/global.ini* | grep -E "basepath_logbackup =|basepath_logbackup=" | awk -F"=" '{print $2}' |xargs`
  cp $globalpath/SYS/global/hdb/custom/config/global.ini $globalpath/SYS/global/hdb/custom/config/global.ini."$tdate"
  chown $osuser:sapsys $globalpath/SYS/global/hdb/custom/config/global.ini."$tdate"
  if [ ! -d $locallogbackup_path ] && [ ! -d $sourcelogbackup_path ]; then
     echo "ERRORMSG: Logbackup path $sourcelogbackup_path does not exists. Please set the logbackup path to proceed!"
     exit 1
  elif [ -d  $sourcelogbackup_path ]; then
       echo "Source logbackup path $sourcelogbackup_path exists, using the same in global.ini"
       cp $backupconfigfilespath/$JOBID/global.ini* $globalpath/SYS/global/hdb/custom/config/global.ini
       chown $dbsidadm:sapsys $globalpath/SYS/global/hdb/custom/config/global.ini
  elif [ ! -d $sourcelogbackup_path ] && [ -d $locallogbackup_path ]; then
       cp $backupconfigfilespath/$JOBID/global.ini* $globalpath/SYS/global/hdb/custom/config/global.ini
       chown $dbsidadm:sapsys $globalpath/SYS/global/hdb/custom/config/global.ini
       sed -i "/basepath_logbackup/d" $globalpath/SYS/global/hdb/custom/config/global.ini
       sed -i "/basepath_catalogbackup/d" $globalpath/SYS/global/hdb/custom/config/global.ini
       sed -i "/\bpersistence\b/a basepath_logbackup = $locallogbackup_path" $globalpath/SYS/global/hdb/custom/config/global.ini
       sed -i "/\bpersistence\b/a basepath_catalogbackup = $locallogbackup_path" $globalpath/SYS/global/hdb/custom/config/global.ini
  fi

  if [ "$CLUSTERTYPE" = "replication" ]; then
     sed -i '/site_id/d' $globalpath/SYS/global/hdb/custom/config/global.ini
     sed -i '/site_name/d' $globalpath/SYS/global/hdb/custom/config/global.ini
  fi
}

update_tenant_userstorekey()
{
  dbusername=$1
  set +x
  dbuserpassword=$2
  set -x
  userstorekey=$3
  portno=$4
  set +x
  if [ -z "$userstorekey" ]; then
     if [  -z "$dbusername" ] || [ -z "$dbuserpassword" ]; then
          echo "ERRORMSG: Database username and password or USERSTORE KEY is required to continue!"
          exit 1
     fi
  fi

 #### USECASE when username, password and USERSTOREKEY is not empty
  if [ ! -z "$userstorekey" ]; then
     if [ ! -z "$dbusername" ] && [ ! -z "$dbuserpassword" ]; then
        su - $osuser -c "hdbuserstore set $userstorekey $localhostname:$PORTNO $dbusername $dbuserpassword"
        su - $osuser -c "hdbuserstore list $userstorekey"
        if [ "$?" -gt 0 ]; then
           if [ ! -d /act/touch ]; then
              mkdir -p /act/touch
           fi
           echo "DELETE_USERSTOREKEY=YES" >/act/touch/."$osuser"_userstorekey
        fi
     fi
 #### USECASE when username and password are empty but USERSTOREKEY is passed
     if [ -z "$dbusername" ] || [ -z  "$dbuserpassword" ]; then
        set -x
        su - $osuser -c "hdbuserstore list $userstorekey"
        if [ "$?" -gt 0 ]; then
           echo "ERRORMSG: Unable to find the USERSTORE KEY:$userstorekey!"
           exit 1
        else
            #### Check the ENV matches with hostname ###
            userstorekeyhost=`su - $osuser -c "hdbuserstore list $userstorekey| grep -w ENV"`
            userstorekeyhost=`echo $userstorekeyhost | awk -F":" '{print $2}' |xargs`
            physicalhostname=`hostname`
            if [ "$userstorekeyhost" != "$physicalhostname" ] && [ "$userstorekeyhost" != "$localhostname" ]; then
                echo "WARNINGMSG: USERSTORE KEY - $userstorekey passed does not have valid hostname configured!"
            fi
        fi

     fi
  fi
}

check_global_preflight()
{
  HDBKEY_LOCATION=`su - $osuser -c "hdbuserstore list | grep \"DATA FILE\""`
  HDBKEY_LOCATION=`echo $HDBKEY_LOCATION |awk -F":" '{print $2}' |xargs`
  HDBKEY_LOCATION=`dirname $HDBKEY_LOCATION`
  globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
  globalpath=`dirname $globalpath`
  nameserverini=$globalpath/SYS/global/hdb/custom/config/nameserver.ini

  if [ ! -f $globalpath/SYS/global/hdb/custom/config/global.ini ]; then
     echo "ERRORMSG: Unable to find the global.ini file under $globalpath/SYS/global/hdb/custom/config/. This file is mandatory to continue!"
     preflight_message "Check config file $globalpath/SYS/global/hdb/custom/config/global.ini exists, Failed, config file $globalpath/SYS/global/hdb/custom/config/global.ini does not exists on the target"
  else
     preflight_message "Check config file $globalpath/SYS/global/hdb/custom/config/global.ini exists, OK, "
  fi
}

check_dbsid_preflight()
{
  dbsidexists=`su - $osuser -c 'ls | wc -l'`
  retval=$?
  if [ $retval -ne 0 ]; then
     echo "ERRORMSG: $dbsid is not available, please check!"
     echo"  PRECHECK:Verify database SID, Failed, Database SID $DBSID is not configured on the target server `hostname`. Please configure HANA instance $DBSID on the target using hdblcm tool; PRECHECK:Check config file global.ini exists, Failed, Skipped;PRECHECK:Verify Node Status, Failed,Skipped ;PRECHECK:Verify no  Backint is configured, Failed,Skipped ;PRECHECK:Verify Log Backup Path, Failed, Skipped;PRECHECK:Verify HANA Version, Failed, Skipped;PRECHECK:Verify USERSTORE KEY, Failed, Skipped;  "
     exit 0
  else
     preflight_message "Verify database SID "$(echo $osuser |cut -c1-3)" is available, OK, "
  fi
}

preflight_excludeinclude_check()
{
   USERSTOREKEY=$1
   DBSID=$2
   DBPORT=$3

   globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
   globalpath=`dirname $globalpath`

   SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
   SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
   SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

   if [ "$SSLENFORCE" = "true" ]; then
      hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
   else
      hdbsql="hdbsql"
   fi
   SQL="select database_name from m_databases"
   export DBSID
   export DBPORT
   export USERSTOREKEY
   export hdbsql
   export SQL
   dbnames=`su -m $osuser -c '/usr/sap/$DBSID/$DBPORT/exe/$hdbsql -U $USERSTOREKEY -a -j -x $SQL'`
   dret=$?
   tdblist=""
   if [ "$dret" -gt 0 ]; then
      echo "ERRORMSG: Unable to connect to the database SYSTEMDB using $USERSTOREKEY!"
      tdblist=""
   else
      for j in ${dbnames}; do
         TSID=`echo $j |awk -F '"' '{print $2}'`
         if [ -z "$tdblist" ]; then
            tdblist=$TSID
         else
            tdblist=$tdblist","$TSID
         fi
      done
   fi
   if [ ! -z "$tdblist" ] && [ "$tdblist" != "null" ]; then
      if [ ! -z "$SOURCE_DBLIST" ] && [ "$SOURCE_DBLIST" != "null" ]; then
         SDBLIST=`echo $SOURCE_DBLIST | tr '[a-z]' '[A-Z]'`
         OIFS=$IFS
         IFS=','
         sdbnamelist=$SDBLIST
         db_not_target_list=""
         db_not_source_list=""
         for k in $sdbnamelist; do
            db_tcheck=`echo $tdblist | grep -iw $k`
            if [ -z "$db_tcheck" ]; then
               echo "Source DB name $k does not exists in the target DB list"
               db_source_check="failed"
               if [ -z "$db_source_check" ]; then
                  db_not_source_list=$k
               else
                   db_not_source_list=$db_not_source_list":"$k
               fi
            else
               echo "Source DB name $k does not exists in the target DB list"
            fi
         done
         IFS=$OIFS
         TDBLIST=`echo $tdblist | tr '[a-z]' '[A-Z]'`
         OIFS=$IFS
         IFS=','
         tdbnamelist=$TDBLIST
         db_exclude_source_target_failed_list=""
         for t in $tdbnamelist; do
            db_stcheck=`echo $SDBLIST | grep -iw $t`
            if [ -z "$db_stcheck" ]; then
               if [ ! -z "$RESTORE_EXCLUDEDBLIST" ] && [ "$RESTORE_EXCLUDEDBLIST" != "null" ]; then
                  DB_LIST=`echo $RESTORE_EXCLUDEDBLIST | tr '[a-z]' '[A-Z]'`
                  dbnotin_source_exclude_list=`echo $DB_LIST | grep -iw $t`
                  if [ -z "$dbnotin_source_exclude_list" ]; then
                     db_exclude_source_target="failed"
                     if [ -z "$db_exclude_source_target_failed_list" ]; then
                        db_exclude_source_target_failed_list=$t
                     else
                        db_exclude_source_target_failed_list=$db_exclude_source_target_failed_list":"$t
                     fi
                  else
                     echo "Target DB name $db_exclude_source_target_failed_list exists in the source database list and also exists in the exclude list"
                  fi
               fi
            fi
         done
         IFS=$OIFS
      fi
   else
      SDBLIST=`echo $SOURCE_DBLIST | tr '[a-z]' '[A-Z]'`
      stdblist=$SDBLIST
   fi
   if [ ! -z "$RESTORE_EXCLUDEDBLIST" ] && [ "$RESTORE_EXCLUDEDBLIST" != "null" ]; then
      if [ "$db_source_check" != "failed" ]; then
         DB_LIST=`echo $RESTORE_EXCLUDEDBLIST | tr '[a-z]' '[A-Z]'`
         OIFS=$IFS
         IFS=','
         dbnamelist=$DB_LIST
         db_exclude_sfailed_list=""
         db_exclude_failed_list=""
         db_exclude_target_failed_list=""
         for i in $dbnamelist; do
            if [ ! -z "$SOURCE_DBLIST" ] && [ "$SOURCE_DBLIST" != "null" ]; then
               SDBLIST=`echo $SOURCE_DBLIST | tr '[a-z]' '[A-Z]'`
               db_source_check=`echo $SDBLIST | grep -iw $i`
            fi
            if [ -z "$db_source_check" ]; then
               if [ ! -z "$tdblist" ] && [ "$tdblist" != "null" ]; then
                  exclude_db_not_in_target_list=`echo $tdblist |  grep -iw $i`
                  if [ -z "$exclude_db_not_in_target_list" ]; then
                     excludedb_not_in_source_target="failed"
                     if [ -z "$db_exclude_target_failed_list" ]; then
                        db_exclude_target_failed_list=$i
                     else
                        db_exclude_target_failed_list=$db_exclude_target_failed_list":"$i
                     fi
                  else
                     echo "DB name $i from the Exclude DB list exists in the target DB list"
                  fi
               fi
            fi
            if [ -z "$db_source_check" ]; then
               echo "DB name $i from the Exclude DB list does not exists in the target DB list"
               db_exclude_scheck="failed"
               if [ -z "$db_exclude_failed_list" ]; then
                  db_exclude_sfailed_list=$i
               else
                  db_exclude_sfailed_list=$db_exclude_sfailed_list":"$i
               fi
            else
               echo "DB name $i from the Exclude DB list exists in the source DB list"
            fi
         done
         IFS=$OIFS
         if [ ! -z "$db_exclude_scheck" ]  && [ ! -z "$excludedb_not_in_source_target" ]; then
            echo "preflight for exclude db list failed"
            preflight_message "Verify Exclude DB list, Failed, Database name list $db_exclude_sfailed_list does not exists in the source and target  DB list"
         elif  [ ! -z "$db_exclude_scheck" ]  && [ -z "$tdblist" ]; then
            echo "preflight for exclude db list failed"
            preflight_message "Verify Exclude DB list, Failed, Database name list $db_exclude_sfailed_list does not exists in the source DB list"
         elif [ ! -z "$db_exclude_source_target" ]; then
            preflight_message "Verify Exclude DB list, Failed, Database name list $db_exclude_source_target_failed_list does not exists in the source DB list and also does not exists in the Exclude DB list"
         else
            preflight_message "Verify Exclude DB list, OK, "
         fi
      else
         preflight_message "Verify Exclude DB list, Failed, source DB list does not match with the target DB list"
      fi
   elif [ ! -z "$RESTORE_INCLUDEDBLIST" ] && [ "$RESTORE_INCLUDEDBLIST" != "null" ]; then
      DB_LIST=`echo $RESTORE_INCLUDEDBLIST | tr '[a-z]' '[A-Z]'`
      OIFS=$IFS
      IFS=','
      dbnamelist=$DB_LIST
      sdb_include_failed_list=""
      tdb_include_failed_list=""
      for i in $dbnamelist; do
         if [ ! -z "$SOURCE_DBLIST" ] && [ "$SOURCE_DBLIST" != "null" ]; then
            SDBLIST=`echo $SOURCE_DBLIST | tr '[a-z]' '[A-Z]'`
            sdb_check=`echo $SDBLIST | grep -iw $i`
         fi
         if [ ! -z "$tdblist" ] && [ "$tdblist" != "null" ]; then
            tdb_check=`echo $tdblist | grep -iw $i`
         fi
         if [ -z "$sdb_check" ]; then
            echo "DB name $i from the Include DB list does not exists in the source DB list"
            sdb_include_check="failed"
            if [ -z "$sdb_include_failed_list" ]; then
               sdb_include_failed_list=$i
            else
               sdb_include_failed_list=$sdb_include_failed_list":"$i
            fi
         else
            echo "DB name $i from the Include DB does exists in the source DB list"
         fi
         if [ -z "$tdb_check" ] && [ ! -z "$tdblist" ] && [ "$tdblist" != "null" ]; then
            echo "DB name $i from the Include DB list does not exists in the target DB list"
            tdb_include_check="failed"
            if [ -z "$tdb_include_failed_list" ]; then
               tdb_include_failed_list=$i
            else
               tdb_include_failed_list=$tdb_include_failed_list":"$i
            fi
         else
            echo "DB name $i from the Include DB does exists in the target DB list"
         fi
      done
      IFS=$OIFS
      if [ ! -z "$sdb_include_check" ] &&  [ ! -z "$tdb_include_check" ]; then
         echo "preflight for include db list failed"
         preflight_message "Verify Include DB list, Failed, Database name list $sdb_include_failed_list:$tdb_include_failed_list does not exists in the source and target DB list"
      elif [ ! -z "$sdb_include_check" ] &&  [  -z "$tdb_include_check" ]; then
         preflight_message "Verify Include DB list, Failed, Database name list $sdb_include_failed_list does not exists in the source DB list"
      elif [ -z "$sdb_include_check" ] &&  [ ! -z "$tdb_include_check" ]; then
         preflight_message "Verify Include DB list, Failed, Database name list $tdb_include_failed_list does not exists in the target DB list"
      else
         preflight_message "Verify Include DB list, OK, "
      fi
   else
      DB_LIST="null"
      echo "preflight check skipped as exclude and include db lists are empty"
   fi
   unset DBSID
   unset DBPORT
   unset USERSTOREKEY
   unset hdbsql
   unset SQL
}

preflight_check_connection()
{
   KEY=$1
   TDBSID=$2
   export KEY
   export TDBSID
   hdbse=`su - $osuser -c 'echo $DIR_INSTANCE'`
   globalpath=`su - $osuser -c 'echo $DIR_INSTANCE'`
   globalpath=`dirname $globalpath`

   SSLENFORCE=`grep "sslenforce" $globalpath/SYS/global/hdb/custom/config/global.ini`
   SSLENFORCE=`echo $SSLENFORCE | awk -F "=" '{print $2}'|xargs`
   SSLENFORCE=`echo $SSLENFORCE | tr '[A-Z]' '[a-z]'`

   export hdbse
   if [ "$SSLENFORCE" = "true" ]; then
      hdbsql="hdbsql -e -sslprovider commoncrypto -sslkeystore $SECUDIR/sapsrv.pse -ssltruststore $SECUDIR/sapsrv.pse"
   else
      hdbsql="hdbsql"
   fi
   export hdbsql
   echo "***** CHECKING DB CONNECTION for $TDBSID *****"
   SQL="select database_name from m_databases"
   export SQL
   dbnames=`su -m $osuser -c "$hdbse/exe/$hdbsql -U $KEY -a -j -x $SQL"`
   if [ "$?" -gt 0 ]; then
      echo "ERRORMSG: Unable to connect to the database $TDBSID using $KEY!"
      preflight_message "Verify SYSTEMDB connection, Failed, Target HANA SYSTEMDB connection failed to perform Tenant DB restore"
   else
      preflight_message "Verify SYSTEMDB connection, OK, "
   fi
   unset KEY
   unset TDBSID
   unset hdbsql
   unset SQL
   unset hdbse
}

################### Function to append preflight error message ####################

preflight_message()
{
  set +x
  str="$1"
  if [ -z "$preflight_status" ]; then
     preflight_status='PRECHECK:'"$str"
  else
     preflight_status="$preflight_status"';PRECHECK:'"$str"
  fi
  set -x
}

process_multi_logmounts()
{
  LOGMOUNT=$1
  LOGBACKUPFILES=/act/touch/.logbackups_$DBSID.txt
  PRIM_LOGMOUNT=`echo $LOGMOUNT | awk -F"," '{print $1}'`
  if [ ! -z $LOGMOUNT ]; then
     for logbkp_mnt in $(echo $LOGMOUNT | tr ',' ' ')
     do
       if [ "$logbkp_mnt" = "$PRIM_LOGMOUNT" ]; then
          continue;
       else
          DBFOLDER_LIST=`ls -l $logbkp_mnt | grep '^d' | awk '{print $NF}' | xargs`
          for foldername in ${DBFOLDER_LIST}
          do
           ls $logbkp_mnt/$foldername/ > $LOGBACKUPFILES
           if [ ! -d  $PRIM_LOGMOUNT/$foldername ]; then
              mkdir -p $PRIM_LOGMOUNT/$foldername
           fi
           while read line
           do
             if [ ! -f $PRIM_LOGMOUNT/$foldername/$line ]; then
              ln -s $logbkp_mnt/$foldername/$line $PRIM_LOGMOUNT/$foldername/$line
             fi
           done < $LOGBACKUPFILES
          done
       fi
     done
  fi
  if [ -f $LOGBACKUPFILES ]; then
     rm -f $LOGBACKUPFILES
  fi
}

###################### Function to check data and log Status ################
preflight_check_data_log_details()
{
  BASEPATH_DATAVOL=$1
  BASEPATH_LOGVOL=$2

  TGT_BASEPATH_DATAVOL=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_datavolumes =|basepath_datavolumes=" | awk -F"=" '{print $2}' |xargs`
  TGT_BASEPATH_LOGVOL=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep -E "basepath_logvolumes =|basepath_logvolumes=" | awk -F"=" '{print $2}' |xargs`
  if [ "$BASEPATH_DATAVOL" != "$TGT_BASEPATH_DATAVOL" ] && [ "$BASEPATH_LOGVOL" != "$TGT_BASEPATH_LOGVOL" ]; then
     PATHLIST="Source basepath_datavolumes & baspath_logvolumes ($BASEPATH_DATAVOL & $BASEPATH_LOGVOL) is not same as target basepath_datavolumes & baspath_logvolumes ($TGT_BASEPATH_DATAVOL & $TGT_BASEPATH_LOGVOL) defined in global.ini. It will be updated with source basepath_datavolmes & basepath_logvolumes."
  elif [ "$BASEPATH_DATAVOL" != "$TGT_BASEPATH_DATAVOL" ]; then
       PATHLIST="Source basepath_datavolumes ($BASEPATH_DATAVOL) is not same as target basepath_datavolumes ($TGT_BASEPATH_DATAVOL) defined in global.ini. It will be updated with source basepath_datavolumes."
  elif [ "$BASEPATH_LOGVOL" != "$TGT_BASEPATH_LOGVOL" ]; then
       PATHLIST="Source basepath_logvolumes ($BASEPATH_LOGVOL) is not same as target baspath_logvolumes ($TGT_BASEPATH_LOGVOL) defined in global.ini. It will be udpdated with source basepath_logvolumes."
  fi
  if [ ! -z "$PATHLIST" ]; then
      preflight_message "Verify Data & Log Volume Details: $PATHLIST, OK,"
  else
      preflight_message "Verify Data & Log Volume Details,OK,"
  fi
}
#=================== Added for PD Snapshot ======================================
################### Function to check the database sid ############################

backup_checkdbsid()
{
  dbsid=$1
  dbsidstatus=`ls /usr/sap | grep -iw $dbsid |grep -v grep |wc -l `
  if [ "$dbsidstatus" -gt 0 ]; then
     return 0
  else
     return 1
  fi
}

################### Function to check userstoreky presence ####################
backup_check_userstorekey()
{
  userstorekey=$1
  dbuser=$2
  su - $dbuser -c "hdbuserstore list $userstorekey" >/dev/null 2>&1
  if [ "$?" -gt 0 ]; then
     return 1
  else
     return 0
  fi
}

################### Function to validate database connenction #################
backup_check_connection()
{
   KEY=$1
   TDBSID=$2
   portno=$3
   FAIL_MSG=$4
   echo "***** CHECKING DB CONNECTION for $TDBSID *****"
   SQL="select database_name from m_databases"
   set -o pipefail
   dbnames=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x $SQL" 2>&1 | tee $FAIL_MSG/"$DBSID"_prepare_error_msg`
   if [ "$?" -gt 0 ]; then
      errorstring=`cat $FAIL_MSG/"$DBSID"_prepare_error_msg`
      echo "ERRORMSG: Backup Pre Check: Unable to connect to the database $TDBSID using hdbuserstore key $KEY!. $errorstring"
      if [ -d $FAIL_MSG ] && [ ! -z $FAIL_MSG ] && [ $FAIL_MSG != "/" ]; then
         rm -f $FAIL_MSG/*
      fi
      exit 1
   else
      KEYHOST=`su - $dbuser -c "hdbuserstore list $KEY | grep -w ENV"`
      KEYPORT=`echo $KEYHOST | awk -F":" '{print $3}' |xargs`
      KEYHOST=`echo $KEYHOST | awk -F":" '{print $2}' |xargs`
      nameserverini=$globalpath/SYS/global/hdb/custom/config/nameserver.ini
      localhostname=`cat $nameserverini |grep -E "worker =|worker=" | awk -F"=" '{print $2}' |xargs`
      phostname=`hostname`
      if [[ ! "$KEYHOST" =~ "$phostname" ]] && [[ ! "$KEYHOST" =~ "$localhostname" ]]; then
         echo "WARNINGMSG: Backup Pre Check: hdbuserstore key $KEY - hostname $KEYHOST is not a valid hostname!"
      elif [ $KEYPORT != $portno ]; then
         echo "ERRORMSG: Backup Pre Check: hdbuserstore key - $KEY does not have valid port# configured, expected port $portno, configured port $KEYPORT"
         exit 1
      fi
   fi
}

################### Function to validate backup user privs #################
backup_check_privs()
{
  KEY=$1
  TDBSID=$2
  ADMIN_PRIV="DATABASE ADMIN"

  echo "***** CHECKING DB PRIVILEGES for $TDBSID *****"
  DATABASE_USER=`su - $dbuser -c "hdbuserstore list $KEY | grep -w USER"`
  DATABASE_USER=`echo $DATABASE_USER | awk -F":" '{print $2}' |xargs`
  DATABASE_USER=`echo $DATABASE_USER | tr '[a-z]' '[A-Z]'`
  OLD_IFS="$IFS"
  IFS=','
  SQL="select string_agg(privilege,',' order by privilege) from PUBLIC.EFFECTIVE_PRIVILEGES where USER_NAME = '$DATABASE_USER' and PRIVILEGE in ('BACKUP ADMIN', 'CATALOG READ', 'DATABASE RECOVERY OPERATOR','DATABASE BACKUP OPERATOR', 'DATABASE START', 'DATABASE STOP','DATABASE ADMIN')"
  REQUIRED_PRIVS_LIST="BACKUP ADMIN,CATALOG READ,DATABASE BACKUP OPERATOR"
  OPTIONAL_PRIVS_LIST="DATABASE RECOVERY OPERATOR,DATABASE START,DATABASE STOP"
  GRANTED_PRIV_LIST=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
  GRANTED_PRIV_LIST=`echo "$GRANTED_PRIV_LIST" |sed 's/\"//g'`
  set +x
  for r_priv in ${REQUIRED_PRIVS_LIST}
  do
    for g_priv in ${GRANTED_PRIV_LIST}
    do
      if [ "$r_priv" = "$g_priv" ]; then
         granted=true;
         break;
      fi
    done
    if [ "$granted" = "true" ]; then
       if [ -z "$ASSIGNED_PRIVS" ]; then
          ASSIGNED_PRIVS=$r_priv
       else
          ASSIGNED_PRIVS=$ASSIGNED_PRIVS','$r_priv
       fi
    else
       if [ -z "$MISSED_PRIVS" ]; then
          MISSED_PRIVS=$r_priv
       else
          MISSED_PRIVS=$MISSED_PRIVS','$r_priv
       fi
    fi
    granted=
  done
  set -x
  ADMIN_PRIV_GRANTED=`echo $GRANTED_PRIV_LIST |grep -i "$ADMIN_PRIV"`
  if [ ! -z "$MISSED_PRIVS" ]; then
     if [ -z "$ADMIN_PRIV_GRANTED" ]; then
          echo "ERRORMSG: Backup Pre Check: hdbuserstore key $KEY has only $ASSIGNED_PRIVS privileges. Missing privileges are $MISSED_PRIVS"
          exit 1
     fi
  else
     if [ -z "$ADMIN_PRIV_GRANTED" ]; then
        set +x
        for o_priv in ${OPTIONAL_PRIVS_LIST}
        do
          OPTIONAL_GRANTED=`echo $GRANTED_PRIV_LIST | grep -i "$o_priv"`
          if [ -z "$OPTIONAL_GRANTED" ]; then
             if [ -z "$MISSED_OPTIONAL_PRIVS" ]; then
                MISSED_OPTIONAL_PRIVS=$o_priv
             else
                MISSED_OPTIONAL_PRIVS="$MISSED_OPTIONAL_PRIVS"','"$o_priv"
             fi
          fi
          OPTIONAL_GRANTED=
        done
        set -x
        if [ ! -z "$MISSED_OPTIONAL_PRIVS" ]; then
           echo "WARNINGMSG: Backup Pre Check: hdbuserstore key $KEY is missing ($MISSED_OPTIONAL_PRIVS) privileges required to recover the databases."
        fi
     fi
  fi
  IFS="$OLD_IFS"
}

################### Function to check savepoint #################
backup_check_snapshot()
{
  KEY=$1

  SQL="SELECT string_agg(backup_id,',' order by backup_id) from M_BACKUP_CATALOG WHERE ENTRY_TYPE_NAME = 'data snapshot' and STATE_NAME = 'prepared' and SYS_END_TIME is null"
  SAVEPOINT_ID=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
  SAVEPOINT_ID=`echo $SAVEPOINT_ID |sed 's/"//g'`
  if [ ! -z $SAVEPOINT_ID ]; then
     echo "ERRORMSG: Backup Pre Check: There is already a snapshot (ID:$SAVEPOINT_ID)  present in the prepared state. Please cleanup the same to continue with the backup!"
     exit 1
  fi
}

################### Function to check backint config #################
backup_backint_check()
{
   KEY=$1
   SQL="select database_name from m_databases"
   dbnames=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
   dret=$?
   if [ "$dret" -gt 0 ]; then
      echo "ERRORMSG: Backup Pre Check: Unable to connect to the database SYSTEMDB using $KEY!"
   else
      dbnames=`echo $dbnames |xargs |sed 's/"//g'`
      for j in ${dbnames}; do
         bint=""
         TSID=$j
         if [ $TSID = "SYSTEMDB" ]; then
            bintsql="select value from SYS_DATABASES.M_INIFILE_CONTENTS where SECTION = 'backup' and layer_name = 'SYSTEM' and KEY = 'catalog_backup_using_backint'"
         else
            bintsql="select distinct value from SYS_DATABASES.M_INIFILE_CONTENTS where SECTION = 'backup' and layer_name = 'DATABASE' and DATABASE_NAME= '$TSID' and KEY = 'catalog_backup_using_backint'"
         fi
         HANAVERSION_TMP=`echo $HANAVERSION |sed 's/\.//g'`
         if [ "$HANAVERSION_TMP" -gt "200000" ]; then
            binten=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x \"$bintsql\""`
            binten=`echo $binten | sed 's/"//g'`
            if [ ! -z "$binten" ] && [ "$binten" = "true" ]; then
               echo "ERRORMSG: Backup Pre Check: The target server should not have backint configured. Please remove all the backint related parameters of $TSID database "
               exit 1
            fi
         fi
      done
   fi
}

###################### Function to check HANA Database Status ################
preflight_check_database_status()
{
  INSTANCENUM=`su - $osuser -c 'env | grep TINSTANCE= | cut -d"=" -f2'`
  if [ -z "$INSTANCENUM" ]; then
      INSTANCENUM=`su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
  fi
  if [ ! -z "$INSTANCENUM" ]; then
     HANA_STATUS=`su - $osuser -c "sapcontrol -nr $INSTANCENUM -function GetProcessList | grep -E 'GREEN|YELLOW|RED' | grep -v grep |wc -l"`
    if [ "$HANA_STATUS" -gt 0 ]; then
       preflight_message "Verify Database Status, Failed, HANA Database is up and running. Please stop to proceed with restore."
    else
       preflight_message "Verify Database Status, OK, "
    fi
  fi

}

###################### Function to check VG exists ################
check_vg_exists()
{
  VGNAME=$1
  EXISTS="$(vgs --noheadings -o vg_name | grep -w $VGNAME |grep -v grep 2>/dev/null)"
  echo "$EXISTS"
}

###################### Function to deactivate VG################
disable_vg()
{
  VGNAME=$1
  echo "Deactivating VG $VGNAME"
  errmsg="$(vgchange -an $VGNAME 2>&1)"
  if [[ "$?" -gt 0 ]]; then
     echo "ERRORMSG: Unable to deactivate $VGNAME.Error: $errmsg"
     exit 1
  fi
}

###################### Function to activate VG################
enable_vg()
{
  VGNAME=$1
  echo "Activating VG $VGNAME"
  errmsg="$(vgchange -ay $VGNAME 2>&1)"
  retval=$?
  if [[ "$retval" -ne 0 ]] && [[ "$retval" -ne 5 ]]; then
     echo "ERRORMSG: Unable to deactivate $VGNAME.Error: $errmsg"
     exit 1
  fi
}

###################### Function to mount file system ################
mount_mountpt()
{
  MNTPT=$1
  VGNAME=$2
  LVNAME=$3
  if [[ ! -d $MNTPT ]]; then
     echo "INFO: Mount directory $MNTPT does not exist. Creating $MNTPT"
     mkdir -p $MNTPT
     if [[ ! -z "$MNTPT" ]] && [[ "$MNTPT" != "/" ]]; then
        chown $osuser:sapsys $MNTPT
     fi
  fi
  ISMOUNTED="$(grep -w $MNTPT /proc/mounts |uniq)"
  if [[ ! -z "$ISMOUNTED" ]]; then
     echo "INFO: Mount point is already mounted"
  else
     mount -o nouuid /dev/mapper/"$VGNAME"-"$LVNAME" $MNTPT
     ISMOUNTED="$(grep -w $MNTPT /proc/mounts |uniq)"
     if [[ ! -z "$ISMOUNTED" ]]; then
         echo "INFO: Mounted $MNTPT successfully"
     else
        echo "INFO: Reloading daemon as normal mount command did not mount $MNTPT"
        vgchange --refresh $VGNAME
        mount -o nouuid /dev/mapper/"$VGNAME"-"$LVNAME" $MNTPT
        ISMOUNTED="$(grep -w $MNTPT /proc/mounts |uniq)"
        if [[ -z "$ISMOUNTED" ]]; then
           echo "ERRORMSG: Unable to mount $MNTPT even after reloading services"
           exit 1
        else
           echo "INFO: Mounted $MNTPT successfully"
        fi
     fi
  fi
}


############## Function to unmount volumes ##############
unmount_mountpt()
{
  MNTPT=$1
  count=0
  timeout=12
  echo "Check if mount $MNTPT is mounted"
  ISMOUNTED="$(grep -w $MNTPT /proc/mounts |awk '{print $1}')"
  if [[ ! -z "$ISMOUNTED" ]]; then
     CHECK_PROCESSES="$(fuser -c -u $MNTPT)"
     if [[ ! -z "$CHECK_PROCESSES" ]]; then
        echo "WARNINGMSG: Mount point $MNTPT is currently in use by ($CHECK_PROCESSES), retrying in 5 seconds."
        while [ $count -lt $timeout ]
        do
          sleep 5
          count="$(($count+1))"
          CHECK_PROCESSES="$(fuser -c -u $MNTPT)"
          if [[ ! -z "$CHECK_PROCESSES" ]]; then
             echo "WARNINGMSG: Mount point $MNTPT is currently in use by ($CHECK_PROCESSES), retrying in 5 seconds."
          else
             umount $MNTPT 2> /dev/null;
             break;
          fi
          if [[ "$count" -eq $(($timeout-1)) ]]; then
              echo "ERRORMSG: Unable to unmount $MNTPT as it is currently in use. $CHECK_PROCESSES"
              exit 1
          fi
        done
     else
        umount $MNTPT 2> /dev/null;
        echo "INFO: Unmounted $MNTPT successfully."
     fi
  else
     echo "INFO: $MNTPT was already unmounted."
  fi
  if [[ -d "$MNTPT" ]]; then
     rmdir $MNTPT
  fi
}

######################### Function check the mount points ####################
preflight_check_mountpoint_exists()
{
  DATAMNT=$1
  LOGMNT=$2
  LOGBACKUPMNT=$3

  MOUNT_LIST=
  if [[ ! -z "$DATAMNT" ]]; then
     ISDATAMOUNTED="$(grep -w $DATAMNT /proc/mounts |awk '{print $1}')"
  fi
  if [[ ! -z "$LOGMNT" ]]; then
     ISLOGMOUNTED="$(grep -w $LOGMNT /proc/mounts |awk '{print $1}')"
  fi
  if [[ ! -z "$LOGBACKUPMNT" ]]; then
     ISLOGBACKUPMOUNTED="$(grep -w $LOGBACKUPMNT /proc/mounts |awk '{print $1}')"
  fi

  if [[ ! -z "$ISDATAMOUNTED" ]]; then
     MOUNT_LIST=$DATAMNT
  fi
  if [[ ! -z "$ISLOGMOUNTED" ]]; then
      if [[ -z "$MOUNT_LIST" ]]; then
          MOUNT_LIST=$LOGMNT
      else
         MOUNT_LIST=$MOUNT_LIST':'$LOGMNT
      fi
  fi
  if [[ ! -z "$ISLOGBACKUPMOUNTED" ]]; then
      if [[ -z "$MOUNT_LIST" ]]; then
          MOUNT_LIST=$LOGBACKUPMNT
      else
         MOUNT_LIST=$MOUNT_LIST':'$LOGBACKUPMNT
      fi
  fi

  if [[ ! -z "$MOUNT_LIST" ]]; then
     preflight_message "Verify Mount point Status, Failed, The mount point(s) <$MOUNT_LIST> mounted on the host. Please unmount them to proceed."
  else
     preflight_message "Verify Mount point Status, OK, "
  fi
}

######################### Function check the mount points ####################
preflight_check_vgname_exists()
{
  DATA_VGNAME=$1
  LOG_VGNAME=$2
  LOGBACKUP_VGNAME=$3

  VGNAME_LIST=
  VGEXISTS="$(check_vg_exists $DATA_VGNAME)"
  if [[ ! -z "$VGEXISTS" ]]; then
     VGNAME_LIST=$DATA_VGNAME
  fi

  if [[ "$DATA_VGNAME" != "$LOG_VGNAME" ]]; then
     VGEXISTS=
     VGEXISTS="$(check_vg_exists $LOG_VGNAME)"
     if [[ ! -z "$VGEXISTS" ]]; then
        if [[ -z "$VGNAME_LIST" ]]; then
           VGNAME_LIST=$LOG_VGNAME
        else
           VGNAME_LIST=$VGNAME_LIST':'$LOG_VGNAME
        fi
     fi
  fi
  VGEXISTS=
  VGEXISTS="$(check_vg_exists $LOGBACKUP_VGNAME)"
  if [[ ! -z "$VGEXISTS" ]]; then
     if [[ -z "$VGNAME_LIST" ]]; then
        VGNAME_LIST=$LOGBACKUP_VGNAME
     else
        VGNAME_LIST=$VGNAME_LIST':'$LOGBACKUP_VGNAME
     fi
  fi
  if [[ ! -z "$VGNAME_LIST" ]]; then
     preflight_message "Verify Volume Group, Failed, The Volume group(s) <$VGNAME_LIST> exists on the host. Please remove them to proceed."
  else
     preflight_message "Verify Volume Group, OK, "
  fi
}


######################### Function to check target hana version ####################
preflight_check_target_version()
{
   sourceversion=$1
   osuser=$2

   len=${#sourceversion}

   TARGET_HVERSION=`su - $osuser -c "HDB version | grep -i version: | cut -d':' -f2 |xargs"`
   TARGET_HVERSION=`echo $TARGET_HVERSION | cut -c1-8`

   TARGET_HVERSIONTMP=`echo $TARGET_HVERSION |sed 's/\.//g'`

   if [[ "$TARGET_HVERSIONTMP" -lt "200050" ]] ; then
      echo " Target HANA Version ($TARGET_HVERSION)  is less than 2.0SP5"
      preflight_message "Verify HANA Version, Failed, Target HANA Version ($TARGET_HVERSION)  is less than 2.00.SP5. Target HANA version is required to be equal to or greater than 2.00.SP5"
   else
      preflight_message "Verify HANA Version, OK, Target HANA Version ($TARGET_HVERSION)  is equal or greater than required HANA Version 2.00.SP5"
   fi
}


######################### Function to get mount point from VGNAME ####################
get_mountpoint()
{
  local VGNAME=$1
  local MNTPT_LIST=
  local LVNAME="$(lvs --noheadings -o lv_name $VGNAME |xargs)"
   if [[ ! -z "$LVNAME" ]]; then
      for lvname in ${LVNAME}
      do
        MNTPT="$(grep '/dev/mapper/'$VGNAME'-'$lvname /proc/mounts |awk '{print $2}')"
        if [[ -z "$MNTPT" ]]; then
           MNTPT="$(grep '/dev/'$VGNAME'/'$lvname /proc/mounts |awk '{print $2}')"
        fi
        if [[ ! -z "$MNTPT" ]]; then
           if [[ -z "$MNTPT_LIST" ]]; then
              MNTPT_LIST=$MNTPT
           else
              MNTPT_LIST=$MNTPT_LIST','$MNTPT
           fi
        fi
      done
   fi
   echo $MNTPT_LIST

}

######################### Function to check if VGNAME is used ####################
preflight_check_vg_status()
{
  set -x
  DATA_VGNAME=$1
  LOG_VGNAME=$2
  LOGBACKUP_VGNAME=$3
  local DBSID=$3
  osuser="$(echo $DBSID | tr '[A-Z]' '[a-z]')"'adm'

  INSTANCENUM="$(su - $osuser -c 'env | grep TINSTANCE= | cut -d'=' -f2')"

  if [[ -z "$INSTANCENUM" ]]; then
     INSTANCENUM="$(su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev')"
  fi

  local DBSID="$(echo $DBSID | tr '[a-z]' '[A-Z]')"
  HANASHARED="$(ls -l /usr/sap/$DBSID/HDB"$INSTANCENUM" | awk -F'->' '{print $2}')"

  CHECK_PROCESS=
  VG_INUSE=
  echo "Checking the variable DATA_VGNAME empty"
  if [[ ! -z "$DATA_VGNAME" ]]; then
     echo "DATA_VGNAME is not empty, checking if it exists"
     DATA_VG_EXISTS="$(check_vg_exists $DATA_VGNAME)"
     if [[ ! -z "$DATA_VG_EXISTS" ]]; then
        echo "DATA_VGNAME:$DATA_VGNAME exists"
        TGT_DATAMNT="$(get_mountpoint $DATA_VGNAME)"
        if [[ ! -z "$TGT_DATAMNT" ]]; then
           for mntpt in $(echo $TGT_DATAMNT | tr ',' ' ')
           do
             CHECK_PROCESS="$(fuser -c -u $mntpt)"
             if [[ ! -z "$CHECK_PROCESS" ]]; then
                echo "DATA_VGNAME:$DATA_VGNAME is in use"
                 VG_INUSE=$DATA_VGNAME
                 break;
             fi
           done
        fi
     fi
  fi

  CHECK_PROCESS=
  if [[ "$DATA_VGNAME" != "$LOG_VGNAME" ]]; then
     echo "Checking the variable LOG_VGNAME empty"
     if [[ ! -z "$LOG_VGNAME" ]]; then
        echo "LOG_VGNAME is not empty, checking if it exists"
        LOG_VG_EXISTS="$(check_vg_exists $LOG_VGNAME)"
        if [[ ! -z "$LOG_VG_EXISTS" ]]; then
           echo "LOG_VGNAME:$LOG_VGNAME exists"
           TGT_LOGMNT="$(get_mountpoint $LOG_VGNAME)"
            if [[ ! -z "$TGT_LOGMNT" ]]; then
               for mntpt in $(echo $TGT_LOGMNT | tr ',' ' ')
               do
                CHECK_PROCESS="$(fuser -c -u $mntpt)"
                if [[ ! -z "$CHECK_PROCESS" ]]; then
                   echo "LOG_VGNAME:$LOG_VGNAME is in use"
                   if [[ -z "$VG_INUSE" ]]; then
                      VG_INUSE=$LOG_VGNAME
                   else
                      VG_INUSE=$VG_INUSE':'$LOG_VGNAME
                   fi
                   break;
                fi
               done
            fi
        fi
     fi
  fi

  if [[ ! -z "$VG_INUSE" ]]; then
     preflight_message "Verify Volume Group, Failed, Volume group $VG_INUSE is in use. Please stop the processes to proceed."
  elif [[ ! -z "$HANASHARED" ]]; then
        HANASHAREDMNTPT="$(df -P $HANASHARED | awk 'NR==2{print $NF}')"
        HANASHARED_LGNAME="$(df $HANASHAREDMNTPT | tail -1 | awk '{ print $1 }')"
        if [[ ! "$HANASHARED_LGNAME" =~ "/dev/sd" ]]; then
           HANASHARED_VGNAME="$(lvdisplay $HANASHARED_LGNAME | grep 'VG Name' | awk '{print $3}')"
        fi
        if [[ "$HANASHARED_VGNAME" == "$DATA_VGNAME" ]] || [[ "$HANASHARED_VGNAME" == "$LOG_VGNAME" ]]; then
           preflight_message "Verify Volume Group, Failed, Volume group for data/log ($DATA_VGNAME) is shared with /hana/shared volume group ($HANASHARED_VGNAME). /hana/shared Volume group should not be shared with /hana/data and /hana/log"
        fi
  fi
  if [[ -z "$VG_INUSE" ]] && [[ "$HANASHARED_VGNAME" != "$DATA_VGNAME" ]] && [[ "$HANASHARED_VGNAME" != "$LOG_VGNAME" ]]; then
     preflight_message "Verify Volume Group, OK, "
  fi

}

######################### Function check if /hana/shared VG is shared with data/log ####################
update_global_file()
{
   DATAPATH=$1
   LOGPATH=$2
   LOGBKPPATH=$3
   BACKUP_METHOD=$4

   globalpath=`su - $dbsidadm -c 'echo $DIR_INSTANCE'`
   globalpath=`dirname $globalpath`

   TENANT_GLOBAL_INI_LIST="$(find $globalpath/SYS/global/hdb/custom/config/DB_* -maxdepth 1 -name global.ini | grep DB_ |xargs)"
   TGT_DATAPATH=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep "basepath_datavolumes" | tail -1 |awk -F"=" '{print $2}' |xargs`
   TGT_LOGPATH=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep "basepath_logvolumes" |tail -1| awk -F"=" '{print $2}' |xargs`
   TGT_LOGBKPPATH=`cat $globalpath/SYS/global/hdb/custom/config/global.ini | grep "basepath_logbackup"|tail -1 | awk -F"=" '{print $2}' |xargs`

   if [ "$TGT_DATAPATH" != "$DATAPATH" ] && [ ! -z "$DATAPATH" ]; then
      echo "Target basepath_datavolumes is not matching to the restored datavolume. Updating the SYSTEMDB global.ini file"
      sed -i '/basepath_datavolumes/d' $globalpath/SYS/global/hdb/custom/config/global.ini
      sed -i "/\bpersistence\b/a basepath_datavolumes = $DATAPATH" $globalpath/SYS/global/hdb/custom/config/global.ini
   fi
   if [ "$TGT_LOGPATH" != "$LOGPATH" ] && [ ! -z "$LOGPATH" ]; then
      echo "Target basepath_logvolumes is not matching to the restored log volume. Updating the SYSTEMDB global.ini file"
      sed -i '/basepath_logvolumes/d' $globalpath/SYS/global/hdb/custom/config/global.ini
      sed -i "/\bpersistence\b/a basepath_logvolumes = $LOGPATH" $globalpath/SYS/global/hdb/custom/config/global.ini
   fi
   if [ "$BACKUP_TYPE" = "PDSNAP" ]; then
      if [ "$TGT_LOGBKPPATH" != "$LOGBKPPATH" ] && [ ! -z "$LOGBKPPATH" ]; then
         echo "Target basepath_logbackup is not matching to the restored log backup location. Updating the SYSTEMDB global.ini file"
         sed -i "/basepath_logbackup/d" $globalpath/SYS/global/hdb/custom/config/global.ini
         sed -i "/basepath_catalogbackup/d" $globalpath/SYS/global/hdb/custom/config/global.ini
         sed -i "/\bpersistence\b/a basepath_catalogbackup = $LOGBKPPATH" $globalpath/SYS/global/hdb/custom/config/global.ini
         sed -i "/\bpersistence\b/a basepath_logbackup = $LOGBKPPATH" $globalpath/SYS/global/hdb/custom/config/global.ini
      fi
   fi

   #### Update tenant global.ini only if the entries found ####
   for globalinifile in ${TENANT_GLOBAL_INI_LIST}
   do
     TGT_DATAPATH=`cat $globalinifile | grep "basepath_datavolumes" | tail -1 |awk -F"=" '{print $2}' |xargs`
     TGT_LOGPATH=`cat $globalinifile | grep "basepath_logvolumes" |tail -1| awk -F"=" '{print $2}' |xargs`
     TGT_LOGBKPPATH=`cat $globalinifile | grep "basepath_logbackup"|tail -1 | awk -F"=" '{print $2}' |xargs`

     if [ "$TGT_DATAPATH" != "$DATAPATH" ] && [ ! -z "$DATAPATH" ] && [ ! -z "$TGT_DATAPATH" ]; then
        echo "Target basepath_datavolumes is not matching to the restored datavolume. Updating file $globalinifile"
        sed -i '/basepath_datavolumes/d' $globalinifile
        sed -i "/\bpersistence\b/a basepath_datavolumes = $DATAPATH" $globalinifile
     fi
     if [ "$TGT_LOGPATH" != "$LOGPATH" ] && [ ! -z "$LOGPATH" ] && [ ! -z "$TGT_LOGPATH" ]; then
        echo "Target basepath_logvolumes is not matching to the restored log volume. Updating $globalinifile"
        sed -i '/basepath_logvolumes/d' $globalinifile
        sed -i "/\bpersistence\b/a basepath_logvolumes = $LOGPATH" $globalinifile
     fi
     if [ "$BACKUP_TYPE" = "PDSNAP" ]; then
        if [ "$TGT_LOGBKPPATH" != "$LOGBKPPATH" ] && [ ! -z "$LOGBKPPATH" ] && [ ! -z "$TGT_LOGBKPPATH" ]; then
           echo "Target basepath_logbackup is not matching to the restored log backup location. Updating $globalinifile"
           sed -i "/basepath_logbackup/d" $globalinifile
           sed -i "/basepath_catalogbackup/d" $globalinifile
           sed -i "/\bpersistence\b/a basepath_catalogbackup = $LOGBKPPATH" $globalinifile
           sed -i "/\bpersistence\b/a basepath_logbackup = $LOGBKPPATH" $globalinifile
        fi
     fi
   done
}

######################### Function to check if data/log is 100% used ####################
backup_check_fs_usage()
{
   local DATAPATH=$1
   local LOGPATH=$2
   local LOGBACKUPPATH=$3
   local USAGELIST=

   if [[ -d "$DATAPATH" ]]; then
      DATAPATHUSAGE="$(df -H $DATAPATH | grep -v "Filesystem" | awk '{print $5}' | cut -d'%' -f1)"
   fi
   if [[ -d "$LOGPATH" ]]; then
      LOGPATHUSAGE="$(df -H $LOGPATH | grep -v "Filesystem" | awk '{print $5}' | cut -d'%' -f1)"
   fi
   if [[ -d "$LOGBACKUPPATH" ]]; then
      LOGBACKUPPATHUSAGE="$(df -H $LOGBACKUPPATH | grep -v "Filesystem" | awk '{print $5}' | cut -d'%' -f1)"
   fi
   if [[ "$DATAPATHUSAGE" -eq 100 ]]; then
      USAGELIST=$DATAPATH
   fi
   if [[ "$LOGPATHUSAGE" -eq 100 ]]; then
      if [[ -z "$USAGELIST" ]]; then
         USAGELIST=$LOGPATH
      else
         USAGELIST=$USAGELIST','$LOGPATH
      fi
   fi
   if [[ "$LOGBACKUPPATHUSAGE" -eq 100 ]]; then
      if [[ -z "$USAGELIST" ]]; then
         USAGELIST=$LOGBACKUPPATH
      else
         USAGELIST=$USAGELIST','$LOGBACKUPPATH
      fi
   fi
   if [[ ! -z "$USAGELIST" ]]; then
      echo "ERRORMSG: Backup Pre Check: The File System usage for $USAGELIST is 100%. Please clear the space and re-run the backup"
      exit 1
   fi
}

######################### Function to check tenant status ####################
backup_check_tenant_status()
{
  KEY=$1
  SQL="SELECT string_agg(database_name,',' order by database_name) from M_DATABASES WHERE ACTIVE_STATUS = 'NO'"
  TENANT_STATUS=`su - $dbuser -c "$hdbsql -U $KEY -a -j -x \"$SQL\""`
  TENANT_STATUS=`echo $TENANT_STATUS |sed 's/"//g'`
  if [[ ! -z "$TENANT_STATUS" ]]; then
     echo "ERRORMSG: Backup Pre Check: Inactive tenant databases found: $TENANT_STATUS. Please start the tenant database and re-run the backup!"
     exit 1
  fi
}


######################### Function to check database status during mount ####################
preflight_check_database_status_mount()
{
  INSTANCENUM=`su - $osuser -c 'env | grep TINSTANCE= | cut -d"=" -f2'`
  if [ -z "$INSTANCENUM" ]; then
      INSTANCENUM=`su - $osuser -c 'basename $DIR_INSTANCE | rev | cut -c 1-2 | rev'`
  fi
  if [ ! -z "$INSTANCENUM" ]; then
     HANA_STATUS=`su - $osuser -c "sapcontrol -nr $INSTANCENUM -function GetProcessList | grep -E 'GREEN|YELLOW|RED' | grep -v grep |wc -l"`
    if [ "$HANA_STATUS" -gt 0 ]; then
       preflight_message "Verify Database Status, Failed, HANA instance "$(echo $osuser|cut -c1-3)" is up and running. Please shutdown the instance as it can corrupt the data."
    else
       preflight_message "Verify Database Status, OK, "
    fi
  fi

}

######################### Function to clone vg ####################
clone_vg()
{
  local VGNAME=$1
  local DEVICENAME_LIST=$2

  local block_dev_list=
  for pdname in $(echo $DEVICENAME_LIST | tr ',' ' ')
  do
    BLOCKDEVICE="$(udevadm info /dev/disk/by-id/google-$pdname | grep -w 'DEVNAME=' |awk -F'=' '{print $2}')"
    if [[ -z "$block_dev_list" ]]; then
       block_dev_list=$BLOCKDEVICE
    else
       block_dev_list="$block_dev_list"' '$BLOCKDEVICE
    fi
  done
  echo "Clonning the VG"
  errmsg="$(vgimportclone --basevgname $VGNAME $block_dev_list 2>&1)"
  if [[ "$?" -gt 0 ]]; then
     echo "ERRORMSG: Error while clonning the VG $VGNAME. Error:$errmsg"
     exit 1
  fi
}

######################### Function to get logical dev/mapper name ####################
get_lgname()
{
  mntpt=$1
  #LGNAME=`grep -w "$mntpt" /proc/mounts | awk '{print $1}'`
  LGNAME=`df "$mntpt" | tail -1 | awk '{ print $1 }'`
  echo $LGNAME
}

######################### Function to get VGNAME ####################
get_vgname()
{
  lgname=$1
  VGNAME=`lvdisplay $lgname | grep "VG Name" | awk '{print $3}'`
  echo $VGNAME
}

######################### Function to get LVNAME ####################
get_lvname()
{
  lgname=$1
  LVNAME=`lvdisplay $lgname | grep "LV Name" | awk '{print $3}'`
  echo $LVNAME
}
