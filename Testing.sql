USE Data_Pipeline_Observation;

-- ============================================================
-- TESTING.SQL
-- Run this AFTER: Data_Pipeline_Observation_ddl.sql, Triggers.sql, 
--                 Stored_Procedures.sql, Views.sql, Data_Pipeline_Observation_data_insertion.sql
-- ============================================================


-- ===================================
-- TRIGGER TESTS
-- ===================================

-- TRIGGER 1: duration_setting_after_pipeline_finished
-- Expected: DurationSec auto-calculated = TIMESTAMPDIFF of StartedAt vs FinishedAt
-- We update RunID=3 (currently running, FinishedAt is NULL)

SELECT 'TRIGGER 1 - BEFORE update' AS Test, RunID, StartedAt, FinishedAt, DurationSec
FROM Pipeline_run WHERE RunID = 3;

UPDATE Pipeline_run
SET FinishedAt = '2026-01-01 11:45:00'
WHERE RunID = 3;

SELECT 'TRIGGER 1 - AFTER update' AS Test, RunID, StartedAt, FinishedAt, DurationSec
FROM Pipeline_run WHERE RunID = 3;
-- Expected DurationSec: 6300 (105 minutes * 60 seconds)


-- -------------------------------------------------------

-- TRIGGER 2: set_status_completed
-- Expected: when all layers for a RunID are completed,
--           Pipeline_run Status auto-sets to 'completed'
-- RunID=2 currently has one 'failed' layer — let's add a new run to test cleanly

CALL start_new_pipeline_run(1, @test_run_id);
SELECT @test_run_id AS NewRunID;

INSERT INTO Layer (LayerName, SizeBytes, RowCount, Status, RunID)
VALUES 
('bronze', 10000, 500, 'pending', @test_run_id),
('silver', 8000,  490, 'pending', @test_run_id);

SELECT 'TRIGGER 2 - BEFORE all layers completed' AS Test, Status 
FROM Pipeline_run WHERE RunID = @test_run_id;

UPDATE Layer SET Status = 'completed' WHERE LayerName = 'bronze' AND RunID = @test_run_id;
UPDATE Layer SET Status = 'completed' WHERE LayerName = 'silver' AND RunID = @test_run_id;

SELECT 'TRIGGER 2 - AFTER all layers completed' AS Test, Status 
FROM Pipeline_run WHERE RunID = @test_run_id;
-- Expected: Status = 'completed'


-- -------------------------------------------------------

-- TRIGGER 3: check_if_failed_run_before_layer_insertion
-- Expected: inserting a Layer into a failed run raises SQLSTATE 45000 error
-- RunID=2 has Status='failed'

SELECT 'TRIGGER 3 - Attempting insert into failed run (should error)' AS Test;

INSERT INTO Layer (LayerName, SizeBytes, RowCount, Status, RunID)
VALUES ('gold', 5000, 100, 'pending', 2);
-- Expected: ERROR 1001 - Cannot insert layer into a failed pipeline run


-- -------------------------------------------------------

-- TRIGGER 4: create_alert_on_failure_insertion
-- Expected: inserting a Failure with Severity='high' auto-creates an Alert

SELECT 'TRIGGER 4 - BEFORE high severity failure insert' AS Test, COUNT(*) AS AlertCount 
FROM Alert;

INSERT INTO Failure (ErrorMessage, ErrorCode, Severity, RunID)
VALUES ('Disk space exceeded', 'ERR_DISK', 'high', 1);

SELECT 'TRIGGER 4 - AFTER high severity failure insert' AS Test, COUNT(*) AS AlertCount 
FROM Alert;
-- Expected: AlertCount increases by 1

-- Verify the auto-created alert
SELECT 'TRIGGER 4 - Auto-created alert' AS Test, a.*
FROM Alert a
INNER JOIN Failure f ON a.FailureID = f.FailureID
WHERE f.ErrorCode = 'ERR_DISK';

-- Confirm medium severity does NOT create alert
SELECT 'TRIGGER 4 - BEFORE medium severity insert' AS Test, COUNT(*) AS AlertCount 
FROM Alert;

INSERT INTO Failure (ErrorMessage, ErrorCode, Severity, RunID)
VALUES ('Minor config warning', 'ERR_CONFIG', 'medium', 1);

SELECT 'TRIGGER 4 - AFTER medium severity insert (count should NOT change)' AS Test, COUNT(*) AS AlertCount 
FROM Alert;


-- ===================================
-- STORED PROCEDURE TESTS
-- ===================================

-- PROCEDURE 1: start_new_pipeline_run
-- Expected: new row inserted in Pipeline_run, RunID returned via OUT param

SELECT 'PROC 1 - start_new_pipeline_run' AS Test;

CALL start_new_pipeline_run(2, @new_run_id);
SELECT @new_run_id AS ReturnedRunID;

SELECT RunID, PipelineID, Status, StartedAt, FinishedAt, DurationSec
FROM Pipeline_run
WHERE RunID = @new_run_id;
-- Expected: Status='running', FinishedAt=NULL, DurationSec=NULL


-- -------------------------------------------------------

-- PROCEDURE 2: update_finish_time
-- Expected: FinishedAt set, DurationSec auto-calculated by Trigger 1

SELECT 'PROC 2 - BEFORE update_finish_time' AS Test, RunID, FinishedAt, DurationSec
FROM Pipeline_run WHERE RunID = @new_run_id;

CALL update_finish_time(@new_run_id, '2026-03-01 12:30:00');

SELECT 'PROC 2 - AFTER update_finish_time' AS Test, RunID, FinishedAt, DurationSec
FROM Pipeline_run WHERE RunID = @new_run_id;
-- Expected: FinishedAt populated, DurationSec auto-calculated


-- -------------------------------------------------------

-- PROCEDURE 3: health_report
-- Expected: total_rows_written, average_duration, total_failures for PipelineID=1

SELECT 'PROC 3 - health_report for PipelineID=1' AS Test;
CALL health_report(1);
-- Expected: rows_written > 0, average_duration > 0, total_failures = 0

SELECT 'PROC 3 - health_report for PipelineID=2' AS Test;
CALL health_report(2);
-- Expected: total_failures = 1 (RunID=2 has Status='failed')


-- ===================================
-- VIEW TESTS
-- ===================================

-- VIEW 1: currently_running_pipelines
-- Expected: shows pipelines with Status='running'
-- After Trigger 1 test above RunID=3 was finished, so only @new_run_id rows remain running

SELECT 'VIEW 1 - currently_running_pipelines' AS Test;
SELECT * FROM currently_running_pipelines;
-- Expected: Name, StartedAt, RunningSec (live seconds since start)


-- -------------------------------------------------------

-- VIEW 2: high_severity_failures
-- Expected: only Severity='high' failures, with Pipeline name and IsAlertSent flag

SELECT 'VIEW 2 - high_severity_failures' AS Test;
SELECT * FROM high_severity_failures;
-- Expected: ERR_TIMEOUT failure from User Events pipeline, IsAlertSent=1
-- ERR_QUALITY is medium severity so should NOT appear