./gradlew :connector:clean
./gradlew :connector:shadowJar

java -jar connector/build/libs/basic-connector.jar

java -Dedc.fs.config=config.properties -jar connector/build/libs/basic-connector.jar

------ transfer -------

java -Dedc.fs.config=configuracoes/consumer-configuration.properties -jar connector/build/libs/basic-connector.jar

java -Dedc.fs.config=configuracoes/provider-configuration.properties -jar connector/build/libs/basic-connector.jar

------ observability -------

### 1. Subir os containers

Execute a partir da pasta `observability`:

```bash
docker compose up -d --build
```

Aguarde os containers iniciarem.

---

## 2. Criar o Asset no provider

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/create-asset.json \
  http://localhost:19193/management/v3/assets \
  -s | jq
```

---

## 3. Criar a Policy no provider

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/create-policy.json \
  http://localhost:19193/management/v3/policydefinitions \
  -s | jq
```

---

## 4. Criar a Contract Definition no provider

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/create-contract-definition.json \
  http://localhost:19193/management/v3/contractdefinitions \
  -s | jq
```

---

## 5. Solicitar o catálogo no consumer

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/get-dataset.json \
  -X POST http://localhost:29193/management/v3/catalog/dataset/request \
  -s | jq
```

O resultado será algo como isso:

```json
{
  "@id": "assetId",
  "@type": "dcat:Dataset",
  "odrl:hasPolicy": {
    "@id": "MQ==:YXNzZXRJZA==:NjdlNDFhM2EtYThjMS00YTBmLWFkNmYtMjk5NzkzNTE2OTE3",
    "@type": "odrl:Offer",
    "odrl:permission": [],
    "odrl:prohibition": [],
    "odrl:obligation": []
  },
  "dcat:distribution": [
    {
      "@type": "dcat:Distribution",
      "dct:format": {
        "@id": "HttpData-PULL"
      },
      "dcat:accessService": {
        "@id": "cb701b36-48ee-4132-8436-dba7b83c606c",
        "@type": "dcat:DataService",
        "dcat:endpointDescription": "dspace:connector",
        "dcat:endpointUrl": "http://provider:19194/protocol",
        "dct:terms": "dspace:connector",
        "dct:endpointUrl": "http://provider:19194/protocol"
      }
    },
    {
      "@type": "dcat:Distribution",
      "dct:format": {
        "@id": "HttpData-PUSH"
      },
      "dcat:accessService": {
        "@id": "cb701b36-48ee-4132-8436-dba7b83c606c",
        "@type": "dcat:DataService",
        "dcat:endpointDescription": "dspace:connector",
        "dcat:endpointUrl": "http://provider:19194/protocol",
        "dct:terms": "dspace:connector",
        "dct:endpointUrl": "http://provider:19194/protocol"
      }
    }
  ],
  "name": "product description",
  "id": "assetId",
  "contenttype": "application/json",
  "@context": {
    "@vocab": "https://w3id.org/edc/v0.0.1/ns/",
    "edc": "https://w3id.org/edc/v0.0.1/ns/",
    "dcat": "http://www.w3.org/ns/dcat#",
    "dct": "http://purl.org/dc/terms/",
    "odrl": "http://www.w3.org/ns/odrl/2/",
    "dspace": "https://w3id.org/dspace/v0.8/"
  }
}
```

Com o odrl:hasPolicy/@id, agora podemos substituí-lo no arquivo negotiate-contract.json (resources/negotiate-contract.json) e solicitar a negociação do contrato.

---

## 6. Negociar contrato

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/negotiate-contract.json \
  -X POST http://localhost:29193/management/v3/contractnegotiations \
  -s | jq
```

Guarde o valor retornado em `id`. Esse será o `contract-negotiation-id`.

---

## 7. Verificar o estado da negociação

Substitua `CONTRACT_NEGOTIATION_ID` pelo valor retornado anteriormente.

```bash
curl -H "X-Api-Key: password" \
  -X GET http://localhost:29193/management/v3/contractnegotiations/CONTRACT_NEGOTIATION_ID \
  -s | jq
```

```bash
curl -H "X-Api-Key: password" \
  -X GET http://localhost:29193/management/v3/contractnegotiations/1f7b5028-3ab1-454e-a39b-c7f8940fa7ec \
  -s | jq
```

Quando a negociação estiver concluída, o contrato estará ativo.

---

## 8. Iniciar a transferência

Edite o arquivo:

```
resources/start-transfer.json
```

Atualize o campo `contractAgreementId` com o id do contrato retornado na negociação.

Depois execute:

```bash
curl -H "X-Api-Key: password" \
  -H "Content-Type: application/json" \
  -d @resources/start-transfer.json \
  -X POST http://localhost:29193/management/v3/transferprocesses \
  -s | jq
```

---

## 9. Verificar traces

Abra a interface do Jaeger:

```
http://localhost:16686
```

Os serviços `consumer` e `provider` devem aparecer na lista de serviços disponíveis para visualização dos traces.
