import security


def test_origin_verified_matches(monkeypatch):
    monkeypatch.setenv('ORIGIN_VERIFY_SECRET', 'sekret')
    assert security.origin_verified({'headers': {'X-Origin-Verify': 'sekret'}})
    # header lookup is case-insensitive
    assert security.origin_verified({'headers': {'x-origin-verify': 'sekret'}})


def test_origin_verified_rejects_missing_or_wrong(monkeypatch):
    monkeypatch.setenv('ORIGIN_VERIFY_SECRET', 'sekret')
    assert not security.origin_verified({'headers': {}})
    assert not security.origin_verified({})
    assert not security.origin_verified({'headers': {'X-Origin-Verify': 'nope'}})


def test_origin_verified_fails_closed_when_unset(monkeypatch):
    monkeypatch.delenv('ORIGIN_VERIFY_SECRET', raising=False)
    assert not security.origin_verified({'headers': {'X-Origin-Verify': 'anything'}})
