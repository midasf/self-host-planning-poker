import time
import uuid
from decimal import Decimal
from typing import Optional

from boto3.dynamodb.conditions import Key

from domain.deck import Deck
from domain.exceptions import (
    DeckDoesNotExistError,
    GameDoesNotExistError,
    GameNotOngoingError,
    InvalidInputError,
)
from domain.game import Game
from domain.player import Player

# Games and connections are auto-expired after this many seconds of no writes.
TTL_SECONDS = 24 * 60 * 60

# Upper bounds on user-supplied strings, to prevent unbounded storage/cost abuse.
MAX_GAME_NAME_LEN = 100
MAX_PLAYER_NAME_LEN = 50


def _validate_name(value, field: str, max_len: int, allow_empty: bool = False) -> str:
    if not isinstance(value, str):
        raise InvalidInputError(f'{field} must be a string')
    if not allow_empty and not value.strip():
        raise InvalidInputError(f'{field} must not be empty')
    if len(value) > max_len:
        raise InvalidInputError(f'{field} must be at most {max_len} characters')
    return value


def _game_pk(game_id: str) -> str:
    return f'GAME#{game_id}'


def _player_sk(player_id: str) -> str:
    return f'PLAYER#{player_id}'


def _conn_pk(connection_id: str) -> str:
    return f'CONN#{connection_id}'


def _to_number(value):
    """Convert a DynamoDB Decimal back to a plain int/float for JSON output."""
    if isinstance(value, Decimal):
        return int(value) if value == value.to_integral_value() else float(value)
    return value


def _to_decimal(value):
    """DynamoDB stores numbers as Decimal; convert card values on the way in."""
    return Decimal(str(value)) if value is not None else None


def _ttl() -> int:
    return int(time.time()) + TTL_SECONDS


