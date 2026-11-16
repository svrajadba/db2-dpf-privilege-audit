# Interpreting the output (for Oracle DBAs)

## Oracle to Db2 mapping

| Oracle | Db2 LUW | Where |
|---|---|---|
| SYSDBA / SYSOPER | Instance authorities: SYSADM, SYSCTRL, SYSMAINT, SYSMON (granted through OS groups in DBM CFG) | `db2 get dbm cfg` |
| System privileges (CREATE SESSION, CREATE TABLE) | Database authorities: CONNECT, CREATETAB, BINDADD, IMPLSCHEMA, LOAD | `SYSCAT.DBAUTH` |
| `DBA` role / `ANY` privileges | DBADM, DATAACCESS (like SELECT/INSERT/UPDATE/DELETE ANY TABLE), ACCESSCTRL (like GRANT ANY PRIVILEGE), SECADM | `SYSCAT.DBAUTH` |
| Roles | Roles (nestable) | `SYSCAT.ROLEAUTH` |
| Object privileges | Table, schema, routine, package, tablespace, sequence grants | `SYSCAT.*AUTH`, `SYSIBMADM.PRIVILEGES` |
| PUBLIC | PUBLIC | `GRANTEE = 'PUBLIC'` |
| Resource Manager / profiles | Workload Management (WLM) | `SYSCAT.WORKLOADS`, `SYSCAT.THRESHOLDS` |

## Three differences to remember

1. **No `CREATE USER`.** Authentication is external. Any OS/LDAP account that can reach the database is a user.
2. **OS groups can be grantees** (`GRANTEETYPE = 'G'`). A privilege may arrive through an OS group, not a role.
3. **Schema is not user.** A schema is only a namespace.

## Reading `GRANTED_VIA`

| Value | Meaning |
|---|---|
| `DIRECT USER` | Granted to the authid itself |
| `OS GROUP: <name>` | Granted to an OS group the user belongs to |
| `PUBLIC` | Granted to everyone |
| `ROLE <r> <- DIRECT USER` | Held through role `r`, which was granted to the user |
| `ROLE <r> <- ROLE <p>` | Nested role: `r` was granted to role `p` |

For instance authorities (category 0), `GRANTED_VIA` lists the channel Db2 found: `USER`, `OSGROUP`, `PUBLIC`, `ROLE(...)`.

## Red flags to look for

| Finding | Why it matters |
|---|---|
| Any category 0 row (SYSADM, SYSCTRL) | Overrides everything below it |
| `DBADM`, `DATAACCESS`, `ACCESSCTRL`, `SECADM` | Broad data access or ability to grant |
| `CONNECT` via `PUBLIC` | Any OS account that reaches the database can connect |
| `CREATETAB`, `IMPLSCHEMA` via `PUBLIC` | Anyone can create objects |
| `WITH GRANT OPTION` | Privilege can be passed on |
| `CONTROL` on tables | Full control of the object, like ownership |
| `EXECUTE` on `SYSPROC.ADMIN_CMD` via `PUBLIC` | Allows running administrative commands through SQL |
| `USE` on tablespaces | Allows data storage on shared tablespaces |

## Shared-account problem pattern

One authid with many client hosts and applications (`sql/02`, queries A and B), long-running statements (query C), and no WLM thresholds or trusted context (query D) means the database cannot attribute or limit activity per person.

Recommended order:

1. Revoke `CONNECT` from `PUBLIC` and grant it through a role.
2. Add a trusted context bound to the approved source address.
3. Add WLM thresholds (concurrency, elapsed time, estimated cost).
4. Move to individual identities with privileges granted through roles.

See `sql/04_wlm_controls_example.sql`.
