CREATE FUNCTION dbo.FancyTrim(@String NVARCHAR(MAX))
RETURNS nvarchar(MAX)
AS
BEGIN
DECLARE @Chars2Trim VARCHAR(10) = CHAR(9) + CHAR(10) + CHAR(13) + CHAR(32);

--RTRIM
SET @String = REVERSE(@String)
SET @String = REVERSE(SUBSTRING(@String, PATINDEX('%[^' + @Chars2Trim + ']%', @String), LEN(@String)))

--LTRIM
RETURN SUBSTRING(@String, PATINDEX('%[^' + @Chars2Trim + ']%', @String), LEN(@String))
END