class GameRepository:
    """DynamoDB-backed replacement for the in-memory GameManager.

    Each invocation is stateless: a Game is rehydrated from the table, mutated
    in memory using the domain logic, and the change is written back with
    targeted updates so concurrent players don't clobber each other's items.
    """

    def __init__(self, table):
        self.table = table

    # --- deck helper (mirrors GameManager.__get_deck) ---
    @staticmethod
    def _get_deck(deck_name: str) -> Deck:
        if deck_name not in Deck.__members__.keys():
            raise DeckDoesNotExistError(f'Deck {deck_name} does not exist')
        return Deck[deck_name]

    # --- loading ---
    def _load_game(self, game_id: str) -> Game:
        items = self.table.query(
            KeyConditionExpression=Key('PK').eq(_game_pk(game_id))
        ).get('Items', [])
        meta = next((i for i in items if i['SK'] == 'META'), None)
        if meta is None:
            raise GameDoesNotExistError(f'Game {game_id} does not exist')
        game = Game(meta['name'], Deck[meta['deck']])
        game.set_revealed(bool(meta.get('revealed', False)))
        for item in items:
            if not item['SK'].startswith('PLAYER#'):
                continue
            player_id = item['SK'][len('PLAYER#'):]
            player = Player(item['name'], bool(item['spectator']))
            hand = item.get('hand')
            if hand is not None:
                player.set_hand(_to_number(hand))
            game.player_joins(player_id, player)
        return game

    # --- game lifecycle ---
    def create(self, name: str, deck_name: str = 'FIBONACCI') -> str:
        name = _validate_name(name, 'Game name', MAX_GAME_NAME_LEN)
        deck = self._get_deck(deck_name)
        game_id = str(uuid.uuid4())
        self.table.put_item(Item={
            'PK': _game_pk(game_id),
            'SK': 'META',
            'name': name,
            'deck': deck.name,
            'revealed': False,
            'ttl': _ttl(),
        })
        return game_id

    def join(self, game_id: str, player_id: str, player_name: str,
             is_spectator: bool, connection_id: str) -> tuple[dict, dict]:
        player_name = _validate_name(player_name, 'Player name', MAX_PLAYER_NAME_LEN, allow_empty=True)
        self._load_game(game_id)  # raises if the game does not exist
        self.table.put_item(Item={
            'PK': _game_pk(game_id),
            'SK': _player_sk(player_id),
            'name': player_name,
            'spectator': is_spectator,
            'hand': None,
            'connectionId': connection_id,
            'ttl': _ttl(),
        })
        self.table.put_item(Item={
            'PK': _conn_pk(connection_id),
            'SK': 'CONN',
            'gameId': game_id,
            'playerId': player_id,
            'ttl': _ttl(),
        })
        game = self._load_game(game_id)
        return game.info(), game.state()

    def get_connection(self, connection_id: str) -> tuple[str, str]:
        """Resolve a connection to its (game_id, player_id) — replaces the Flask session."""
        conn = self.table.get_item(
            Key={'PK': _conn_pk(connection_id), 'SK': 'CONN'}
        ).get('Item')
        if conn is None:
            raise GameNotOngoingError('Connection is not part of an ongoing game')
        return conn['gameId'], conn['playerId']

    def leave(self, connection_id: str) -> tuple[Optional[str], Optional[dict]]:
        conn = self.table.get_item(
            Key={'PK': _conn_pk(connection_id), 'SK': 'CONN'}
        ).get('Item')
        if conn is None:
            return None, None
        game_id = conn['gameId']
        player_id = conn['playerId']
        self.table.delete_item(Key={'PK': _game_pk(game_id), 'SK': _player_sk(player_id)})
        self.table.delete_item(Key={'PK': _conn_pk(connection_id), 'SK': 'CONN'})
        game = self._load_game(game_id)
        return game_id, game.state()

    def rename_game(self, game_id: str, game_name: str) -> dict:
        game_name = _validate_name(game_name, 'Game name', MAX_GAME_NAME_LEN)
        game = self._load_game(game_id)
        game.name = game_name
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': 'META'},
            UpdateExpression='SET #n = :n, #t = :t',
            ExpressionAttributeNames={'#n': 'name', '#t': 'ttl'},
            ExpressionAttributeValues={':n': game_name, ':t': _ttl()},
        )
        return game.info()

    def set_deck(self, game_id: str, deck_name: str) -> tuple[dict, dict]:
        deck = self._get_deck(deck_name)
        game = self._load_game(game_id)
        deck_changed = game.get_deck() is not deck
        game.set_deck(deck)  # clears hands + revealed when the deck changes
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': 'META'},
            UpdateExpression='SET deck = :d, revealed = :r, #t = :t',
            ExpressionAttributeNames={'#t': 'ttl'},
            ExpressionAttributeValues={':d': deck.name, ':r': game.get_revealed(), ':t': _ttl()},
        )
        if deck_changed:
            self._clear_all_hands(game_id, game)
        return game.info(), game.state()

    def set_player_name(self, game_id: str, player_id: str, player_name: str) -> dict:
        player_name = _validate_name(player_name, 'Player name', MAX_PLAYER_NAME_LEN, allow_empty=True)
        game = self._load_game(game_id)
        game.get_player(player_id).name = player_name  # raises if player not in game
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': _player_sk(player_id)},
            UpdateExpression='SET #n = :n, #t = :t',
            ExpressionAttributeNames={'#n': 'name', '#t': 'ttl'},
            ExpressionAttributeValues={':n': player_name, ':t': _ttl()},
        )
        game = self._load_game(game_id)
        return game.state()

    def set_player_spectator(self, game_id: str, player_id: str, is_spectator: bool) -> dict:
        game = self._load_game(game_id)
        player = game.get_player(player_id)
        player.spectator = is_spectator
        player.clear_hand()
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': _player_sk(player_id)},
            UpdateExpression='SET spectator = :s, #h = :h, #t = :t',
            ExpressionAttributeNames={'#h': 'hand', '#t': 'ttl'},
            ExpressionAttributeValues={':s': is_spectator, ':h': None, ':t': _ttl()},
        )
        game = self._load_game(game_id)
        return game.state()

    def pick_card(self, game_id: str, player_id: str, pick: Optional[int]) -> dict:
        game = self._load_game(game_id)
        game.player_picks(player_id, pick)  # validates card + spectator rules
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': _player_sk(player_id)},
            UpdateExpression='SET #h = :h, #t = :t',
            ExpressionAttributeNames={'#h': 'hand', '#t': 'ttl'},
            ExpressionAttributeValues={':h': _to_decimal(pick), ':t': _ttl()},
        )
        game = self._load_game(game_id)
        return game.state()

    def reveal_cards(self, game_id: str) -> tuple[dict, dict]:
        game = self._load_game(game_id)
        game.reveal_hands()
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': 'META'},
            UpdateExpression='SET revealed = :r, #t = :t',
            ExpressionAttributeNames={'#t': 'ttl'},
            ExpressionAttributeValues={':r': True, ':t': _ttl()},
        )
        return game.state(), game.info()

    def end_turn(self, game_id: str) -> tuple[dict, dict]:
        game = self._load_game(game_id)
        game.end_turn()
        self.table.update_item(
            Key={'PK': _game_pk(game_id), 'SK': 'META'},
            UpdateExpression='SET revealed = :r, #t = :t',
            ExpressionAttributeNames={'#t': 'ttl'},
            ExpressionAttributeValues={':r': False, ':t': _ttl()},
        )
        self._clear_all_hands(game_id, game)
        return game.state(), game.info()

    # --- broadcasting support ---
    def list_connection_ids(self, game_id: str) -> list[str]:
        items = self.table.query(
            KeyConditionExpression=Key('PK').eq(_game_pk(game_id))
        ).get('Items', [])
        return [i['connectionId'] for i in items
                if i['SK'].startswith('PLAYER#') and i.get('connectionId')]

    def _clear_all_hands(self, game_id: str, game: Game) -> None:
        for player_id in game.list_players_uuid():
            self.table.update_item(
                Key={'PK': _game_pk(game_id), 'SK': _player_sk(player_id)},
                UpdateExpression='SET #h = :h',
                ExpressionAttributeNames={'#h': 'hand'},
                ExpressionAttributeValues={':h': None},
            )
