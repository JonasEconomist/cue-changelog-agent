FROM golang:1.8-alpine

ADD . $GOPATH/src/github.com/JonasEconomist/cue-changelog-agent

WORKDIR $GOPATH/src/github.com/JonasEconomist/cue-changelog-agent

RUN apk add --no-cache git && go install

CMD $GOPATH/bin/cue-changelog-agent

EXPOSE 9494
