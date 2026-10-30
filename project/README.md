# Empirical Seminar: Compromise of a Small Team

## Overview

In this seminar you study one fictional team, **LabOps**. LabOps is four people who administer a Linux server over SSH and publish an internal install script to their users.

You will reproduce a short compromise on your own machine, keep the evidence, and turn that evidence into a risk assessment and a security plan. The techniques are the ones from the tutorials. This repository does not repeat those procedures.

| Step | What fails | Tutorial |
|------|------------|----------|
| 1 | A helpdesk mailbox accepts a forged login page | `lab02` |
| 2 | The server still allows a weak SSH password | `lab03` |
| 3 | A release key is replaced and the fingerprint is never checked | `lab04`, `lab05` |
| 4 | A database password sits in a file that can be committed | `lab06` |
| 5 | `install.sh` is changed and nobody checks the signature | `lab07` |

The grade is for the argument you build from the evidence: what is at risk, how serious each weakness is, and which controls LabOps should adopt.

---

## Scenario

LabOps maintains an internal enrollment helper for a faculty.

Assets you must cover:

- the helpdesk mailbox, `helpdesk@labops.example`
- the SSH account on the enrollment server
- the GPG key that signs releases
- `install.sh`, the script users download
- `secrets.env`, which holds a database password

Users of the helper are students. Treat the database as if it contains personal data.

LabOps is not a real organization. Every test stays on your computer.

---

## Objectives

- Describe the assets and how the data moves.
- Collect empirical evidence for each row in the table above.
- Rate the risks.
- Write a security plan with five to eight controls LabOps can actually apply.
- State the legal and ethical limits of the tests you ran.

---

## Rules

- Attack only this local lab: your container, your files, and a phishing page that never leaves your computer.
- Do not scan, phish, or send traffic to any system you do not own.
- Do not put real passwords, real API keys, or real personal data in the report.
- Screenshots may show the lab passwords from this README. Nothing else.

---

## Lab setup

Work from the `project` directory of this repository. Kali or Ubuntu is enough. You need Docker, an SSH client, `nmap`, `hydra`, and `gnupg`.

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-v2 openssh-client nmap hydra gnupg
```

On Kali these packages are usually already present. If your user cannot talk to Docker, add the user to the `docker` group and open a new shell.

### 1. Start the SSH server

Compose builds a small Ubuntu image and publishes SSH on `127.0.0.1` port `2222`. The server starts as root so it can open a session for every lab account. `create_users.sh` runs on each start.

```bash
docker compose up -d --build
docker compose ps
```

If SSH reports that the remote host identification has changed, the container was recreated and the old host key is stale. Remove it and connect again:

```bash
ssh-keygen -R "[localhost]:2222"
```

### 2. Lab accounts

These accounts exist as soon as the container is up:

| User | Password | Role in the scenario |
|------|----------|----------------------|
| `weakuser` | `123456` | Abandoned admin account |
| `mediumuser` | `Password123` | Daily account, reused password |
| `stronguser` | `Str0ng!Pass#2026` | Break-glass account |
| `student` | `password123` | Daily student account |

Confirm that `weakuser` can log in:

```bash
ssh weakuser@localhost -p 2222
```

To reset the lab passwords without rebuilding:

```bash
docker exec -it ssh_lab bash /create_users.sh
```

### 3. Prepare the release workspace

This directory is the "download page" and the secrets file. It stays on the host. It is not inside the container.

```bash
mkdir -p "$HOME/labops/release" "$HOME/labops/evidence"
printf 'echo LabOps enrollment helper 1.0\n' > "$HOME/labops/release/install.sh"
printf 'DB_PASSWORD=lab-demo-pass\n' > "$HOME/labops/release/secrets.env"
chmod 600 "$HOME/labops/release/secrets.env"
cd "$HOME/labops/release"
sha256sum install.sh > install.sh.sha256
```

Create two GPG keys that share the same name and address, as in `lab04` and `lab05`. Each key lives in its own keyring, so they do not land in your personal `~/.gnupg` and `-u` is never ambiguous. The lab keys have no passphrase.

```bash
mkdir -p "$HOME/labops/gnupg-release" "$HOME/labops/gnupg-attacker"
chmod 700 "$HOME/labops/gnupg-release" "$HOME/labops/gnupg-attacker"

gpg --batch --pinentry-mode loopback --passphrase '' \
  --homedir "$HOME/labops/gnupg-release" \
  --quick-generate-key "LabOps Release <labops-release@labops.example>" rsa4096 sign,encr 1y

gpg --batch --pinentry-mode loopback --passphrase '' \
  --homedir "$HOME/labops/gnupg-attacker" \
  --quick-generate-key "LabOps Release <labops-release@labops.example>" rsa4096 sign,encr 1y
```

Same address, different fingerprint. That is the point of the check in `lab05`.

Sign the checksum with the real release key:

```bash
gpg --homedir "$HOME/labops/gnupg-release" \
  --detach-sign --armor \
  -u labops-release@labops.example \
  install.sh.sha256
```

`gpg: No secret key` means this homedir does not contain the private key yet. Generate it with the command above, then sign again. Do not drop `--homedir`. Without it, GnuPG looks in `~/.gnupg`.

