

CREATE   PROCEDURE dbo.CreatePrimaryKeyStatement
(
    @SchemaName NVARCHAR(128),
    @ObjectName NVARCHAR(128),
    @ColumnNameList NVARCHAR(MAX),
    @PrimaryKeyPrefix NVARCHAR(128) = 'PK_',
    @PrimaryKeySufix  NVARCHAR(128) = '',
    @WithStatement NVARCHAR(MAX) = 'WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)',
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

IF RIGHT(@PrimaryKeyPrefix, 1) != '_' AND @PrimaryKeyPrefix != ''
    SET @PrimaryKeyPrefix += '_';

IF LEFT(@PrimaryKeySufix, 1) != '_' AND @PrimaryKeySufix != ''
    SET @PrimaryKeySufix = '_' + @PrimaryKeySufix;


IF (SELECT COUNT(*)
    FROM sys.objects AS o
    WHERE SCHEMA_NAME(schema_id) = @SchemaName
    AND o.[name] = @PrimaryKeyPrefix + @SchemaName + '_' + @ObjectName + @PrimaryKeySufix
    AND o.type = 'PK') = 0

    BEGIN
        SET @SQL = 
        'ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName) + '
        ADD CONSTRAINT ' + QUOTENAME(@PrimaryKeyPrefix + @SchemaName + '_' + @ObjectName + @PrimaryKeySufix) + ' PRIMARY KEY CLUSTERED
        (' +  + @ColumnNameList + ')
        ' + @WithStatement + '
        ON ' + QUOTENAME(@FilegroupName) + @CrLf

        IF @Debug = 1
            PRINT @SQL

        IF @Execute = 1
            EXEC sp_executesql @SQL;
    END

ELSE
    RAISERROR('PK already exists.', 0, 16);

END