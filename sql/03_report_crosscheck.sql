----------------------------------------------------------------------------------
-- 03_report_crosscheck.sql
-- Independent checks to validate the output of 01_privilege_audit.sql.
-- Replace APP_SHARED_USER (uppercase). Run: db2 -tvf 03_report_crosscheck.sql
----------------------------------------------------------------------------------

-- 1. OS groups resolved for the authid (compare with `id <osuser>` on the server)
SELECT GRP FROM TABLE(SYSPROC.AUTH_LIST_GROUPS_FOR_AUTHID('APP_SHARED_USER')) AS G(GRP);

-- 2. Authorities as Db2 itself resolves them (should match sections 0 and 1 of the report)
SELECT AUTHORITY, D_USER, D_GROUP, D_PUBLIC, ROLE_USER, ROLE_GROUP, ROLE_PUBLIC
FROM   TABLE(SYSPROC.AUTH_LIST_AUTHORITIES_FOR_AUTHID('APP_SHARED_USER','U')) AS T
WHERE  D_USER <> 'N' OR D_GROUP <> 'N' OR D_PUBLIC <> 'N'
    OR ROLE_USER <> 'N' OR ROLE_GROUP <> 'N' OR ROLE_PUBLIC <> 'N'
ORDER  BY AUTHORITY;

-- 3. Direct role grants (the first level of the recursive role resolution)
SELECT ROLENAME, GRANTEETYPE, GRANTOR
FROM   SYSCAT.ROLEAUTH
WHERE  GRANTEE = 'APP_SHARED_USER';

-- 4. Row counts per identity for object privileges; compare with the report's
--    "2. OBJECT PRIVILEGE" rows (the report hides PUBLIC's system-schema grants)
SELECT AUTHIDTYPE, COUNT(*) AS PRIV_ROWS
FROM   SYSIBMADM.PRIVILEGES
WHERE  AUTHID = 'APP_SHARED_USER'
GROUP  BY AUTHIDTYPE;

-- 5. Dangerous PUBLIC grants that apply to every connection
SELECT AUTHID, PRIVILEGE, OBJECTTYPE, OBJECTSCHEMA, OBJECTNAME
FROM   SYSIBMADM.PRIVILEGES
WHERE  AUTHID = 'PUBLIC'
  AND (OBJECTSCHEMA = 'SYSPROC' AND OBJECTNAME IN ('ADMIN_CMD','ADMIN_CMD_PARTITION')
       OR PRIVILEGE = 'CONTROL');

-- 6. Functional test (run in a SEPARATE session, as the real user):
--    db2 connect to <DBNAME> user <authid>
--    db2 "values current user"
--    then attempt an action the report says is allowed / denied and confirm the SQLCODE
--    (SQL0551N = no privilege).