Save both fingerprints before you simulate the substitution:

```bash
{
  echo "=== release key ==="
  gpg --homedir "$HOME/labops/gnupg-release" --fingerprint labops-release@labops.example
  echo "=== attacker key ==="
  gpg --homedir "$HOME/labops/gnupg-attacker" --fingerprint labops-release@labops.example
} > "$HOME/labops/evidence/fingerprints.txt"
```

### 4. Where to put evidence

Save command output and screenshots under `$HOME/labops/evidence/`:

```text
01-phishing.png
02-nmap.txt
03-ssh-weak.txt
04-fingerprints.txt
05-signature-fail.txt
06-secrets.txt
```

The report quotes these files. A screenshot without the command that produced it is not evidence.

### 5. Stop the lab

```bash
docker compose down
```

`docker compose down` does not delete the files in `$HOME/labops`.

---

## Tasks

Do the work in this order. For each task, write what you did, paste the evidence, and state what LabOps would have seen.

### 1. Assets

One page. List the five assets, who uses them, and what an attacker gets if the asset is lost. Mark which assets contain personal data.

### 2. Phishing (`lab02`)

Reuse the local login page from `lab02`. Do not mail it and do not host it for anyone else.

Evidence: a screenshot of the page and five signs a helpdesk employee should notice before typing a password.

### 3. SSH (`lab03`)

Point the tools at `localhost` port `2222` only.

- Scan the published port with `nmap` and save the output.
- Run one Hydra attempt against `weakuser` with `passwords.txt` from this directory.
- Try `stronguser` only long enough to show that the same wordlist does not succeed in a short run. Stop the tool. Do not leave Hydra running.

```bash
nmap -sV -p 2222 localhost
hydra -l weakuser -P passwords.txt ssh://localhost:2222
```

Record success or failure, the password found, and the rough time. You do not need a full experiment matrix.

### 4. Release key (`lab04`, `lab05`)

Show both fingerprints from `fingerprints.txt`. Export the public key from `gnupg-attacker` and import it into an empty keyring, as if it had arrived by email under the real address. Encrypt a short note to that key and decrypt it with `gnupg-attacker`.

Evidence: the two fingerprints and a sentence on how LabOps should have compared them out of band.

### 5. Secrets (`lab06`)

Show `secrets.env` as a file that must not be committed. Encrypt it with GPG and show the ciphertext. State what remains exposed if someone has already cloned a repository that once contained the plaintext.

### 6. Tampered install script (`lab07`)

Change one line in `install.sh`. Check the checksum and the signature. Save the failing verification.

### 7. Risk assessment

Rate each demonstrated weakness. Use this scale: likelihood and impact are Low, Medium, or High. Overall risk is your judgment, justified in one or two sentences.

| Asset | Weakness | Evidence | Likelihood | Impact | Risk |
|-------|----------|----------|------------|--------|------|
| | | | | | |

### 8. Security plan

Five to eight controls. For each control write:

- which weakness it addresses
- what LabOps changes on Monday morning
- which tutorial practice it comes from
- what risk remains

A control you cannot connect to your evidence does not count. Useful starting points, if your evidence supports them:

- SSH keys for administration, password login disabled
- remove or lock `weakuser`
- compare release-key fingerprints in person or by a second channel before use
- publish `install.sh.sha256` and `install.sh.sha256.asc` with every release
- refuse to run a script when `gpg --verify` fails
- encrypt secrets and keep them out of git
- a short rule for the helpdesk mailbox: no password typed into a page reached from email

Name the control in a framework if you want to (NIST CSF function, or an ISO/IEC 27001 control). The name is not a substitute for the Monday-morning change.

### 9. Legal and ethical note

One page.

- The enrollment helper stores personal data. State which GDPR duties matter here (purpose, access control, and what LabOps does if the database password has already leaked). You are not writing a legal opinion.
- Say whether LabOps, as described, would be an essential or important entity under NIS2, and why.
- State that your tests were limited to the container and the local files, and what you would have needed before testing anyone else's server.

---

## Deliverable

A report of 8–12 pages, plus the `evidence` directory.

1. Introduction and scenario
2. Assets
3. Method and lab setup
4. Evidence from the five steps
5. Risk assessment
6. Security plan
7. Legal and ethical note
8. Conclusion

Submit `report.pdf` or `report.md` and the evidence files in your project folder, using the submission process announced for the tutorials.

---

## Evaluation

| Criterion | Points |
|-----------|--------|
| Assets and scenario are concrete | 10 |
| Evidence is complete and comes from your own run | 25 |
| Risks are rated and justified | 20 |
| Security plan follows from the evidence | 25 |
| Legal and ethical limits are stated correctly | 10 |
| The report is readable without the author present | 10 |

A working Hydra command with no risk table is an incomplete seminar. A risk table with no evidence is also incomplete.

---

## Suggested schedule

| Hours | Work |
|-------|------|
| 2 | Setup, assets, phishing evidence |
| 3 | SSH, release key, secrets, tampered script |
| 3 | Risk table, security plan, legal note |
| 2 | Write the report and check that every claim has a file in `evidence` |
