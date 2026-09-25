import uuid

import pytest

from domain.exceptions import (
    DeckDoesNotExistError,
    GameDoesNotExistError,
    GameNotOngoingError,
    InvalidCardValueError,
    SpectatorCannotPlayError,
)


def test_create_stores_game(repo):
    game_id = repo.create('PBR Team Pizza')
    assert uuid.UUID(game_id)
    info, state = repo.join(game_id, 'p1', 'John', False, 'conn1')
    assert info == {'name': 'PBR Team Pizza', 'deck': 'FIBONACCI', 'revealed': False}
    assert state == {'p1': {'name': 'John', 'spectator': False, 'hasPicked': False}}


def test_create_other_deck(repo):
    game_id = repo.create('Pasta', 'POWERS')
    info, _ = repo.join(game_id, 'p1', 'John', False, 'conn1')
    assert info['deck'] == 'POWERS'


def test_create_invalid_deck(repo):
    with pytest.raises(DeckDoesNotExistError):
        repo.create('Pizza', 'PIZZA')


def test_join_unknown_game_raises(repo):
    with pytest.raises(GameDoesNotExistError):
        repo.join(str(uuid.uuid4()), 'p1', 'John', False, 'conn1')


def test_get_connection_after_join(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    assert repo.get_connection('conn1') == (game_id, 'p1')


def test_get_connection_unknown_raises(repo):
    with pytest.raises(GameNotOngoingError):
        repo.get_connection('nope')


def test_pick_card_and_reveal(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.join(game_id, 'p2', 'Peter', False, 'conn2')

    hidden = repo.pick_card(game_id, 'p1', 8)
    assert hidden['p1']['hasPicked'] is True
    assert 'hand' not in hidden['p1']  # hidden until revealed

    state, info = repo.reveal_cards(game_id)
    assert info['revealed'] is True
    assert state['p1']['hand'] == 8
    assert state['p2']['hand'] is None


def test_pick_invalid_card_raises(repo):
    game_id = repo.create('Pizza', 'POWERS')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    with pytest.raises(InvalidCardValueError):
        repo.pick_card(game_id, 'p1', 13)


def test_spectator_cannot_pick(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', True, 'conn1')
    with pytest.raises(SpectatorCannotPlayError):
        repo.pick_card(game_id, 'p1', 8)


def test_fractional_card_roundtrips(repo):
    game_id = repo.create('Pizza', 'MODIFIED_FIBONACCI')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.pick_card(game_id, 'p1', 0.5)
    state, _ = repo.reveal_cards(game_id)
    assert state['p1']['hand'] == 0.5


def test_end_turn_clears_hands(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.pick_card(game_id, 'p1', 8)
    repo.reveal_cards(game_id)

    state, info = repo.end_turn(game_id)
    assert info['revealed'] is False
    assert state['p1']['hasPicked'] is False


def test_set_deck_change_clears_hands(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.pick_card(game_id, 'p1', 8)

    info, state = repo.set_deck(game_id, 'POWERS')
    assert info['deck'] == 'POWERS'
    assert state['p1']['hasPicked'] is False


def test_set_invalid_deck_raises(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    with pytest.raises(DeckDoesNotExistError):
        repo.set_deck(game_id, 'holdem')


def test_rename_game(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    info = repo.rename_game(game_id, 'Pasta')
    assert info['name'] == 'Pasta'


def test_set_player_name(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    state = repo.set_player_name(game_id, 'p1', 'Johnny')
    assert state['p1']['name'] == 'Johnny'


def test_set_spectator_clears_hand(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.pick_card(game_id, 'p1', 8)
    state = repo.set_player_spectator(game_id, 'p1', True)
    assert state['p1']['spectator'] is True
    assert state['p1']['hasPicked'] is False


def test_leave_removes_player(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.join(game_id, 'p2', 'Peter', False, 'conn2')

    left_game_id, state = repo.leave('conn1')
    assert left_game_id == game_id
    assert 'p1' not in state
    assert 'p2' in state
    with pytest.raises(GameNotOngoingError):
        repo.get_connection('conn1')


def test_leave_unknown_connection_is_noop(repo):
    assert repo.leave('nope') == (None, None)


def test_list_connection_ids(repo):
    game_id = repo.create('Pizza')
    repo.join(game_id, 'p1', 'John', False, 'conn1')
    repo.join(game_id, 'p2', 'Peter', False, 'conn2')
    assert set(repo.list_connection_ids(game_id)) == {'conn1', 'conn2'}
