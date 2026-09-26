import os


def origin_verified(event) -> bool:
    """True if the request carries the CloudFront origin-verify secret.

    CloudFront injects the X-Origin-Verify header on every request it forwards,
    so this rejects requests that hit the execute-api URL directly. Fails closed:
    if the secret isn't configured, every request is rejected (Terraform always
    sets ORIGIN_VERIFY_SECRET, so this only trips on misconfiguration).
    """
    expected = os.environ.get('ORIGIN_VERIFY_SECRET')
    if not expected:
        return False
    headers = event.get('headers') or {}
    for key, value in headers.items():
        if key.lower() == 'x-origin-verify':
            return value == expected
    return False
