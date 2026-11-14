CREATE PROCEDURE [dbo].[ReadAccount]
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT [Id], [Label], [Amount] FROM [dbo].[Account] WHERE [Id] = @Id;
END;
