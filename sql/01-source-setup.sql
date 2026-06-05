-- ============================================================================
-- Source SQL Server: create SourceDB, enable CDC, create TBL_AG_TEST4 with an
-- IDENTITY primary key, and seed five rows with explicit (non-contiguous)
-- identity values. CDC requires the SQL Server Agent (enabled in compose).
-- ============================================================================
USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SourceDB')
    CREATE DATABASE SourceDB;
GO

USE SourceDB;
GO

-- Enable CDC at the database level
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'SourceDB' AND is_cdc_enabled = 1)
    EXEC sys.sp_cdc_enable_db;
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
    CONSTRAINT [PK_TBL_AG_TEST4] PRIMARY KEY CLUSTERED ([col1] ASC)
) ON [PRIMARY];
GO

-- Enable CDC on the table
EXEC sys.sp_cdc_enable_table
    @source_schema = 'dbo',
    @source_name   = 'TBL_AG_TEST4',
    @role_name     = NULL,
    @supports_net_changes = 1;
GO

-- Seed data with explicit IDENTITY values (1, 11, 21, 31, 41)
SET IDENTITY_INSERT dbo.TBL_AG_TEST4 ON;
GO
INSERT INTO dbo.TBL_AG_TEST4 (col1, col2, col3, col4, col5, col6, APP_OR_DEB)
VALUES
    (1,  100, '2026-05-14 10:00:00.000', 'Record1', 'TestA', 'Type1', 1),
    (11, 200, '2026-05-14 10:01:00.000', 'Record2', 'TestB', 'Type2', 2),
    (21, 300, '2026-05-14 10:02:00.000', 'Record3', 'TestC', 'Type3', 1),
    (31, 400, '2026-05-14 10:03:00.000', 'Record4', 'TestD', 'Type4', 2),
    (41, 500, '2026-05-14 10:04:00.000', 'Record5', 'TestE', 'Type5', 1);
GO
SET IDENTITY_INSERT dbo.TBL_AG_TEST4 OFF;
GO

SELECT col1, col2, col4 FROM dbo.TBL_AG_TEST4 ORDER BY col1;
GO
PRINT 'Source ready: SourceDB.dbo.TBL_AG_TEST4 (CDC on, 5 rows).';
GO
