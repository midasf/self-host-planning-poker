// Fill these with the outputs of `sam deploy` (HttpApiUrl / WebSocketUrl)
// before building for production.

import { EnvironmentConfig } from '../app/model/environment-config';

export const environment: EnvironmentConfig = {
  production: true,
  httpApiUrl: 'https://REPLACE_ME.execute-api.eu-west-1.amazonaws.com',
  websocketUrl: 'wss://REPLACE_ME.execute-api.eu-west-1.amazonaws.com/prod'
};
