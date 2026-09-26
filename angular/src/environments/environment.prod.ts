// Fill these with the outputs of `sam deploy` (HttpApiUrl / WebSocketUrl)
// before building for production.

import { EnvironmentConfig } from '../app/model/environment-config';

export const environment: EnvironmentConfig = {
  production: true,
  // Both APIs are fronted by CloudFront (same origin). Injected at deploy time
  // from the Terraform outputs http_api_url / websocket_url.
  httpApiUrl: 'https://REPLACE_ME.cloudfront.net',
  websocketUrl: 'wss://REPLACE_ME.cloudfront.net/prod'
};
