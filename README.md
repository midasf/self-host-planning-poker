# Self-host Planning Poker

A hassle-free Planning Poker application that runs serverless on AWS.

[![GitHub last commit](https://img.shields.io/github/last-commit/axeleroy/self-host-planning-poker?logo=github&logoColor=959DA5)](https://github.com/axeleroy/self-host-planning-poker/commits/main)
[![License](https://img.shields.io/github/license/axeleroy/self-host-planning-poker?logo=github&logoColor=959DA5)](https://github.com/axeleroy/self-host-planning-poker/blob/main/LICENSE)
[![Tests](https://github.com/axeleroy/self-host-planning-poker/actions/workflows/tests.yml/badge.svg)](https://github.com/axeleroy/self-host-planning-poker/actions/workflows/tests.yml)
[![Crowdin](https://badges.crowdin.net/self-host-planning-poker/localized.svg)](https://crowdin.com/project/self-host-planning-poker)

## What is it?

This application is intended as a simplified and self-hostable alternative to
[Planning Poker Online](https://planningpokeronline.com/).

It features:

  * Multiple deck types: Fibonacci, modified Fibonacci, T-Shirt sizes, powers of 2 and trust vote (0 to 5)
  * Spectator mode
  * Responsive layout
  * Vote summary
  * Translations _(English, French, German, Italian and Polish. [Contributions welcome!](#im-a-user-and-want-to-contribute-translations))_

It does not have fancy features like issues management, Jira integration or timers.

## Screenshots
<a href="https://github.com/axeleroy/self-host-planning-poker/blob/main/assets/screenshot.png"><img alt="Application screenshot with cards face down" src="https://github.com/axeleroy/self-host-planning-poker/blob/main/assets/screenshot.png" width="412px"></a>
<a href="https://github.com/axeleroy/self-host-planning-poker/blob/main/assets/screenshot.png"><img alt="Application screenshot with cards revealed" src="https://github.com/axeleroy/self-host-planning-poker/blob/main/assets/screenshot-revealed.png" width="412px"></a>

## Deployment

The application runs **serverless on AWS**, deployed by a Terraform CI/CD
pipeline that separates the **management** account (pipeline, state) from the
**workload** account (the running app):

- **`bootstrap/`** — run once in the management account. Creates the Terraform
  state bucket, a CodeStar GitHub connection and a **CodePipeline**
  (Source → Plan → Apply → Security).
- **`infra/`** — the application, created in the workload account via a
  cross-account assumed role: DynamoDB, the Lambdas (from [`aws/src/`](aws/src)),
  the HTTP + WebSocket APIs, and the S3 + CloudFront front-end (behind WAF).
- **`buildspec-*.yml`** — the pipeline steps: `terraform plan` / `apply`, then an
  Angular build (with the API URLs baked in) synced to S3 and a CloudFront
  invalidation.

```bash
# 1. One-time, in the MANAGEMENT account
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # fill github + bucket + workload account
terraform init && terraform apply
# then activate the CodeStar connection in the AWS Console (see output)

# 2. Push to main → the pipeline plans/applies infra/ in the workload account
#    and deploys the front-end. No manual steps.
```

The workload account is set via `target_account_id` / `target_account_role`
(default `OrganizationAccountAccessRole`); the pipeline's CodeBuild role assumes
that role to deploy. State stays in the management account.

### Customization

See [Customizing the application's style and icon](https://github.com/axeleroy/self-host-planning-poker/wiki/Customizing-the-application's-style-and-icon).

## Getting involved

### I'm a developer and I want to help

You are welcome to open Pull Requests resolving issues in the [Project](https://github.com/users/axeleroy/projects/1/views/1) or
tagged [pr-welcome](https://github.com/axeleroy/self-host-planning-poker/issues?q=is%3Aissue+is%3Aopen+label%3Apr-welcome).
Don't forget to mention the issue you want to close 😉

### I'm a user and I need help / I encountered a bug / I have a feature request

[Open an issue](https://github.com/axeleroy/self-host-planning-poker/issues/new) and I'll take a look at it.

### I'm a user and want to contribute translations

There is a [Crowdin project](https://crowdin.com/project/self-host-planning-poker) that lets you add translations for
your language. If your language is not available, feel free to contact me over Crowdin.

## Development

The app consists of two parts:

* a [back-end](aws/) written in Python, running on AWS Lambda behind API Gateway (HTTP + WebSocket) with DynamoDB for state, defined with Terraform ([`infra/`](infra/), [`bootstrap/`](bootstrap/)).
* a [front-end](angular/) written with [Angular](https://angular.io), talking to the WebSocket API over the native `WebSocket` client.

### Back-end development

The serverless back-end lives in [`aws/`](aws/). Create a virtual environment and
install the dev dependencies:

```sh
# Run the following commands in the aws/ folder
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

Run the tests locally with `python -m pytest`. Deployment is handled by the
Terraform pipeline (see [Deployment](#deployment)); the infrastructure lives in
[`infra/`](infra/) and [`bootstrap/`](bootstrap/).

#### Run unit tests

After installing the dev dependencies, run this command in the `aws/` directory:
```sh
python -m pytest
```

### Front-end development

First make sure that [Node.js](https://nodejs.org/en/) (preferably LTS) is installed.
Then, install dependencies and launch the development server

```sh
# Run the following commands in the angular/ folder
npm install
npm start
```
