Use Data_Pipeline_Observation;
-- ============================
-- STORED PROCEDURES
-- ============================

-- A procedure that starts a new pipeline run

DELIMITER //


CREATE PROCEDURE start_new_pipeline_run(IN p_PipelineID INT, OUT p_RunID INT)
BEGIN

INSERT INTO Pipeline_run(PipelineID, Status, StartedAt)
VALUES (p_PipelineID, 'running', NOW());

SET p_RunID = last_insert_id();

END //

DELIMITER ;

-- Update procedure finish time
DELIMITER //

CREATE PROCEDURE update_finish_time (
    IN p_RunID INT,
    IN p_FinishedAt DATETIME
)
BEGIN

    UPDATE Pipeline_run
    SET FinishedAt = p_FinishedAt
    WHERE RunID = p_RunID;

END//

DELIMITER ;


-- Create a health report 

DELIMITER //
CREATE PROCEDURE health_report(IN p_PipelineID INT)
BEGIN

SELECT 
    SUM(COALESCE(pr.Rows_written, 0)) AS total_rows_written, 
    AVG(COALESCE(pr.DurationSec, 0)) AS average_duration,
    SUM(CASE WHEN pr.Status = 'failed' THEN 1 ELSE 0 END) AS total_failures
FROM Pipeline p
LEFT JOIN Pipeline_run pr ON p.PipelineID = pr.PipelineID
WHERE p.PipelineID=p_PipelineID;

END //
DELIMITER ;