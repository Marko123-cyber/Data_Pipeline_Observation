USE Data_Pipeline_Observation;

-- 1. Pipeline
INSERT INTO Pipeline (Name, SourceType, IsActive)
VALUES 
('Sales ETL', 'csv', 1),
('User Events', 'api', 1),
('Inventory Sync', 'database', 0);

-- 2. Pipeline_run
-- NOTE: Run 2 inserted as 'running' first so layers can be inserted
-- It will be marked as 'failed' at the end of this script after all its data is in
INSERT INTO Pipeline_run (StartedAt, FinishedAt, Status, Rows_written, DurationSec, PipelineID)
VALUES
('2026-01-01 08:00:00', '2026-01-01 08:05:30', 'completed', 15000, 330.5, 1),
('2026-01-01 09:00:00', '2026-01-01 09:02:10', 'running',   3200,  130.0, 2),
('2026-01-01 10:00:00', NULL,                  'running',   0,     NULL,  3);

-- 3. Layer
INSERT INTO Layer (LayerName, SizeBytes, RowCount, Status, RunID)
VALUES
('bronze', 204800, 15000, 'completed', 1),
('silver', 102400, 14800, 'completed', 1),
('gold',   51200,  14500, 'completed', 1),
('bronze', 40960,  3200,  'failed',    2);

-- 4. Data_Quality_Check
INSERT INTO Data_Quality_Check (Check_Name, Check_Type, Actual_Value, Passed, RunID)
VALUES
('Null Check',      'completeness', '0',     1, 1),
('Row Count Match', 'volume',       '15000', 1, 1),
('Schema Validate', 'schema',       'pass',  1, 1),
('Null Check',      'completeness', '412',   0, 2);

-- 5. Failure
INSERT INTO Failure (ErrorMessage, ErrorCode, Severity, RunID)
VALUES
('Connection timeout on source API', 'ERR_TIMEOUT', 'high',   2),
('Null values exceeded threshold',   'ERR_QUALITY', 'medium', 2);

-- 6. Alert (manual alerts in addition to the auto-created one from Trigger 4)
INSERT INTO Alert (Channel, FailureID)
VALUES
('slack', 1),
('email', 2);

-- 7. Mark Run 2 as failed now that all its data is inserted
-- Trigger 3 would block any future layer inserts into this run
UPDATE Pipeline_run
SET Status = 'failed'
WHERE RunID = 2;