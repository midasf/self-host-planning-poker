FROM --platform=$BUILDPLATFORM docker.io/library/node:22-slim AS node_builder
WORKDIR /angular
COPY angular/ /angular
RUN npm config set update-notifier false && \
  npm config set fund false && \
  npm config set audit false && \
  npm ci
RUN npm run build self-host-planning-poker

FROM docker.io/library/python:3.11.7-alpine3.18
RUN adduser -H -D -u 10001 -G root default
WORKDIR /app
COPY --chown=10001:0 flask/ ./
COPY --chown=10001:0 --from=node_builder /angular/dist/self-host-planning-poker ./static
RUN pip install pip==26.1.2 && \
  pip install --requirement requirements.txt && \
  mkdir /data && \
  chown -R 10001:0 /app /data && \
  chmod -R g+w /app /data
USER 10001
CMD [ "gunicorn", "--worker-class", "eventlet", "-w", "1", "app:app", "--bind", "0.0.0.0:8000" ]
