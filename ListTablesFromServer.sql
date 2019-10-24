
 /*

    Purpose:        List tables from all databases on the server
    Source:         github.com/wasilewskipm/
    Initial code:   2019.10.24
    Comments:

 */


 
------------------------------------------ Configuration ------------------------------------------

 -- Filter for user defined tables (use 0 for no filter) 
 DECLARE @UserOnly  bit = 1;
 
 -- Filter for specific databases using comma separated values (use NULL for no filter)
 DECLARE @DbList    nvarchar(max);

 -- Working variables
 DECLARE @DbName    nvarchar(128);

 DECLARE @AllTables table 
 (
     DbName         nvarchar(128),
     SchemaName     nvarchar(128),
     TableName      nvarchar(128)
 );



 ------------------------------------------ Implementation ----------------------------------------

 DECLARE Crs CURSOR
 FOR SELECT QUOTENAME(d.[name])
       FROM sys.databases AS d
            LEFT JOIN STRING_SPLIT(@DbList, ',') AS s
              ON d.[name] = LTRIM(s.[value])
      WHERE d.[state] = 0
            AND d.database_id > @UserOnly*4
            AND d.[name] = CASE WHEN @DbList IS NULL THEN d.[name]
                                ELSE LTRIM(s.[value]) END;


 OPEN Crs;
 FETCH NEXT FROM Crs INTO @DbName;

 
 WHILE @@FETCH_STATUS = 0
 BEGIN

     INSERT INTO @AllTables (DbName, SchemaName, TableName)
     EXEC ('SELECT PARSENAME(''' + @DbName + ''', 1), s.name, t.name 
              FROM ' + @DbName + '.sys.tables AS t 
                   INNER JOIN sys.schemas AS s
                      ON t.schema_id = s.schema_id;');

     FETCH NEXT FROM Crs INTO @DbName;

 END; -- WHILE @@FETCH_STATUS = 0


 CLOSE Crs;
 DEALLOCATE Crs;


 SELECT * 
   FROM @AllTables
  ORDER BY DbName, SchemaName, TableName;



 ----------------------------------------- Other approaches ---------------------------------------

 /*

 DECLARE @AllTables table 
 (
    DbName      nvarchar(4000),
    SchemaName  nvarchar(4000),
    TableName   nvarchar(4000)
 );


 INSERT INTO @AllTables
   EXEC sp_msforeachDb 'SELECT ''?'', s.name, t.name 
                          FROM [?].sys.tables AS t 
                               INNER JOIN sys.schemas AS s
                                  ON t.schema_id = s.schema_id';


 SELECT * 
   FROM @AllTables
  ORDER BY DbName, SchemaName, TableName;

 */