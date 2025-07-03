# Model API definition

A model is served through an AI node. A model API can be defined as a flat list of arguments.

E.g.

```

My custom model
INPUT:
 - prompt: string
 - type: uint8
 - width: uint64
 - height: uint64
OUTPUT:
 - bytes

```



