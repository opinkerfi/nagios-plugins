declare @dbname varchar(255)
declare @check_mssql_health_USER varchar(255)
declare @check_mssql_health_ROLE varchar(255)

SET @check_mssql_health_USER = '"[Servername|Domainname]\Username"'
SET @check_mssql_health_ROLE = 'Rolename'

declare dblist cursor for
  select name from sysdatabases WHERE name NOT IN ('master', 'tempdb', 'msdb') open dblist
    fetch next from dblist into @dbname
    while @@fetch_status = 0 begin
      EXEC ('USE ' + @dbname + ' print ''Revoke permissions in the db '' + ''"'' + DB_NAME() + ''"''')
      EXEC ('USE ' + @dbname + ' EXEC sp_droprolemember ' + @check_mssql_health_ROLE + ' , ' + @check_mssql_health_USER)
      EXEC ('USE ' + @dbname + ' DROP USER ' + @check_mssql_health_USER)               
      EXEC ('USE ' + @dbname + ' REVOKE VIEW DEFINITION TO ' + @check_mssql_health_ROLE)
      EXEC ('USE ' + @dbname + ' REVOKE VIEW DATABASE STATE TO ' + @check_mssql_health_ROLE)
      EXEC ('USE ' + @dbname + ' REVOKE EXECUTE TO ' + @check_mssql_health_ROLE)
      EXEC ('USE ' + @dbname + ' DROP ROLE ' + @check_mssql_health_ROLE)
      EXEC ('USE ' + @dbname + ' print ''Permissions in the db '' + ''"'' + DB_NAME() + ''" revoked.''')
      fetch next from dblist into @dbname
    end
close dblist
deallocate dblist

PRINT ''
PRINT 'drop Nagios plugin user ' + @check_mssql_health_USER
EXEC ('USE MASTER REVOKE VIEW SERVER STATE TO ' + @check_mssql_health_USER)
EXEC ('DROP LOGIN ' + @check_mssql_health_USER)
PRINT 'User ' + @check_mssql_health_USER + ' dropped.'

