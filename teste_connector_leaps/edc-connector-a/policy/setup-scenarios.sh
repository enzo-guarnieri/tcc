#!/bin/bash

PROVIDER="http://localhost:19193"
API_KEY="password"

echo ""
echo "======================================"
echo " Subindo cenários no provider..."
echo "======================================"

run() {
  local label=$1
  local file=$2
  local url=$3

  echo ""
  echo ">>> $label"
  curl -s -H "X-Api-Key: $API_KEY" \
    -H "Content-Type: application/json" \
    -d @"$file" \
    -X POST "$url" | jq '.["@id"] // .message'
}

# ---------- CENÁRIO 1 ----------
echo ""
echo "--- Cenário 1: Fluxo feliz (BR pode acessar e negociar) ---"
run "Asset cenario1"             resources/cenario1/create-asset.json             $PROVIDER/management/v3/assets
run "Policy cenario1"            resources/cenario1/create-policy.json            $PROVIDER/management/v3/policydefinitions
run "Contract Definition cen1"   resources/cenario1/create-contract-definition.json $PROVIDER/management/v3/contractdefinitions

# ---------- CENÁRIO 2 ----------
echo ""
echo "--- Cenário 2: BR vê no catálogo mas falha ao negociar (contrato exige ARG) ---"
run "Asset cenario2"             resources/cenario2/create-asset.json             $PROVIDER/management/v3/assets
run "Open Policy cenario2"       resources/cenario2/create-open-policy.json       $PROVIDER/management/v3/policydefinitions
run "Arg Policy cenario2"        resources/cenario2/create-policy.json            $PROVIDER/management/v3/policydefinitions
run "Contract Definition cen2"   resources/cenario2/create-contract-definition.json $PROVIDER/management/v3/contractdefinitions

# ---------- CENÁRIO 3 ----------
echo ""
echo "--- Cenário 3: Asset invisível no catálogo (acesso exige ARG) ---"
run "Asset cenario3"             resources/cenario3/create-asset.json             $PROVIDER/management/v3/assets
run "Policy cenario3"            resources/cenario3/create-policy.json            $PROVIDER/management/v3/policydefinitions
run "Contract Definition cen3"   resources/cenario3/create-contract-definition.json $PROVIDER/management/v3/contractdefinitions

echo ""
echo "======================================"
echo " Tudo criado! Testando catálogo..."
echo "======================================"
echo ""
curl -s -H "X-Api-Key: $API_KEY" \
  -H "Content-Type: application/json" \
  -d @resources/catalog-request.json \
  -X POST http://localhost:29193/management/v3/catalog/request | jq '[.["dcat:dataset"][] | {"id": .["@id"]}] // [{"id": .["dcat:dataset"]["@id"]}]'

