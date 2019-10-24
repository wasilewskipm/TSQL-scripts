 
 /*
    Purpose:        Get status of packages' last run and last succesful run along with error messages
    Source:         github.com/wasilewskipm/
    Initial code:   2019.10.02
    Comments:
 */


 
USE SSISDB
GO


------------------------------------------ Configuration ------------------------------------------

DROP TABLE IF EXISTS #SSISStatus;

-- Filter data by project name (use % for no filter)
DECLARE @ProjectName NVARCHAR(100) = '%';

-- Filter data by package name (use % for no filter)
DECLARE @PackageName NVARCHAR(100) = 'Masterpackage%';

-- Filter data by execution id (use NULL for no filter)
DECLARE @ExecutionId BIGINT = NULL;



------------------------------------------ Implementation -----------------------------------------

 SELECT e.execution_id AS exec_id, 
    	e.project_name,
	    e.package_name,
	    e.[status], 
	    status_desc = 
            CASE e.[status]
			    WHEN 1 THEN 'Created'
				WHEN 2 THEN 'Running'
				WHEN 3 THEN 'Cancelled'
				WHEN 4 THEN 'Failed'
				WHEN 5 THEN 'Pending'
				WHEN 6 THEN 'Ended Unexpectedly'
				WHEN 7 THEN 'Succeeded'
				WHEN 8 THEN 'Stopping'
				WHEN 9 THEN 'Completed'
			END,
	    CAST(e.start_time AS datetime) AS start_time,
	    CAST(e.end_time AS datetime) AS end_time,
	    elapsed_time_min = DATEDIFF(mi, e.start_time, e.end_time),
        ls_exec_id = 
            CASE e.[status]
                WHEN 7 THEN NULL
                ELSE ISNULL(se.execution_id, 0)
            END,
        ls_start_time = 
            CASE e.[status]
                WHEN 7 THEN NULL
                ELSE CAST(ISNULL(se.start_time, '1900-01-01') AS datetime)
            END,
        ls_end_time =
            CASE e.[status]
                WHEN 7 THEN NULL
                ELSE CAST(ISNULL(se.end_time, '1900-01-01') AS datetime)
            END

   INTO #SSISStatus

   FROM (
         SELECT MAX(execution_id) AS max_exec_id, 
                MAX(CASE 
                         WHEN [status] = 7 THEN execution_id
                         ELSE 0
                    END) AS ls_exec_id

           FROM [catalog].executions

          WHERE package_name LIKE @PackageName

          GROUP BY folder_name, project_name, package_name
        ) AS il

        LEFT JOIN [catalog].executions AS e
           ON il.max_exec_id = e.execution_id

        LEFT JOIN [catalog].executions AS se
           ON il.ls_exec_id = se.execution_id

  WHERE e.project_name LIKE @ProjectName
        AND	e.package_name LIKE @PackageName
        AND	e.execution_id = ISNULL(@ExecutionId, e.execution_id);



 SELECT * 
   FROM #SSISStatus
  ORDER BY exec_id DESC;



 IF EXISTS (SELECT * 
              FROM #SSISStatus 
             WHERE [status] = 4
                   AND DATEDIFF(week, end_time, GETDATE()) < 1)


     SELECT t.exec_id, t.package_name, em.message_time, em.[message]
       FROM #SSISStatus AS t
            INNER JOIN SSISDB.[catalog].event_messages AS em
               ON t.exec_id = em.operation_id
      WHERE em.event_name = 'OnError'
            AND DATEDIFF(week, t.end_time, GETDATE()) < 1
      ORDER BY em.operation_id DESC, em.event_message_id;
