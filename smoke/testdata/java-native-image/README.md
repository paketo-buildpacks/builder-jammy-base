# Java Native Image Sample Application

## Building

```bash
pack build applications/native-image \
  --builder paketobuildpacks/builder-jammy-base \
  --env BP_NATIVE_IMAGE=true
```

## Running

```bash
docker run --rm --tty --publish 8080:8080 applications/native-image
```

## Viewing

```bash
curl -s http://localhost:8080/actuator/health | jq .
```
