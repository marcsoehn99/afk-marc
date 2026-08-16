#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <iterations> <feature-slug> [pi flags...]"
  exit 1
fi

iterations=$1
slug=$2
tickets=".scratch/$slug/issues"
spec=".scratch/$slug/spec.md"

shift 2

for ((i = 1; i <= iterations; i++)); do
  echo "Durchlauf $i feature=$slug"

  result=$(
    pi -p --no-session "$@" "
Tickets: $tickets
Spec: $spec

Wenn kein Ticket mit Status ready-for-agent existiert, dessen Blocker alle done sind:
  gib genau <promise>COMPLETE</promise> aus und sonst nichts.

Sonst:
  nimm genau EIN solches Ticket (kleinste Nummer)
  implementiere es mit /implement
  überspringe /code-review — Review kommt in einer eigenen Session
  setze Status in dieser Ticket-Datei auf done
  committe
  NUR EIN TICKET.
"
  )

  echo "$result"

  if [[ "$result" == *"<promise>COMPLETE</promise>"* ]]; then
    echo "Tickets complete after $i iterations."
    exit 0
  fi
done
