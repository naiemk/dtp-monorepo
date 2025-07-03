# DTN AI Server Node Template

# API

PORT: 8026

We serve a simple API:

**Request**

```
- method: POST
- headers: Content-Type: application/json
- body:
{
    requestId: "...",
    model: "...",
    call: {
        parameters: [ "", ... ],
        types: ["", ...]
    }
}

```

**Response**

```
{
    requestId: "...",
    data: "...",
    datatype: "...",
    error: "..."
}
```

## Model Definition

You can choose to serve many models. Each model is defined by a namespace, it has an API for example:

- name: `model.system.openai-gpt-o3-simpletext`
- model API: `api.system.simple-text-prompt`
  - api: `string -> string`
  - description: `prompt: string - provide the prompt -> returns (string) - the AI chat response`

Another example:

- name: `model.system.openai-gpt-o3-simpleimage`
- model API: `api.system.simple-image-prompt`
  - api: `string, uint64, uint64 -> bytes`
  - description: `prmopt: string - provide the prompt, width: the image width, height: the height`
  `-> returns (bytes) the generated image binary`

# Hosting
This node is meant to run in a docker image within a docker-compose on the same host as teh DTN-Network
image.

