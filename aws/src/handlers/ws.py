import json
import uuid

from broadcast import broadcast_event, make_management_client, send_ack
from domain.exceptions import PlanningPokerException
from security import origin_verified
from store import repo


def connect_handler(event, context):
    """$connect — accept the socket only if it came through CloudFront (origin-verify)."""
    if not origin_verified(event):
        return {'statusCode': 401}
    return {'statusCode': 200}


def disconnect_handler(event, context):
    """$disconnect — remove the player and broadcast the updated state to the room."""
    connection_id = event['requestContext']['connectionId']
    game_id, state = repo.leave(connection_id)
    if game_id is not None:
        client = make_management_client(event)
        broadcast_event(client, repo.list_connection_ids(game_id), 'state', state)
    return {'statusCode': 200}


def default_handler(event, context):
    """$default — dispatch client actions, broadcast results, and ack the sender."""
    connection_id = event['requestContext']['connectionId']
    body = json.loads(event.get('body') or '{}')
    action = body.get('action')
    data = body.get('data') or {}
    request_id = body.get('requestId')
    client = make_management_client(event)

    try:
        ack = _dispatch(action, connection_id, data, client)
        send_ack(client, connection_id, request_id, data=ack)
    except PlanningPokerException as e:
        send_ack(client, connection_id, request_id,
                 error={'error': True, 'message': str(e), 'code': e.code})
    except Exception as e:  # noqa: BLE001 - surface any failure to the client, mirror on_error_handler
        send_ack(client, connection_id, request_id,
                 error={'error': True, 'message': str(e), 'code': 0})
    return {'statusCode': 200}


def _dispatch(action, connection_id, data, client):
    if action == 'join':
        game_id = data['game']
        player_id = data.get('playerId') or str(uuid.uuid4())
        info, state = repo.join(game_id, player_id, data['name'], data['spectator'], connection_id)
        broadcast_event(client, repo.list_connection_ids(game_id), 'state', state)
        info['playerId'] = player_id
        return info

    game_id, player_id = repo.get_connection(connection_id)

    if action == 'rename_game':
        info = repo.rename_game(game_id, data['name'])
        broadcast_event(client, repo.list_connection_ids(game_id), 'info', info)

    elif action == 'set_deck':
        info, state = repo.set_deck(game_id, data['deck'])
        connection_ids = repo.list_connection_ids(game_id)
        broadcast_event(client, connection_ids, 'info', info)
        broadcast_event(client, connection_ids, 'state', state)

    elif action == 'set_player_name':
        state = repo.set_player_name(game_id, player_id, data['name'])
        broadcast_event(client, repo.list_connection_ids(game_id), 'state', state)

    elif action == 'set_spectator':
        state = repo.set_player_spectator(game_id, player_id, data['spectator'])
        broadcast_event(client, repo.list_connection_ids(game_id), 'state', state)

    elif action == 'pick_card':
        state = repo.pick_card(game_id, player_id, data['card'])
        broadcast_event(client, repo.list_connection_ids(game_id), 'state', state)

    elif action == 'reveal_cards':
        state, info = repo.reveal_cards(game_id)
        connection_ids = repo.list_connection_ids(game_id)
        broadcast_event(client, connection_ids, 'state', state)
        broadcast_event(client, connection_ids, 'info', info)

    elif action == 'end_turn':
        state, info = repo.end_turn(game_id)
        connection_ids = repo.list_connection_ids(game_id)
        broadcast_event(client, connection_ids, 'state', state)
        broadcast_event(client, connection_ids, 'info', info)
        broadcast_event(client, connection_ids, 'new_game', None)

    return None
