# Node.js Sample App using NPM

## Building

`pack build npm-sample --buildpack docker.io/paketobuildpacks/nodejs`

## Running

`docker run --interactive --tty --publish 8080:8080 npm-sample`

## Viewing

`curl http://localhost:8080`
