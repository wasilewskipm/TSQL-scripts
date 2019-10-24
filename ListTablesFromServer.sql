
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
