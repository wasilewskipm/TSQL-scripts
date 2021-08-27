
CREATE PROCEDURE [dbo].[GenerateAllObjects]
(
    @SourceServerName NVARCHAR(128),
    @SourceDatabaseName NVARCHAR(128),
    @SourceSchemaName NVARCHAR(128),
    @SourceObjectName NVARCHAR(128),
    @ForceNullability BIT = 1,
    @Debug BIT = 1,
    @Execute BIT = 0
)
AS
BEGIN
SET NOCOUNT ON;

BEGIN TRY
BEGIN TRAN
DECLARE @CrLf CHAR(2) = CHAR(13) + CHAR(10);
DECLARE @SQL NVARCHAR(max), @SQL2 NVARCHAR(MAX);

DECLARE @StageObjectName NVARCHAR(128) = @SourceSchemaName + '_' + @SourceObjectName;
DECLARE @StageSchemaName NVARCHAR(128) = 'Stage';
DECLARE @DDLBulkPrintSystemColumns NVARCHAR(MAX) = 'CreateETLDate datetime2(3) NULL,' + @CrLf + 'CreateETLKey bigint NULL';
DECLARE @BulkPrintSystemColumns NVARCHAR(MAX) = 'CreateETLDate,' + @CrLf + 'CreateETLKey';
DECLARE @ColumnNameListInPrimaryKey NVARCHAR(MAX) = '';
DECLARE @ColumnNameListNotInPrimaryKey NVARCHAR(MAX) = '';
DECLARE @DDLColumNameList NVARCHAR(MAX) = '';
DECLARE @PrimaryKeyWithStatement NVARCHAR(MAX) = 'WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)';
DECLARE @Filegroup NVARCHAR(128) = 'PRIMARY';

DROP TABLE IF EXISTS #meta;

CREATE TABLE #meta(
    SchemaName NVARCHAR(128),
    ObjectName NVARCHAR(128),
    ColumnName NVARCHAR(128),
    ColumnOrdinal INT,
    DataTypeName NVARCHAR(128),
    DataTypeLength INT,
    DataTypePrecision INT,
    DataTypeScale INT,
    ColumnCollation NVARCHAR(128),
    ColumnNullable BIT,
    PrimaryKeyColumnOrdinal INT,
    DDLDataType  NVARCHAR(256)
);

SET @SQL = '
SELECT SchemaName = s.[name],
       ObjectName = o.[name],
       ColumnName = c.[name],
       ColumnOrdinal = c.column_id,
       DataTypeName = t.[name],
       DataTypeLength = c.max_length,
       DataTypePrecision = c.precision,
       DataTypeScale = c.scale,
       ColumnCollation = c.collation_name,
       ColumnNullable = c.is_nullable,
       PrimaryKeyColumnOrdinal = ic.key_ordinal,
       DDLDataType = CASE
                       WHEN t.[name] = ''datetime2''
                            THEN t.[name] + ''('' + CAST(c.[scale] AS VARCHAR(3)) + '')''
                       WHEN t.[name] IN (''decimal'', ''numeric'')
                            THEN t.[name] + ''('' + CAST(c.[precision] AS VARCHAR(3)) + '','' + CAST(c.[scale] AS VARCHAR(3)) + '')''
                       WHEN t.[name] IN (''varchar'', ''char'', ''nvarchar'', ''nchar'') AND c.[max_length] = -1
                            THEN t.[name] + ''(MAX)''
                       WHEN t.[name] IN (''varchar'', ''char'')
                            THEN t.[name] + ''('' + CAST(c.[max_length] AS VARCHAR(5)) + '')''
                       WHEN t.[name] IN (''nvarchar'', ''nchar'')
                            THEN t.[name] + ''('' + CAST(c.[max_length]/2 AS VARCHAR(5)) + '')''
                       ELSE t.[name]
                    END
                    +
                    CASE 
                      WHEN ic.key_ordinal IS NOT NULL THEN '' NOT NULL''
                      WHEN ' + CAST(@ForceNullability AS CHAR(1)) + ' = 1 THEN '' NULL''
                      WHEN c.is_nullable = 0 THEN '' NOT NULL''
                      WHEN c.is_nullable = 1 THEN '' NULL''
                    END
