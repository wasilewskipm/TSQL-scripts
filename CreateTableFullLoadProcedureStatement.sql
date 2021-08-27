CREATE   PROCEDURE dbo.CreateTableFullLoadProcedureStatement
(
    @SourceSchemaName NVARCHAR(128),
    @SourceObjectName NVARCHAR(128),
    @TargetSchemaName NVARCHAR(128),
    @TargetObjectName NVARCHAR(128),
    @SourceColumnNameList NVARCHAR(MAX),
    @TargetColumnNameList NVARCHAR(MAX),
    @LinkedServerName NVARCHAR(128) = NULL,
    @SourceDatabaseName NVARCHAR(128) = NULL,
    @Debug BIT = 1,
    @Execute BIT = 0
)
AS
BEGIN

DECLARE @SQL NVARCHAR(MAX);
DECLARE @CrLf CHAR(2) = CHAR(13) + CHAR(10);

SET @SourceColumnNameList = dbo.FancyTrim(@SourceColumnNameList)

IF RIGHT(@SourceColumnNameList, 1) = ','
    SET @SourceColumnNameList = LEFT(@SourceColumnNameList, LEN(@SourceColumnNameList) - 1);

SET @TargetColumnNameList = dbo.FancyTrim(@TargetColumnNameList)

IF RIGHT(@TargetColumnNameList, 1) = ','
    SET @TargetColumnNameList = LEFT(@TargetColumnNameList, LEN(@TargetColumnNameList) - 1);

IF (SELECT COUNT(*)
    FROM sys.objects AS o
    WHERE SCHEMA_NAME(schema_id) = @TargetSchemaName
    AND o.[name] = 'FullLoad_' + @TargetObjectName
    AND o.type = 'P') = 0

    BEGIN
        SET @SQL = 
        'CREATE PROCEDURE ' + QUOTENAME(@TargetSchemaName) + '.FullLoad_' + @TargetObjectName + '
        AS
        BEGIN
        BEGIN TRY
        BEGIN TRAN
        TRUNCATE TABLE ' + QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME(@TargetObjectName) + ';
        INSERT INTO ' + QUOTENAME(@TargetSchemaName) + '.' + QUOTENAME(@TargetObjectName) + '(' + @TargetColumnNameList + ')
        SELECT ' + @SourceColumnNameList + '
        FROM ' + ISNULL(QUOTENAME(@LinkedServerName) + '.', '') + ISNULL(QUOTENAME(@SourceDatabaseName) + '.', '')+ QUOTENAME(@SourceSchemaName) + '.' + QUOTENAME(@SourceObjectName) + ';
        COMMIT TRAN
        END TRY
        BEGIN CATCH
        IF(@@TRANCOUNT > 0)
        ROLLBACK TRAN;

        THROW;
        END CATCH
        END'

        IF @Debug = 1
            PRINT @SQL

        IF @Execute = 1
            EXEC sp_executesql @SQL;
    END
ELSE
    RAISERROR('SP already exists.', 0, 16);
;
END