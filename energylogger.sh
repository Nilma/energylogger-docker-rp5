#!/usr/bin/env bash
set -u

# ---------------- CONFIG via environment variables ----------------
SIGMARK_PATH="${SIGMARK_PATH:-./sigmark.sh}"
REMOTE_ADDRESS="${REMOTE_ADDRESS:-192.168.50.2:8000}"   # MacBook/sigless receiver
MARKER_CHANNEL="${MARKER_CHANNEL:-CH1}"

LOADS="${LOADS:-0 5 10 15 20 30 40 50 60 70 80 90 100}"
REPEATS="${REPEATS:-35}"
SAMPLE_PERIODS="${SAMPLE_PERIODS:-2 1 0.5 0.2 0.1 0.05 0.04 0.03}"
WORK_DURATION="${WORK_DURATION:-80s}"
COOLDOWN="${COOLDOWN:-20}"
PRE_IDLE="${PRE_IDLE:-0}"
OUTDIR="${OUTDIR:-/data}"
CPU_WORKERS="${CPU_WORKERS:-1}"
# ------------------------------------------------------------------

mkdir -p "$OUTDIR"

send_marker_raw() {
  local msg="$1"
  sh "$SIGMARK_PATH" "$REMOTE_ADDRESS" "$MARKER_CHANNEL" "$msg" || {
    echo "WARN: failed to send marker: $msg" >&2
    return 0
  }
}

send_start() { send_marker_raw "start,sigmark,$1"; }
send_stop()  { send_marker_raw "stop,sigmark,$1"; }

run_baseline() {
  local repeat="$1"
  local load="$2"
  local sampleperiod="0"
  echo "=== Baseline: repeat=$repeat load=$load sampleperiod=$sampleperiod ==="
  send_start "$repeat,$load,$sampleperiod"
  stress-ng --cpu "$CPU_WORKERS" -l "$load" -t "$WORK_DURATION" &
  local work_pid=$!
  wait "$work_pid"
  send_stop "$repeat,$load,$sampleperiod"
  echo "Done baseline. Cooling down $COOLDOWN seconds."
  sleep "$COOLDOWN"
}

run_logged() {
  local repeat="$1"
  local load="$2"
  local sampleperiod="$3"
  local ts
  ts="$(date +"%Y%m%d_%H%M%S")"
  local outfile="$OUTDIR/pmic_log_${repeat}_${load}_${sampleperiod}s_${ts}.csv"

  echo "=== Logged: repeat=$repeat load=$load sampleperiod=$sampleperiod outfile=$outfile ==="
  send_start "$repeat,$load,$sampleperiod"

  ./run_with_logging "$sampleperiod" "$PRE_IDLE" "2" "$outfile" \
    stress-ng --cpu "$CPU_WORKERS" -l "$load" -t "$WORK_DURATION"

  send_stop "$repeat,$load,$sampleperiod"
  echo "Done logged run. Data in $outfile. Cooling down $COOLDOWN seconds."
  sleep "$COOLDOWN"
}

for load in $LOADS; do
  for repeat in $(seq 1 "$REPEATS"); do
    run_baseline "$repeat" "$load"
    for period in $SAMPLE_PERIODS; do
      run_logged "$repeat" "$load" "$period"
    done
  done
done

echo "All experiments complete. CSV files are in $OUTDIR"