FROM   [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.objects            AS o
       INNER JOIN [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.schemas AS s
          ON o.schema_id = s.schema_id
       INNER JOIN [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.columns AS c
          ON o.object_id = c.object_id
       INNER JOIN [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.types   AS t
          ON c.user_type_id = t.user_type_id
       LEFT JOIN [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.indexes AS i
          ON o.object_id = i.object_id AND i.is_primary_key = 1
       LEFT JOIN [' + @SourceServerName + '].[' + @SourceDatabaseName + '].sys.index_columns AS ic
          ON o.object_id = ic.object_id AND i.index_id = ic.index_id AND c.column_id = ic.column_id
WHERE  s.[name] = ISNULL(''' + @SourceSchemaName + ''', s.[name])
       AND o.[name] = ISNULL(''' + @SourceObjectName + ''', o.[name]);'

--PRINT @SQL;

INSERT INTO #meta
EXEC sys.sp_executesql @SQL;



SELECT @DDLColumNameList += ColumnName + ' ' + DDLDataType + ',' + @CrLf
FROM #meta
ORDER BY ColumnOrdinal;

SELECT @ColumnNameListInPrimaryKey += ColumnName + ',' + @CrLf
FROM #meta
WHERE PrimaryKeyColumnOrdinal IS NOT NULL
ORDER BY PrimaryKeyColumnOrdinal;

SELECT @ColumnNameListNotInPrimaryKey += ColumnName + ',' + @CrLf
FROM #meta
WHERE PrimaryKeyColumnOrdinal IS  NULL
ORDER BY ColumnOrdinal;

SET @SQL = @DDLColumNameList + @DDLBulkPrintSystemColumns

/* Create Target table */
EXEC dbo.CreateTableStatement
    @SchemaName = @SourceSchemaName,
    @ObjectName = @SourceObjectName,
    @ColumnNameList = @SQL,
    @Debug = @Debug,
    @Execute = @Execute

/* Create PK on Target table */
EXEC dbo.CreatePrimaryKeyStatement
    @SchemaName = @SourceSchemaName,
    @ObjectName = @SourceObjectName,
    @ColumnNameList = @ColumnNameListInPrimaryKey,
    @Debug = @Debug,
    @Execute = @Execute




/* Create Stage table */
EXEC dbo.CreateTableStatement
    @SchemaName = @StageSchemaName,
    @ObjectName = @StageObjectName,
    @ColumnNameList = @SQL,
    @Debug = @Debug,
    @Execute = @Execute

/* Create PK on Stage table */
EXEC dbo.CreatePrimaryKeyStatement
    @SchemaName = @StageSchemaName,
    @ObjectName = @StageObjectName,
    @ColumnNameList = @ColumnNameListInPrimaryKey,
    @Debug = @Debug,
    @Execute = @Execute



SET @SQL = '';

SELECT @SQL += c.[name] + ','
FROM   sys.objects            AS o
       INNER JOIN sys.columns AS c
          ON o.object_id = c.OBJECT_ID
WHERE SCHEMA_NAME(o.schema_id) = @SourceSchemaName
AND o.[name] = @SourceObjectName
AND c.[name] NOT IN ('CreateETLDate', 'CreateETLKey')

SET @SQL2 = @SQL + 'CONVERT(VARCHAR(26), GETDATE(), 121), CAST(FORMAT(GETDATE(), ''yyyyMMdd'') AS VARCHAR(8))'          
SET @SQL += @BulkPrintSystemColumns



EXEC dbo.CreateTableFullLoadProcedureStatement
    @SourceSchemaName = @StageSchemaName,
    @SourceObjectName = @StageObjectName,
    @TargetSchemaName = @SourceSchemaName,
    @TargetObjectName = @SourceObjectName,
    @SourceColumnNameList = @SQL,
    @TargetColumnNameList = @SQL,
    @Debug = @Debug,
    @Execute = @Execute



EXEC dbo.CreateTableFullLoadProcedureStatement
    @SourceSchemaName = @SourceSchemaName,
    @SourceObjectName = @SourceObjectName,
    @TargetSchemaName = @StageSchemaName,
    @TargetObjectName = @StageObjectName,
    @SourceColumnNameList = @SQL2,
    @TargetColumnNameList = @SQL,
    @LinkedServerName = @SourceServerName,
    @SourceDatabaseName = @SourceDatabaseName,
    @Debug = @Debug,
    @Execute = @Execute

COMMIT TRAN
END TRY
BEGIN CATCH
IF(@@TRANCOUNT > 0)
ROLLBACK TRAN;

THROW;
END CATCH
END