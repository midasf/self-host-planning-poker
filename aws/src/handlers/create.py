import json

from domain.exceptions import PlanningPokerException
from store import repo

# CORS is handled by the API Gateway HTTP API cors_configuration (restricted to
# the CloudFront origin), so handlers must not also emit CORS headers.


def _error(status, message, code):
    return {
        'statusCode': status,
        'headers': {'Content-Type': 'application/json'},
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
        'headers': {'Content-Type': 'text/plain'},
        'body': game_id,
    }
