CREATE   PROCEDURE dbo.CreateTableStatement
(
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnNameList NVARCHAR(MAX),
    @FilegroupName NVARCHAR(128) = 'PRIMARY',
    @Debug BIT = 1,
    @Execute BIT = 0
)
AS
BEGIN

DECLARE @SQL NVARCHAR(MAX);
DECLARE @CrLf CHAR(2) = CHAR(13) + CHAR(10);

SET @ColumnNameList = dbo.FancyTrim(@ColumnNameList)

IF RIGHT(@ColumnNameList, 1) = ','
    SET @ColumnNameList = LEFT(@ColumnNameList, LEN(@ColumnNameList) - 1);


IF (SELECT COUNT(*)
    FROM sys.objects AS o
    WHERE SCHEMA_NAME(schema_id) = @SchemaName
    AND o.[name] = @ObjectName
    AND o.type = 'U') = 0

    BEGIN

        SET @SQL = 
        'CREATE TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName) + '
        (' +  + @ColumnNameList + ')
        ON ' + QUOTENAME(@FilegroupName) + @CrLf

        IF @Debug = 1
            PRINT @SQL

        IF @Execute = 1
            EXEC sp_executesql @SQL;
    END

ELSE
    RAISERROR('Table already exists.', 0, 16);
;


END