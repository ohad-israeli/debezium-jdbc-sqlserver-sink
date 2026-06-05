-- ============================================================================
-- Target SQL Server: create TargetDB and TBL_AG_TEST4 with the SAME schema as
-- the source, including the IDENTITY column. It starts empty — the Debezium JDBC
-- sink populates it. Because the column is IDENTITY, inserting the source's
-- identity values normally fails; the sink's "dialect.sqlserver.identity.insert"
-- option wraps each batch in SET IDENTITY_INSERT ON/OFF so the values carry over.
-- ============================================================================
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'TargetDB')
    CREATE DATABASE TargetDB;
GO

USE TargetDB;
GO

IF OBJECT_ID('dbo.TBL_AG_TEST4', 'U') IS NOT NULL
    DROP TABLE dbo.TBL_AG_TEST4;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE TABLE [dbo].[TBL_AG_TEST4](
    [col1] [BIGINT] IDENTITY(1,10) NOT FOR REPLICATION NOT NULL,
    [col2] [INT] NULL,
    [col3] [DATETIME] NOT NULL,
    [col4] [VARCHAR](50) NOT NULL,
    [col5] [VARCHAR](50) NULL,
    [col6] [VARCHAR](30) NOT NULL,
    [APP_OR_DEB] [INT] NULL,
    CONSTRAINT [PK_TBL_AG_TEST4_TARGET] PRIMARY KEY CLUSTERED ([col1] ASC)
) ON [PRIMARY];
GO

SELECT COUNT(*) AS row_count FROM dbo.TBL_AG_TEST4;
GO
PRINT 'Target ready: TargetDB.dbo.TBL_AG_TEST4 (empty).';
GO
