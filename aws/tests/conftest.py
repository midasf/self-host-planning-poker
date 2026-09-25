import os

import boto3
import pytest
from moto import mock_aws

from repository import GameRepository

os.environ.setdefault('AWS_DEFAULT_REGION', 'us-east-1')
os.environ.setdefault('AWS_ACCESS_KEY_ID', 'testing')
os.environ.setdefault('AWS_SECRET_ACCESS_KEY', 'testing')


@pytest.fixture
def table():
    with mock_aws():
        resource = boto3.resource('dynamodb', region_name='us-east-1')
        tbl = resource.create_table(
            TableName='poker-test',
            AttributeDefinitions=[
                {'AttributeName': 'PK', 'AttributeType': 'S'},
                {'AttributeName': 'SK', 'AttributeType': 'S'},
            ],
            KeySchema=[
                {'AttributeName': 'PK', 'KeyType': 'HASH'},
                {'AttributeName': 'SK', 'KeyType': 'RANGE'},
            ],
            BillingMode='PAY_PER_REQUEST',
        )
        tbl.wait_until_exists()
        yield tbl


@pytest.fixture
def repo(table):
    return GameRepository(table)
