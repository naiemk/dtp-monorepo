# AI Node Architecture

The AI node consists of a set of Docker images. You can build your own AI service or mix and match existing ones. An AI node consists of the following items:

1) The AI interface. This is a docker image (ts/node) that will be responsible for system operations, and is built by DTN team.

2) The AI engine. This is a docker image, that is responsible for executing queries. This should implement two http APIs on port 8026 (`requestSync` and `requestAsync`)

## On-chain components

- A node must be registered on-chain. The node itself will be under a userid, and will have a namespace (e.g. `node.alice.node01`).
- Each node may be part of one or many trust namespaces. These can be acquired, by either getting a signature from the trust author, or the DTN network after staking.
- Each node may serve one or many models. But the models must be registered on-chain alongside with the model API.

## AI Engine API

```
request (
  requestId,
  modelNamespace,
  modelAPINamespace,
  maxRequestSize,
  maxResponseSize,
  requestJSON
) returns (
  requestId,
  responseJSON,
  errorJSON
)

```


