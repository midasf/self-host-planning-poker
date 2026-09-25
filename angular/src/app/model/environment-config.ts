export interface EnvironmentConfig {
  production: boolean;
  // Base URL of the HTTP API (POST {httpApiUrl}/create). From SAM output HttpApiUrl.
  httpApiUrl: string;
  // WebSocket API endpoint (wss://.../prod). From SAM output WebSocketUrl.
  websocketUrl: string;
}
