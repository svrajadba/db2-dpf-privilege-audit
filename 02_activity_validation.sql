----------------------------------------------------------------------------------
-- 02_activity_validation.sql
-- Who is behind a shared account, what are they running, and which controls exist.
-- Replace APP_SHARED_USER (uppercase). Run: db2 -tvf 02_activity_validation.sql
-- Column names can differ slightly by fix pack; run DESCRIBE if one is rejected.
----------------------------------------------------------------------------------

-- A. Connections behind the account (all DPF members)
SELECT APPLICATION_HANDLE, MEMBER, APPLICATION_NAME, CLIENT_HOSTNAME,
       CLIENT_WRKSTNNAME, CLIENT_USERID, CONNECTION_START_TIME
FROM   TABLE(MON_GET_CONNECTION(CAST(NULL AS BIGINT), -2)) AS C
WHERE  SESSION_AUTH_ID = 'APP_SHARED_USER'
ORDER  BY CLIENT_HOSTNAME;

-- B. Distinct hosts / applications sharing the account (accountability gap)
SELECT CLIENT_HOSTNAME, APPLICATION_NAME, COUNT(*) AS CONNECTIONS
FROM   TABLE(MON_GET_CONNECTION(CAST(NULL AS BIGINT), -2)) AS C
WHERE  SESSION_AUTH_ID = 'APP_SHARED_USER'
GROUP  BY CLIENT_HOSTNAME, APPLICATION_NAME
ORDER  BY CONNECTIONS DESC;

-- C. Longest-running current statements
SELECT APPLICATION_HANDLE, ELAPSED_TIME_SEC, ROWS_READ, ROWS_RETURNED, STMT_TEXT
FROM   SYSIBMADM.MON_CURRENT_SQL
WHERE  SESSION_AUTH_ID = 'APP_SHARED_USER'
ORDER  BY ELAPSED_TIME_SEC DESC
FETCH  FIRST 20 ROWS ONLY;

-- D. Existing controls: WLM workloads, thresholds, trusted contexts
SELECT WORKLOADNAME, ENABLED FROM SYSCAT.WORKLOADS;
SELECT THRESHOLDNAME, THRESHOLDPREDICATE, ENABLED FROM SYSCAT.THRESHOLDS;
SELECT CONTEXTNAME, SYSTEMAUTHID, ENABLED FROM SYSCAT.CONTEXTS;
