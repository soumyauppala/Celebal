WITH EmployeeDetails AS (
    SELECT
        EmpID,
        Name,
        MIN(CASE WHEN Attendance = 'IN' THEN `CheckIn-CheckOut Time` END) AS FirstCheckInTime,
        MAX(CASE WHEN Attendance = 'OUT' THEN `CheckIn-CheckOut Time` END) AS LastCheckOutTime,
        SUM(CASE WHEN Attendance = 'OUT' THEN 1 ELSE 0 END) AS TotalOutCount
    FROM
        EmployeeLog
    GROUP BY
        EmpID, Name
),
WorkDuration AS (
    SELECT
        EmpID,
        Name,
        `CheckIn-CheckOut Time`,
        LAG(`CheckIn-CheckOut Time`) OVER (PARTITION BY EmpID, Name ORDER BY `CheckIn-CheckOut Time`) AS PreviousTime,
        Attendance
    FROM
        EmployeeLog
),
WorkHours AS (
    SELECT
        EmpID,
        Name,
        SUM(
            CASE
                WHEN Attendance = 'OUT' AND PreviousTime IS NOT NULL THEN TIMESTAMPDIFF(MINUTE, PreviousTime, `CheckIn-CheckOut Time`)
                ELSE 0
            END
        ) AS TotalWorkMinutes
    FROM
        WorkDuration
    GROUP BY
        EmpID, Name
)
SELECT
    e.EmpID,
    e.Name,
    e.FirstCheckInTime,
    e.LastCheckOutTime,
    e.TotalOutCount,
    CONCAT(FLOOR(w.TotalWorkMinutes / 60), ':', LPAD(w.TotalWorkMinutes % 60, 2, '0')) AS TotalWorkHours
FROM
    EmployeeDetails e
JOIN
    WorkHours w ON e.EmpID = w.EmpID AND e.Name = w.Name;

WITH check_in_out_times AS (
    SELECT
        EmpID,
        Name,
        CheckInCheckOutTime,
        Attendance,
        LAG(CheckInCheckOutTime) OVER (PARTITION BY EmpID ORDER BY CheckInCheckOutTime) AS PrevTime,
        LEAD(CheckInCheckOutTime) OVER (PARTITION BY EmpID ORDER BY CheckInCheckOutTime) AS NextTime
    FROM attendance
),
work_hours AS (
    SELECT
        EmpID,
        Name,
        MIN(CheckInCheckOutTime) AS FirstCheckInTime,
        MAX(CheckInCheckOutTime) AS LastCheckOutTime,
        COUNT(CASE WHEN Attendance = 'OUT' THEN 1 END) AS TotalOutCount,
        SUM(
            CASE
                WHEN Attendance = 'IN' THEN
                    COALESCE(DATEDIFF(MINUTE, CheckInCheckOutTime, NextTime), 0)
                ELSE 0
            END
        ) AS TotalWorkMinutes
    FROM check_in_out_times
    GROUP BY EmpID, Name
)
SELECT
    EmpID,
    Name,
    FORMAT(FirstCheckInTime, 'MM-dd-yyyy HH:mm') AS FirstCheckInTime,
    FORMAT(LastCheckOutTime, 'MM-dd-yyyy HH:mm') AS LastCheckOutTime,
    TotalOutCount,
    FORMAT(TotalWorkMinutes / 60, '00') + ':' + FORMAT(TotalWorkMinutes % 60, '00') AS TotalWorkHours
FROM work_hours;
