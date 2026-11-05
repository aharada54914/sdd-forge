CREATE TABLE [dbo].[Account]
(
    [Id] INT NOT NULL PRIMARY KEY,
    [Label] NVARCHAR(80) NOT NULL,
    [Amount] DECIMAL(12, 2) NOT NULL,
    [Memo] NVARCHAR(120) NULL
);
