import json
from decimal import Decimal

import boto3
from botocore.exceptions import ClientError


def _json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    raise TypeError(f'Object of type {type(value)} is not JSON serializable')


def _dumps(payload: dict) -> bytes:
    return json.dumps(payload, default=_json_default).encode('utf-8')


def make_management_client(event):
    """Build an API Gateway Management API client bound to this WebSocket API."""
    ctx = event['requestContext']
    endpoint = f"https://{ctx['domainName']}/{ctx['stage']}"
    return boto3.client('apigatewaymanagementapi', endpoint_url=endpoint)


def _post(client, connection_id: str, payload: dict) -> bool:
    """Send a frame to one connection. Returns False if the connection is gone."""
    try:
        client.post_to_connection(ConnectionId=connection_id, Data=_dumps(payload))
        return True
    except client.exceptions.GoneException:
        return False
    except ClientError:
        return False


def broadcast_event(client, connection_ids: list[str], event_name: str, data) -> None:
    """Fan out an event frame to every connection in a game (socket.io room equivalent)."""
    frame = {'type': 'event', 'event': event_name, 'data': data}
    for connection_id in connection_ids:
        _post(client, connection_id, frame)


def send_ack(client, connection_id: str, request_id, data=None, error=None) -> None:
    """Reply to the connection that sent a request, matched client-side by requestId."""
    if request_id is None:
        return
    frame = {'type': 'ack', 'requestId': request_id}
    if error is not None:
        frame['error'] = error
    else:
        frame['data'] = data
    _post(client, connection_id, frame)
