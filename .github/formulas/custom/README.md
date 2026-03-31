# Custom Formula

> Define your own commands when Kubernetes or Docker Compose don't fit.
> For: bare-metal, serverless, mobile emulators, PaaS, or exotic setups.

## Setup

In `workspace.yaml`, set formula to `custom` and define your commands:

```yaml
environment:
  formula: custom
  commands:
    health: "./scripts/health-check.sh"
    deploy: "./scripts/deploy.sh SERVICE"
    logs: "./scripts/logs.sh SERVICE"
    restart: "./scripts/restart.sh SERVICE"
    start: "./scripts/start.sh"
    stop: "./scripts/stop.sh"
```

## Contract

Each command must:
- Exit with code 0 on success, non-zero on failure
- Accept `SERVICE` as a placeholder replaced with the service name
- Write to stdout (agent reads the output)

## Example: Mobile Development

```yaml
environment:
  formula: custom
  commands:
    health: "adb devices | grep -q device"
    deploy: "cd services/SERVICE && flutter run --release"
    logs: "adb logcat -t 100"
    restart: "adb shell am force-stop com.example.app"
```

## Example: Serverless (AWS)

```yaml
environment:
  formula: custom
  commands:
    health: "aws lambda list-functions --query 'Functions[].FunctionName' --output table"
    deploy: "cd services/SERVICE && serverless deploy --stage dev"
    logs: "serverless logs -f SERVICE --stage dev --tail"
    restart: "aws lambda update-function-configuration --function-name SERVICE --description 'restart'"
```
