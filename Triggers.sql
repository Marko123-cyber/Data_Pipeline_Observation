Use Data_Pipeline_Observation;
-- ===================================
-- TRIGGERS
-- ===================================

-- Auto-calculate DurationSec

DELIMITER //

CREATE TRIGGER duration_setting_after_pipeline_finished
BEFORE UPDATE ON Pipeline_run
FOR EACH ROW
BEGIN
    IF NEW.FinishedAt IS NOT NULL THEN
        SET NEW.DurationSec = TIMESTAMPDIFF(SECOND, NEW.StartedAt, NEW.FinishedAt);
    END IF;
END//

DELIMITER ;

-- Auto-set Pipeline_run Status to 'completed'
DELIMITER //

CREATE TRIGGER set_status_completed
AFTER UPDATE ON Layer
FOR EACH ROW
BEGIN

    IF NEW.Status = 'completed' THEN
    
        IF NOT EXISTS (
            SELECT 1
            FROM Layer
            WHERE RunID = NEW.RunID
            AND Status <> 'completed'
        ) THEN
        
            UPDATE Pipeline_run
            SET Status = 'completed'
            WHERE RunID = NEW.RunID;
            
        END IF;
        
    END IF;

END//

DELIMITER ;

-- Prevent inserting a Layer for a failed Run
DELIMITER //

CREATE TRIGGER check_if_failed_run_before_layer_insertion
BEFORE INSERT ON Layer
FOR EACH ROW
BEGIN

    IF EXISTS (
        SELECT 1
        FROM Pipeline_run
        WHERE RunID = NEW.RunID
        AND Status = 'failed'
    ) THEN
    
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cannot insert layer into a failed pipeline run',
            MYSQL_ERRNO = 1001;
            
    END IF;

END//

DELIMITER ;


-- Automatically create an alert for the new failure with severity='high'
DELIMITER //

CREATE TRIGGER create_alert_on_failure_insertion
AFTER INSERT ON Failure
FOR EACH ROW
BEGIN
	IF NEW.Severity='high' THEN 
    INSERT INTO Alert (Channel, SentAt, FailureID)
    VALUES ('email', NOW(), NEW.FailureID);
    END IF;
END//

DELIMITER ;