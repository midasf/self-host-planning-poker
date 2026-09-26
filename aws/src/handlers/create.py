import json

from domain.exceptions import PlanningPokerException
from store import repo

_CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
}


def _error(status, message, code):
    return {
        'statusCode': status,
        'headers': {**_CORS_HEADERS, 'Content-Type': 'application/json'},
        'body': json.dumps({'error': True, 'message': message, 'code': code}),
    }


def handler(event, context):
    """HTTP API handler for POST /create. Returns the new game id as plain text."""
    try:
        body = json.loads(event.get('body') or '{}')
    except (ValueError, TypeError):
        return _error(400, 'Request body must be valid JSON', 0)
    if not isinstance(body, dict):
        return _error(400, 'Request body must be a JSON object', 0)
    try:
        game_id = repo.create(body.get('name'), body.get('deck', 'FIBONACCI'))
    except PlanningPokerException as e:
        return _error(400, str(e), e.code)
    return {
        'statusCode': 200,
        'headers': {**_CORS_HEADERS, 'Content-Type': 'text/plain'},
        'body': game_id,
    }
