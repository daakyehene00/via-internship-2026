# Metasploitable2 Exploitation Report

**Name:** Eugene Antwi Boasiako
**Index Number:** 7352623
**Date:** September 21, 2026
**Target IP:** 192.168.1.3
**Attacker OS / Tools:** Kali Linux, Metasploit, Nmap, Netcat

---

## Reconnaissance Summary

Initial discovery was performed using `nmap -p- -sV -sC 192.168.1.3`. This revealed multiple vulnerable services including an open NFS share, VNC with weak credentials, Tomcat default logins, and several backdoored services (vsftpd, UnrealIRCd, Ingreslock).

---

## Exploit 1: NFS Unrestricted Share

- **Service / Port:** NFS / 2049
- **Vulnerability:** Misconfigured NFS Export
- **Tool Used:** `showmount` and `mount`
- **Why This Tool:** Native OS tools allow direct mounting of the exposed filesystem.
- **Steps:** 
  1. `showmount -e 192.168.1.3`
  2. `sudo mkdir /mnt/nfs`
  3. `sudo mount -t nfs 192.168.1.3:/ /mnt/nfs`
- **Evidence:** `evidence/exploit1.png`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Actions on Objectives.
  - Reconnaissance: Identified the exposed `/ *` share.
  - Actions on Objectives: Achieved local access to remote files.
- **Outcome / Impact:** Full read/write access to target file system.

---

## Exploit 2: VNC Weak Password

- **Service / Port:** VNC / 5900
- **Vulnerability:** Weak Default Credentials
- **Tool Used:** `auxiliary/scanner/vnc/vnc_login`
- **Why This Tool:** Metasploit quickly automates VNC login checks.
- **Steps:**
  1. `use auxiliary/scanner/vnc/vnc_login`
  2. `set RHOSTS 192.168.1.3`
  3. `run` (Found password: `password`)
  4. `vncviewer 192.168.1.3`
- **Evidence:** `evidence/exploit2.png`
- **Cyber Kill Chain Stage(s):** Weaponization, Exploitation.
  - Weaponization: Configured the scanner with standard wordlists.
  - Exploitation: Successfully authenticated to the GUI.
- **Outcome / Impact:** Gained graphical desktop access.

---

## Exploit 3: Tomcat Manager Default Login

- **Service / Port:** Apache Tomcat / 8180
- **Vulnerability:** Default Credentials (`tomcat:tomcat`)
- **Tool Used:** `exploit/multi/http/tomcat_mgr_upload`
- **Why This Tool:** Automatically packages a payload into a WAR file and deploys it via the manager interface.
- **Steps:**
  1. `use exploit/multi/http/tomcat_mgr_upload`
  2. `set RHOSTS 192.168.1.3` and set credentials.
  3. `run`
- **Evidence:** `evidence/exploit3.png`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation.
  - Delivery: Uploaded the malicious WAR file.
  - Exploitation: Triggered code execution for a shell.
- **Outcome / Impact:** Command execution via Tomcat application.

---

## Exploit 4: PostgreSQL Payload Execution

- **Service / Port:** PostgreSQL / 5432
- **Vulnerability:** Default Credentials (`postgres:postgres`)
- **Tool Used:** `exploit/linux/postgres/postgres_payload`
- **Why This Tool:** Uploads a shared object to execute OS commands via database queries.
- **Steps:**
  1. `use exploit/linux/postgres/postgres_payload`
  2. `set RHOSTS 192.168.1.3` and set credentials.
  3. `run`
- **Evidence:** `evidence/exploit4.png`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation, C2.
  - Delivery: Injected the payload object.
  - Exploitation/C2: Executed the payload to establish a Meterpreter session.
- **Outcome / Impact:** System access under the `postgres` user.

---

## Exploit 5: DistCC Command Execution

- **Service / Port:** distccd / 3632
- **Vulnerability:** CVE-2004-2687
- **Tool Used:** `exploit/unix/misc/distcc_exec`
- **Why This Tool:** Readily exploits the compilation daemon to run arbitrary commands.
- **Steps:**
  1. `use exploit/unix/misc/distcc_exec`
  2. `set RHOSTS 192.168.1.3`
  3. `run`
- **Evidence:** `evidence/exploit5.png`
- **Cyber Kill Chain Stage(s):** Exploitation, C2.
  - Exploitation: Sent execution request to daemon.
  - C2: Obtained shell access.
- **Outcome / Impact:** Shell access as `daemon` user.

---

## Exploit 6: UnrealIRCd Backdoor

