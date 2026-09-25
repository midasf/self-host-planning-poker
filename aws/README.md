# Planning Poker — Lambda backend code (AWS)

Real-time Planning Poker on AWS Lambda. Replaces the Flask + Flask-SocketIO
single-container backend.

This folder holds the **Lambda source and its tests**. The infrastructure that
deploys it (DynamoDB, the HTTP + WebSocket APIs, S3 + CloudFront) is defined with
Terraform in [`../infra`](../infra) and shipped by the CodePipeline set up in
[`../bootstrap`](../bootstrap) — see the repository [README](../README.md#deployment).
`infra/lambda.tf` zips this `src/` directory as the function code.

## Architecture

```
Browser ── HTTPS ─► HTTP API ──► CreateFunction ─┐
        │                                         ├─► DynamoDB (single table)
        └── WSS ──► WebSocket API ──► ws.py ──────┘        │
                    $connect / $disconnect / $default      └─ postToConnection (broadcast)
```

- **HTTP API** (`POST /create`) → `handlers/create.py` — creates a game, returns its id.
- **WebSocket API** with route selection on `$request.body.action`:
  - `$connect` → accept the socket.
  - `$disconnect` → remove the player, broadcast state to the room.
  - `$default` → `handlers/ws.default_handler` dispatches the actions
    (`join`, `rename_game`, `set_deck`, `set_player_name`, `set_spectator`,
    `pick_card`, `reveal_cards`, `end_turn`).
- **DynamoDB** single table, see `src/repository.py`:

  | PK | SK | Purpose |
  |---|---|---|
  | `GAME#<id>` | `META` | game name, deck, revealed flag |
  | `GAME#<id>` | `PLAYER#<playerId>` | a player's name/spectator/hand + their connectionId |
  | `CONN#<connId>` | `CONN` | maps a connection to its game/player (replaces the Flask session) |

  Items carry a `ttl` attribute so abandoned games/connections auto-expire.

The pure domain logic in `src/domain/` (`game.py`, `player.py`, `deck.py`,
`exceptions.py`) is unchanged from the original Flask app.

## Client protocol

Client → server frames: `{ "action": "...", "requestId": "...", "data": { ... } }`

Server → client frames:
- events (broadcast): `{ "type": "event", "event": "state|info|new_game", "data": ... }`
- acks (to the sender, matched by `requestId`):
  `{ "type": "ack", "requestId": "...", "data": ... }` or
  `{ "type": "ack", "requestId": "...", "error": { "error": true, "message": "...", "code": 4001 } }`

## Deploy

Deployment is handled by the Terraform pipeline — push to `main` and the
CodePipeline runs `terraform plan`/`apply` for [`../infra`](../infra) in the
workload account, then builds the Angular app (baking in the API URLs) and syncs
it to S3. See the repository [README](../README.md#deployment). There is no
manual build/upload step for the backend.

## Tests

```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
python -m pytest
```

Tests use [moto](https://github.com/getmoto/moto) to mock DynamoDB, so no AWS
resources are created.

## Manual smoke test

After deploying, you can exercise the WebSocket API with
[`wscat`](https://github.com/websockets/wscat):

```sh
# create a game
curl -X POST "$HttpApiUrl/create" -H 'Content-Type: application/json' \
  -d '{"name":"Demo","deck":"FIBONACCI"}'
# -> prints a game id

wscat -c "$WebSocketUrl"
> {"action":"join","requestId":"1","data":{"game":"<GAME_ID>","name":"Alice","spectator":false}}
> {"action":"pick_card","requestId":"2","data":{"card":8}}
> {"action":"reveal_cards","requestId":"3"}
```
