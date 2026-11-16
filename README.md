# Db2 LUW (DPF) Privilege Audit

SQL scripts to report the **effective permissions** of a single authorization ID on Db2 LUW 11.5.x (DPF), organised the way an Oracle DBA thinks about them (system privileges, object privileges, roles), and to **validate** who is really using a shared account.

> **Status:** tested design, but verify on a non-production database first. Catalog column names can vary slightly between fix packs.

## Why this exists

Db2 has no `CREATE USER`. Identities come from the OS or LDAP, so a shared OS account looks like one user to the database. This repo helps you answer three questions:

1. What can this account do? (`01_privilege_audit.sql`)
2. Who is behind it and what are they running? (`02_activity_validation.sql`)
3. Does the report match what Db2 itself resolves? (`03_report_crosscheck.sql`)

## Repository layout

| Path | Purpose |
|---|---|
| `sql/01_privilege_audit.sql` | Main CSV report: instance, database and object privileges, with source of each grant |
| `sql/02_activity_validation.sql` | Connections, hosts, running SQL, existing WLM / trusted context controls |
| `sql/03_report_crosscheck.sql` | Independent checks to validate the CSV |
| `sql/04_wlm_controls_example.sql` | Example remediation (trusted context, WLM thresholds). Not a drop-in |
| `docs/INTERPRETING_OUTPUT.md` | Oracle-to-Db2 mapping and how to read the report |

## Requirements

- Db2 LUW 11.5.x, DPF or non-DPF (catalog is read from the catalog partition; run from any partition)
- `SYSADM`, `DBADM`, `SECADM` or `ACCESSCTRL`, or `SELECT` on the catalog views
- Db2 CLP and a shell with `sed` and `grep`

## Quick start

```bash
# 1. Set the target authid (UPPERCASE) and database
export TARGET_AUTHID=MY_SHARED_USER
export DBNAME=MYDB

# 2. Generate a runnable copy with the placeholder replaced
mkdir -p out
for f in sql/01_privilege_audit.sql sql/02_activity_validation.sql sql/03_report_crosscheck.sql; do
  sed "s/APP_SHARED_USER/${TARGET_AUTHID}/g" "$f" > "out/$(basename "$f")"
done

# 3. Run the report
db2 connect to "$DBNAME"
db2 -txf out/01_privilege_audit.sql | sed 's/[[:space:]]*$//' \
  | grep -v 'record(s) selected' > out/user_permissions.csv

# 4. Run validation
db2 -tvf out/02_activity_validation.sql > out/activity.txt
db2 -tvf out/03_report_crosscheck.sql   > out/crosscheck.txt
```

Instance authorities also come from OS groups. Check them directly as a second source:

```bash
db2 get dbm cfg | grep -iE "SYSADM_GROUP|SYSCTRL_GROUP|SYSMAINT_GROUP|SYSMON_GROUP"
id <os_user>
```

## Output format

CSV columns: `PRIVILEGE_CATEGORY, GRANTED_VIA, OBJECT_TYPE, OBJECT_NAME, PERMISSION, GRANTABLE_OR_ACTIVE`

| Category | Meaning | Oracle analogy |
|---|---|---|
| `0. INSTANCE AUTHORITY` | SYSADM / SYSCTRL / SYSMAINT / SYSMON | SYSDBA / SYSOPER |
| `1. DATABASE AUTHORITY` | DBADM, DATAACCESS, ACCESSCTRL, CONNECT, LOAD, ... | System privileges |
| `2. OBJECT PRIVILEGE` | Table, schema, routine, tablespace, ... grants | Object privileges |
| `3. OWNED OBJECT` | Implicit CONTROL on owned objects | Object ownership |

`GRANTED_VIA` shows where each privilege comes from: `DIRECT USER`, `OS GROUP`, `PUBLIC`, or a `ROLE` chain. See [docs/INTERPRETING_OUTPUT.md](docs/INTERPRETING_OUTPUT.md).

## Validation checklist

- [ ] `sql/03` check 2 (Db2's own authority resolution) agrees with sections 0 and 1 of the CSV
- [ ] OS groups from `sql/03` check 1 match `id <os_user>` on the server
- [ ] No row is silently missing: object-privilege row counts are plausible against `sql/03` check 4
- [ ] `db2 get dbm cfg` instance groups were compared against the user's OS groups
- [ ] Functional test as the real user: an action the CSV allows succeeds, one it denies returns `SQL0551N`
- [ ] Reviewed `PUBLIC` rows, especially `EXECUTE` on `SYSPROC.ADMIN_CMD`

## Known limitations

- Nested roles are resolved up to 10 levels.
- `PUBLIC` default grants on `SYS*`, `NULLID` and `SQLJ` schemas are hidden (SYSPROC is kept). Remove the `WHERE NOT (...)` in section 2 to see them all.
- `SYSIBMADM.PRIVILEGES` may also list database-level rows; if section 1 and 2 show duplicates, filter `OBJECTTYPE <> 'DATABASE'` in section 2.
- RCAC / LBAC security labels, `SETSESSIONUSER` and column-level grants are not covered.
- Group resolution depends on the OS/LDAP being able to resolve the authid on the database server.

## Safety

The scripts in `01`-`03` are read-only. `04_wlm_controls_example.sql` changes the database: review, test and agree on limits first, as `STOP EXECUTION` cancels running statements.

## Contributing

Issues and pull requests are welcome. Please include your Db2 version and fix pack, and never commit real user names, host names or CSV output from a production system.
