Use Data_Pipeline_Observation;
-- ===================================
-- VIEWS
-- ===================================


-- CREATE VIEW currently_running_pipelines AS

CREATE OR REPLACE VIEW currently_running_pipelines AS
SELECT 
    p.Name AS name,
    pr.StartedAt,
    TIMESTAMPDIFF(SECOND, pr.StartedAt, NOW()) AS RunningSec
FROM Pipeline p
LEFT JOIN Pipeline_run pr
    ON p.PipelineID = pr.PipelineID
WHERE pr.Status = 'running';


-- CREATE VIEW high severity failures

CREATE OR REPLACE VIEW high_severity_failures AS
select 
p.Name as Pipeline_Name,
f.*,
case when a.AlertID is not null and a.Channel is not null and a.SentAt is not null then 1
else 0
end as 'IsAlertSent'
from Pipeline p
left join Pipeline_run pr
on pr.PipelineID=p.PipelineID
left join Failure f 
on f.RunID=pr.RunID
left join Alert a
on a.FailureID=f.FailureID
where f.Severity='high';