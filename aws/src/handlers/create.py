import json

from domain.exceptions import PlanningPokerException
from store import repo

_CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
}


def handler(event, context):
    """HTTP API handler for POST /create. Returns the new game id as plain text."""
    try:
        body = json.loads(event.get('body') or '{}')
        game_id = repo.create(body['name'], body.get('deck', 'FIBONACCI'))
    except PlanningPokerException as e:
        return {
            'statusCode': 400,
            'headers': {**_CORS_HEADERS, 'Content-Type': 'application/json'},
            'body': json.dumps({'error': True, 'message': str(e), 'code': e.code}),
        }
    return {
        'statusCode': 200,
        'headers': {**_CORS_HEADERS, 'Content-Type': 'text/plain'},
        'body': game_id,
    }
