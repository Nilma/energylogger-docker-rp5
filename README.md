# Dockerized EnergyLogger for Raspberry Pi 5 + Sigless Simulation on MacBook

This guide documents the complete experimental setup for running the Dockerized EnergyLogger on a Raspberry Pi 5 while using Sigless simulation on a MacBook for synchronized marker logging and simulated external power traces.

## Devices and IPs

| Device | Role | IP |
|---|---|---|
| MacBook Pro | Runs Sigless simulation | 192.168.50.2 |
| Raspberry Pi 5 | Runs Dockerized EnergyLogger | 192.168.50.106 |

---

# 1. Install Docker on Raspberry Pi 5

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
sudo reboot
```

Verify:

```bash
docker --version
```

---

# 2. Verify PMIC Access on RP5

Run outside Docker:

```bash
vcgencmd pmic_read_adc
```

You should see current and voltage channels.

---

# 3. Start Sigless on MacBook

Go to your Sigless folder:

```bash
cd ~/path/to/sigless-0.4.8-all
```

Make executable:

```bash
chmod +x sigless-0.4.8-macos-arm64
```

Run Sigless simulation:

```bash
./sigless-0.4.8-macos-arm64 \
  --simulate \
  --ch1 \
  --web 9000 \
  --verbose 2 \
  --out ./sigless-logs
```

Expected:

```text
Simulation mode enabled. Ignoring Siglent connection.
Serving on http://localhost:9000
```

Keep this terminal running.

---

# 4. Open Sigless Web UI

Open:

```text
http://localhost:9000
```

---

# 5. Copy Experiment Folder to RP5

From MacBook:

```bash
scp -r energylogger-docker-rp5 pi@192.168.50.106:~/
```

SSH into RP5:

```bash
ssh pi@192.168.50.106
```

Go to project folder:

```bash
cd ~/energylogger-docker-rp5
mkdir -p results
```

---

# 6. Dockerfile Requirements

Ensure the Dockerfile includes:

```dockerfile
curl \
```

inside the apt install list.

Example:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       ca-certificates \
       curl \
       gcc \
       libc6-dev \
       make \
       netcat-openbsd \
       stress-ng \
    && rm -rf /var/lib/apt/lists/*
```

---

# 7. Build Docker Image on RP5

```bash
docker build --no-cache -t energylogger-rp5:latest .
```

Verify:

```bash
docker images
```

---

# 8. Working sigmark.sh

```bash
#!/bin/sh
REMOTE="$1"
CHANNEL="$2"
MESSAGE="$3"

if [ "$CHANNEL" = "CH1" ]; then
  CHANNEL_ID="ch1"
else
  CHANNEL_ID="ch2"
fi

curl -sS -X POST "http://$REMOTE/api/log" \
  -H "Content-Type: application/json" \
  -d "{\"channelId\":\"$CHANNEL_ID\",\"message\":\"$MESSAGE\"}"
```

---

# 9. Quick Smoke Test

Run on RP5:

```bash
docker run --rm -it \
  --privileged \
  --network host \
  -v /usr/bin/vcgencmd:/usr/bin/vcgencmd:ro \
  -v "$PWD/results:/data" \
  -e REMOTE_ADDRESS="192.168.50.2:9000" \
  -e MARKER_CHANNEL="CH1" \
  -e LOADS="0" \
  -e REPEATS="1" \
  -e SAMPLE_PERIODS="1" \
  -e WORK_DURATION="5s" \
  -e COOLDOWN="2" \
  energylogger-rp5:latest
```

Expected output:

```text
{"status":"ok"}
Done logged run.
All experiments complete.
```

---

# 10. PMIC Result Files

On RP5:

```bash
ls -lh results
```

Preview:

```bash
head results/*.csv
```

---

# 11. Sigless Result Files

On MacBook:

```bash
ls -lh sigless-logs
```

Example:

```text
sigless.1779710350305.CH1-0.csv
```

---

# 12. Full Experiment Run

```bash
docker run --rm -it \
  --privileged \
  --network host \
  -v /usr/bin/vcgencmd:/usr/bin/vcgencmd:ro \
  -v "$PWD/results:/data" \
  -e REMOTE_ADDRESS="192.168.50.2:9000" \
  -e MARKER_CHANNEL="CH1" \
  energylogger-rp5:latest
```

Default parameters:

| Parameter | Value |
|---|---|
| Loads | 0 5 10 15 20 30 40 50 60 70 80 90 100 |
| Repeats | 35 |
| Sample Periods | 2 1 0.5 0.2 0.1 0.05 0.04 0.03 |
| Work Duration | 80s |
| Cooldown | 20s |

---

# 13. Important Docker Flags

## --privileged

Allows firmware and hardware access.

## --network host

Allows RP5 container to communicate with Sigless on MacBook.

## -v /usr/bin/vcgencmd:/usr/bin/vcgencmd:ro

Mounts Raspberry Pi firmware utility into the container.

## -v "$PWD/results:/data"

Persists CSV files outside container.

---

# 14. Troubleshooting

## vcgencmd not found

Add:

```bash
-v /usr/bin/vcgencmd:/usr/bin/vcgencmd:ro
```

## curl not found

Add curl to Dockerfile packages and rebuild.

## 400 Bad Request

Old Sigless API format.

Use:

```text
POST /api/log
```

with JSON body.

## Missing channelId

Fix JSON payload in sigmark.sh.

---

# 15. Final Working Setup

Validated working pipeline:

```text
RP5 Docker Container
    -> PMIC Logger
    -> stress-ng
    -> sigmark.sh
            |
            v
MacBook Sigless Simulation
    -> simulated power logs
    -> marker logs
    -> CSV exports
```

This setup supports:
- Docker energy experiments
- PMIC analysis
- synchronized markers
- simulated external power traces

