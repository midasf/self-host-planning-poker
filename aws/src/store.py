import os

import boto3

from repository import GameRepository

_table = boto3.resource('dynamodb').Table(os.environ['TABLE_NAME'])
repo = GameRepository(_table)
