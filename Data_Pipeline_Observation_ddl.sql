Drop Database If Exists Data_Pipeline_Observation;
Create Database Data_Pipeline_Observation;
Use Data_Pipeline_Observation;

CREATE TABLE Pipeline(
PipelineID int not null auto_increment primary key,
Name nvarchar(255) not null,
SourceType nvarchar(255) not null,
IsActive tinyint not null default 1,
CreatedAt datetime not null default now()
);


CREATE TABLE Pipeline_run (
RunID int not null auto_increment primary key,
StartedAt datetime not null default now(),
FinishedAt datetime,
Status nvarchar(50) not null default 'running',
Rows_written int not null default 0,
DurationSec float,
PipelineID int not null,
Constraint FK_PipelineID_Pipeline_run FOREIGN KEY (PipelineID) references Pipeline (PipelineID)
);


CREATE TABLE Layer (
LayerID int not null auto_increment primary key,
LayerName nvarchar(255) not null,
SizeBytes int default 0,
RowCount int default 0,
Status nvarchar(50) not null default 'pending',
RunID int not null,
Constraint FK_RunID_Layer FOREIGN KEY (RunID) references Pipeline_run (RunID)
);

CREATE TABLE Data_Quality_Check(
CheckID int not null auto_increment primary key,
Check_Name nvarchar(255) not null,
Check_Type nvarchar(50) not null,
Actual_Value nvarchar(255) not null,
Passed tinyint not null default 0,
RunID int not null,
Constraint FK_RunID_Data_Quality_Check FOREIGN KEY (RunID) references Pipeline_run (RunID)
);

CREATE TABLE Failure(
FailureID int not null auto_increment primary key,
ErrorMessage nvarchar(255),
ErrorCode nvarchar(50) not null,
OccuredAt datetime not null default now(),
Severity nvarchar(50) default 'medium',
RunID int not null,
Constraint FK_Failure_RunID FOREIGN KEY (RunID) references Pipeline_run (RunID)
);

CREATE Table Alert(
AlertID int not null auto_increment primary key,
Channel nvarchar(50) not null,
SentAt datetime not null default now(),
FailureID int not null,
Constraint FK_Alert_FailureID FOREIGN KEY (FailureID) references Failure (FailureID)
);













