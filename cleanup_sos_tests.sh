#!/usr/bin/env bash
set -euo pipefail

API="${API:-https://sos.vsti.cl}"
CC="${CC:-CC-VINA}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: falta jq. En Mac: brew install jq" >&2
  exit 1
fi

echo "== Cerrando tickets abiertos en $CC =="
curl -s "$API/tickets?control_center_code=$CC&limit=200" \
| jq -r '.tickets[]? | select(.state != "CLOSED" and .state != "CANCELLED" and .state != "RESOLVED") | .id' \
| while read -r TICKET_ID; do
  [ -z "$TICKET_ID" ] && continue
  echo "Cerrando ticket $TICKET_ID"
  curl -s -X POST "$API/tickets/$TICKET_ID/close" \
    -H "Content-Type: application/json" \
    -d '{"operator_user_id": null, "closing_notes": "Limpieza de pruebas para nueva validación de mapa"}' \
  | jq -r '.status + " - " + (.message // "")'
done

echo "== Cancelando alertas móviles activas =="
curl -s "$API/public/map-state" \
| jq -r '.mobile_events[]? | "\(.id)|\(.user_id)"' \
| while IFS="|" read -r EVENT_ID USER_ID; do
  [ -z "$EVENT_ID" ] && continue
  echo "Cancelando mobile event $EVENT_ID"
  curl -s -X POST "$API/public/mobile/cancel" \
    -H "Content-Type: application/json" \
    -d "{\"event_id\": \"$EVENT_ID\", \"user_id\": \"$USER_ID\"}" \
  | jq -r '.status + " - " + (.message // "")'
done

echo "== Estado posterior =="
echo "Tickets:"
curl -s "$API/tickets?control_center_code=$CC&limit=20" \
| jq '{total, open: [.tickets[]? | select(.state != "CLOSED" and .state != "CANCELLED" and .state != "RESOLVED") | {id, state, title, created_at}]}'

echo "Mobile events:"
curl -s "$API/public/map-state" \
| jq '{mobile_events: [.mobile_events[]? | {id, state, user_id, created_at}]}'
