#!/usr/bin/env bash
set -euo pipefail

LOW_PCT=15
VERY_LOW_PCT=12
CRITICAL_PCT=8
SLEEP_SECONDS=10

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME_DIR/hypr-battery-notify.state"

read_battery_dir() {
  local bat
  for bat in /sys/class/power_supply/BAT*; do
    if [[ -d "$bat" ]]; then
      echo "$bat"
      return 0
    fi
  done
  return 1
}

send_notification() {
  local title="$1"
  local body="$2"
  local urgency="$3"
  notify-send -u "$urgency" -a "bateria" "$title" "$body"
}

battery_dir="$(read_battery_dir || true)"
if [[ -z "$battery_dir" ]]; then
  exit 0
fi

last_level="none"
if [[ -f "$STATE_FILE" ]]; then
  last_level="$(cat "$STATE_FILE" 2>/dev/null || echo none)"
fi

while true; do
  capacity="$(cat "$battery_dir/capacity" 2>/dev/null || echo 0)"
  status="$(cat "$battery_dir/status" 2>/dev/null || echo Unknown)"

  if [[ "$status" != "Discharging" ]]; then
    last_level="none"
    echo "$last_level" >"$STATE_FILE"
    sleep "$SLEEP_SECONDS"
    continue
  fi

  if (( capacity <= CRITICAL_PCT )); then
    if [[ "$last_level" != "critical" ]]; then
      send_notification "Alerta apagado" "Bateria en ${capacity}%" critical
      last_level="critical"
      echo "$last_level" >"$STATE_FILE"
    fi
  elif (( capacity <= VERY_LOW_PCT )); then
    if [[ "$last_level" != "very" ]]; then
      send_notification "Bateria muy baja" "Bateria en ${capacity}%" critical
      last_level="very"
      echo "$last_level" >"$STATE_FILE"
    fi
  elif (( capacity <= LOW_PCT )); then
    if [[ "$last_level" != "low" ]]; then
      send_notification "Bateria baja" "Bateria en ${capacity}%" normal
      last_level="low"
      echo "$last_level" >"$STATE_FILE"
    fi
  else
    if [[ "$last_level" != "none" ]]; then
      last_level="none"
      echo "$last_level" >"$STATE_FILE"
    fi
  fi

  sleep "$SLEEP_SECONDS"
done
