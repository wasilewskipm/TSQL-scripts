
 /*

    Purpose:        List tables from all databases on the server
    Source:         github.com/wasilewskipm/
    Initial code:   2019.10.24
    Comments:

 */


 
------------------------------------------ Configuration ------------------------------------------

 -- Filter data for user defined tables (use 0 for no filter) 
 DECLARE @UserOnly  bit = 1;

 -- Working variables
 DECLARE @DBName    nvarchar(128);

 DECLARE @AllTables table 
 (
     DBName         nvarchar(128),
     SchemaName     nvarchar(128),
     TableName      nvarchar(128)
 );



 ------------------------------------------ Implementation ----------------------------------------

 DECLARE Crs CURSOR
 FOR SELECT QUOTENAME([name])
       FROM sys.databases
      WHERE [state] = 0
            AND database_id > @UserOnly*4;


 OPEN Crs;
 FETCH NEXT FROM Crs INTO @DBName;

 
 WHILE @@FETCH_STATUS = 0
 BEGIN

     INSERT INTO @AllTables (DBName, SchemaName, TableName)
     EXEC ('SELECT PARSENAME(''' + @DBName + ''', 1), s.name, t.name 
              FROM ' + @DBName + '.sys.tables AS t 
                   INNER JOIN sys.schemas AS s
                      ON t.schema_id = s.schema_id;');

     FETCH NEXT FROM Crs INTO @DBName;

 END; -- WHILE @@FETCH_STATUS = 0


 CLOSE Crs;
 DEALLOCATE Crs;


 SELECT * 
   FROM @AllTables
  ORDER BY DBName, SchemaName, TableName;



 ----------------------------------------- Other approaches ---------------------------------------

  /*

  DECLARE @AllTables table 
 (
     DBName      nvarchar(4000),
     SchemaName  nvarchar(4000),
     TableName   nvarchar(4000)
 );


 INSERT INTO @AllTables
   EXEC sp_msforeachdb 'SELECT ''?'', s.name, t.name 
                          FROM [?].sys.tables AS t 
                               INNER JOIN sys.schemas AS s
                                  ON t.schema_id = s.schema_id';


 SELECT * 
   FROM @AllTables
  ORDER BY DBName, SchemaName, TableName;

  */