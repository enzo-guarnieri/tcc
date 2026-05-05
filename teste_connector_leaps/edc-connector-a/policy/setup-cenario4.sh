#!/bin/bash

PROVIDER="http://localhost:19193"
CONSUMER="http://localhost:29193"
API_KEY="password"

echo ""
echo "======================================"
echo " CENÁRIO 4: Aprovação Manual"
echo "======================================"

echo ""
echo "--- 1. Criando asset, policy e contract definition ---"

curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-asset.json \
  -X POST $PROVIDER/management/v3/assets | jq -r '.["@id"] // .[0].message'

curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-policy.json \
  -X POST $PROVIDER/management/v3/policydefinitions | jq -r '.["@id"] // .[0].message'

curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-contract-definition.json \
  -X POST $PROVIDER/management/v3/contractdefinitions | jq -r '.["@id"] // .[0].message'

echo ""
echo "--- 2. Buscando offer no catálogo ---"
OFFER_ID=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/catalog-request.json \
  -X POST $CONSUMER/management/v3/catalog/request \
  | jq -r '[.["dcat:dataset"]] | flatten | .[] | select(.["@id"] == "test-document4") | .["odrl:hasPolicy"]["@id"]')
echo "Offer ID: $OFFER_ID"

echo ""
echo "--- 3. Iniciando negociação ---"
NEGOTIATION_ID=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -X POST $CONSUMER/management/v3/contractnegotiations \
  -d "{
    \"@context\": { \"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\" },
    \"@type\": \"ContractRequest\",
    \"counterPartyId\": \"provider1\",
    \"counterPartyAddress\": \"http://provider1:19194/protocol\",
    \"protocol\": \"dataspace-protocol-http\",
    \"policy\": {
      \"@context\": \"http://www.w3.org/ns/odrl.jsonld\",
      \"@id\": \"$OFFER_ID\",
      \"@type\": \"Offer\",
      \"odrl:permission\": [{\"odrl:action\": {\"@id\": \"odrl:use\"}}],
      \"odrl:prohibition\": [],
      \"odrl:obligation\": [],
      \"assigner\": \"provider1\",
      \"target\": \"test-document4\"
    }
  }" | jq -r '.["@id"]')
echo "Consumer Negotiation ID: $NEGOTIATION_ID"

sleep 2

echo ""
echo "--- 4. Estado da negociação ---"
curl -s -H "X-Api-Key: $API_KEY" \
  $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID \
  | jq '{state: .state}'

PROVIDER_ID=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -X POST $PROVIDER/management/v3/contractnegotiations/request \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "filterExpression": [{"operandLeft": "pending", "operator": "=", "operandRight": true}]}' \
  | jq -r '.[0]["@id"]')

echo ""
echo "============================================"
echo "  Negociação aguardando decisão do provider"
echo "============================================"
echo ""
echo "  1) ✅ APROVAR  — conceder acesso"
echo "  2) ❌ REJEITAR — negar acesso"
echo ""
read -p "  Sua decisão [1 ou 2]: " DECISAO

if [ "$DECISAO" = "1" ]; then
  echo ""
  echo "--- Aprovando negociação ---"
  curl -s -H "X-Api-Key: $API_KEY" \
    -X POST $PROVIDER/management/v3/contractnegotiations/$PROVIDER_ID/approve
  sleep 3
  echo ""
  echo "--- Estado final ---"
  curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID \
    | jq '{state: .state, contractAgreementId: .contractAgreementId}'
  echo ""
  echo "✅ Contrato FINALIZADO — acesso autorizado!"

elif [ "$DECISAO" = "2" ]; then
  echo ""
  echo "--- Rejeitando negociação ---"
  curl -s -H "X-Api-Key: $API_KEY" \
    -X POST $PROVIDER/management/v3/contractnegotiations/$PROVIDER_ID/reject
  sleep 3
  echo ""
  echo "--- Estado final ---"
  curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID \
    | jq '{state: .state, contractAgreementId: .contractAgreementId}'
  echo ""
  echo "❌ Negociação TERMINADA — acesso negado!"

else
  echo "Opção inválida. Digite 1 ou 2."
fi