- **Service / Port:** IRC / 6667
- **Vulnerability:** Malicious source code backdoor
- **Tool Used:** `exploit/unix/irc/unreal_ircd_3281_backdoor`
- **Why This Tool:** Triggers the specific debug string required by the backdoored software.
- **Steps:**
  1. `use exploit/unix/irc/unreal_ircd_3281_backdoor`
  2. `set RHOSTS 192.168.1.3`
  3. `run`
- **Evidence:** `evidence/exploit6.png`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation.
  - Delivery: Sent the trigger sequence `AB;`.
  - Exploitation: Forced the service to execute a payload.
- **Outcome / Impact:** Root-level shell execution.

---

## Exploit 7: vsftpd 2.3.4 Backdoor

- **Service / Port:** FTP / 21
- **Vulnerability:** CVE-2011-2523 (Smiley Face Backdoor)
- **Tool Used:** `exploit/unix/ftp/vsftpd_234_backdoor`
- **Why This Tool:** Seamlessly sends the `:)` string and catches the resulting root shell on port 6200.
- **Steps:**
  1. `use exploit/unix/ftp/vsftpd_234_backdoor`
  2. `set RHOSTS 192.168.1.3`
  3. `run`
- **Evidence:** `evidence/exploit7.png`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation, C2.
  - Delivery: Sent the malformed username.
  - Exploitation/C2: Triggered the backdoor listener and connected to it.
- **Outcome / Impact:** Root shell access.

---

## Exploit 8: Anonymous FTP

- **Service / Port:** FTP / 21
- **Vulnerability:** Anonymous Login Permitted
- **Tool Used:** `ftp` client
- **Why This Tool:** Basic client to verify standard read access.
- **Steps:**
  1. `ftp 192.168.1.3`
  2. Login as `anonymous`
  3. `ls`
- **Evidence:** `evidence/exploit8.png`
- **Cyber Kill Chain Stage(s):** Exploitation, Actions on Objectives.
  - Exploitation: Bypassed auth with anonymous credentials.
  - Actions on Objectives: Listed remote directories.
- **Outcome / Impact:** Unauthorized file system enumeration.

---

## Exploit 9: Samba usermap_script

- **Service / Port:** SMB / 139
- **Vulnerability:** CVE-2007-2447
- **Tool Used:** `exploit/multi/samba/usermap_script`
- **Why This Tool:** Automates shell metacharacter injection into the username field.
- **Steps:**
  1. `use exploit/multi/samba/usermap_script`
  2. `set RHOSTS 192.168.1.3`
  3. `run`
- **Evidence:** `evidence/exploit9.png`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation, C2.
  - Delivery: Sent malicious SMB request.
  - Exploitation/C2: Executed payload as root and caught shell.
- **Outcome / Impact:** Root shell obtained.

---

## Exploit 10: Ingreslock Bind Shell

- **Service / Port:** Ingreslock / 1524
- **Vulnerability:** Open Backdoor
- **Tool Used:** `nc` (Netcat)
- **Why This Tool:** Directly interacts with the raw TCP socket.
- **Steps:**
  1. `nc 192.168.1.3 1524`
  2. `whoami`
- **Evidence:** `evidence/exploit10.png`
- **Cyber Kill Chain Stage(s):** Delivery, C2.
  - Delivery: Initiated direct TCP handshake.
  - C2: Interacted with the existing root listener.
- **Outcome / Impact:** Instant root access.

---

## Kill Chain Coverage Summary

| Exploit | Recon | Weaponization | Delivery | Exploitation | Installation | C2 | Actions on Objectives |
|---|---|---|---|---|---|---|---|
| 1. NFS Share | ✔ | | | | | | ✔ |
| 2. VNC | | ✔ | | ✔ | | | |
| 3. Tomcat | | | ✔ | ✔ | | | |
| 4. PostgreSQL | | | ✔ | ✔ | | ✔ | |
| 5. DistCC | | | | ✔ | | ✔ | |
| 6. UnrealIRCd | | | ✔ | ✔ | | | |
| 7. vsftpd (Meta) | | | ✔ | ✔ | | ✔ | |
| 8. vsftpd (Anon) | | | | ✔ | | | ✔ |
| 9. Samba usermap | | | ✔ | ✔ | | ✔ | |
| 10. Ingreslock | | | ✔ | | | ✔ | |

---

## Lessons Learned / Mitigations

- Disable default/anonymous accounts on FTP, VNC, and Databases.
- Patch services to remove known backdoors (vsftpd, UnrealIRCd).
- Restrict NFS shares to specific IP addresses rather than `/ *`.

