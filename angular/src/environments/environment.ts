// This file can be replaced during build by using the `fileReplacements` array.
// `ng build` replaces `environment.ts` with `environment.prod.ts`.
// The list of file replacements can be found in `angular.json`.
//
// Fill these with the outputs of `sam deploy` (HttpApiUrl / WebSocketUrl).

import { EnvironmentConfig } from '../app/model/environment-config';

export const environment: EnvironmentConfig = {
  production: false,
  httpApiUrl: 'https://REPLACE_ME.execute-api.eu-west-1.amazonaws.com',
  websocketUrl: 'wss://REPLACE_ME.execute-api.eu-west-1.amazonaws.com/prod'
};
