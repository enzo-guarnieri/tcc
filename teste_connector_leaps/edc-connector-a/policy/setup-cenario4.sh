#!/bin/bash

# Definição de cores para formatação do terminal
NC='\033[0m'
BRANCO='\033[1;37m'
AZUL='\033[1;34m'
VERDE='\033[0;32m'
AMARELO='\033[1;33m'
VERMELHO='\033[0;31m'
ROXO='\033[0;35m'
CINZA='\033[0;90m'

# Configurações de ambiente do ecossistema EDC
PROVIDER="http://localhost:19193"
CONSUMER="http://localhost:29193"
FEDERATED_CATALOG="http://localhost:49193"
API_KEY="password"
ASSET_ID="prontuario-joao-silva"

clear
echo -e "${AMARELO}==========================================================================${NC}"
echo -e "${BRANCO}         ECLIPSE DATASPACE COMPONENTS (EDC) - FRAMEWORK DE TESTES           ${NC}"
echo -e "${AMARELO}==========================================================================${NC}"
echo -e "${BRANCO} Ambiente: Provedor e Consumidor Locais | Cenário 2: Aprovação externa     ${NC}"
echo -e "${AMARELO}==========================================================================${NC}"
sleep 1

# ----------------------------------------------------------------------
# PASSO 1: Publicação dos Recursos no Provedor
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 1] Provedor publica um dado em seu conector (Asset, Policy e Contract)${NC}"
echo ""

echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/assets"
ASSET_RES=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-asset.json \
  -X POST $PROVIDER/management/v3/assets \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"] // .[0].message) else (.id // .["@id"] // .message) end')
echo -e "        Response ID: ${AMARELO}$ASSET_RES${NC}"

echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/policydefinitions"
POLICY_RES=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-policy.json \
  -X POST $PROVIDER/management/v3/policydefinitions \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"] // .[0].message) else (.id // .["@id"] // .message) end')
echo -e "        Response ID: ${AMARELO}$POLICY_RES${NC}"

echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/contractdefinitions"
CONTRACT_RES=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/cenario4/create-contract-definition.json \
  -X POST $PROVIDER/management/v3/contractdefinitions \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"] // .[0].message) else (.id // .["@id"] // .message) end')
echo -e "        Response ID: ${AMARELO}$CONTRACT_RES${NC}"

sleep 2

# ----------------------------------------------------------------------
# PASSO 2: Consulta ao Catálogo Federado
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 2] Consumidor consulta o Catálogo Federado${NC}"
echo ""
echo -e " [HTTP] ${VERDE}POST${NC} ${FEDERATED_CATALOG}/api/catalog/v1alpha/catalog/query"

CATALOG_RES=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/catalog-request.json \
  -X POST $CONSUMER/management/v3/catalog/request)

# Filtro corrigido e simplificado em uma única linha para evitar problemas de quebra de shell
OFFER_ID=$(echo "$CATALOG_RES" | jq -r --arg ASSET "$ASSET_ID" '[.["dcat:dataset"]] | flatten | .[] | select(.["@id"] == $ASSET or .id == $ASSET) | .["odrl:hasPolicy"]["@id"]' | head -1)

if [ -z "$OFFER_ID" ] || [ "$OFFER_ID" = "null" ]; then
    echo -e " [ERRO] Recurso '$ASSET_ID' não localizado no catálogo federado."
    echo -e "${CINZA}[DEBUG] Resposta bruta:${NC}"
    echo "$CATALOG_RES" | jq .
    exit 1
fi

echo -e "        Status: ${VERDE}SUCCESS${NC} | Recurso localizado no catálogo federado."
echo -e "        Offer ID: ${AMARELO}$OFFER_ID${NC}"


# ----------------------------------------------------------------------
# PASSO 3: Inicialização do Protocolo de Negociação
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 3] Consumidor inicia a Negociação do Contrato${NC}"
echo ""
echo -e " [HTTP] ${VERDE}POST${NC} ${CONSUMER}/management/v3/contractnegotiations"

# Injeção direta e segura das variáveis no escopo do JSON por aspas escapadas
NEGOTIATION_RAW=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
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
      \"target\": \"$ASSET_ID\"
    }
  }")

NEGOTIATION_ID=$(echo "$NEGOTIATION_RAW" \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"]) else (.id // .["@id"]) end')

if [ -z "$NEGOTIATION_ID" ] || [ "$NEGOTIATION_ID" = "null" ]; then
    echo -e " [ERRO] Falha na inicialização da negociação."
    echo -e "${CINZA}[DEBUG] Resposta bruta:${NC} $NEGOTIATION_RAW"
    exit 1
fi
echo -e "        Status: ${VERDE}INITIALIZED${NC} | Processo registrado no conector local."
echo -e "        Consumer Negotiation ID: ${AMARELO}$NEGOTIATION_ID${NC}"

sleep 2

# ----------------------------------------------------------------------
# PASSO 4: Avaliação do Estado da Negociação
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 4] Verificando o Estado da Negociação${NC}"
echo ""
echo -e " [HTTP] ${VERDE}GET${NC} ${CONSUMER}/management/v3/contractnegotiations/$NEGOTIATION_ID"
STATE_RES=$(curl -s -H "X-Api-Key: $API_KEY" \
  $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID | jq -r '.state')
echo -e "        Estado atual no Consumidor: ${ROXO}$STATE_RES${NC}"

PROVIDER_ID=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -X POST $PROVIDER/management/v3/contractnegotiations/request \
  -d '{"@context": {"@vocab": "https://w3id.org/edc/v0.0.1/ns/"}, "filterExpression": [{"operandLeft": "state", "operator": "=", "operandRight": "REQUESTED"}]}' \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"]) else (.id // .["@id"]) end')

sleep 1

# ----------------------------------------------------------------------
# INTERFACE DE TOMADA DE DECISÃO (INTERATIVO)
# ----------------------------------------------------------------------
echo ""
echo -e "${AMARELO}======================================================================${NC}"
echo -e "${BRANCO}          SISTEMA RECORRENTE: AGUARDANDO DECISÃO DE GOVERNANÇA         ${NC}"
echo -e "${AMARELO}======================================================================${NC}"
echo -e " Negociação travada pelo conector do Provedor com base na policy mapeada."
echo -e " Requer intervenção manual ou gatilho de API externa ao conector para transição."
echo -e " Provider Contract Negotiation ID: ${ROXO}$PROVIDER_ID${NC}"
echo ""
echo -e "  1) [APROVAR CONTRATO] - Aprovar o acordo e liberar o acesso"
echo -e "  2) [REJEITAR CONTRATO] - Negar o acordo e impedir o acesso"
echo ""
read -p " Informe a ação [1 ou 2]: " DECISAO

if [ "$DECISAO" = "1" ]; then
  echo -e "\n[INFO] Enviando aprovação ao Provedor..."
  echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/contractnegotiations/$PROVIDER_ID/approve"
  curl -s -H "X-Api-Key: $API_KEY" -X POST \
    $PROVIDER/management/v3/contractnegotiations/$PROVIDER_ID/approve

  echo -e "\n[WAIT] Aguardando propagação do estado..."
  sleep 3

  echo -e "\n${AZUL}[VERIFICAÇÃO] Consultando estado consolidado da transação...${NC}"
  FINAL_STATUS=$(curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID)
  STATE_FINAL=$(echo "$FINAL_STATUS" | jq -r '.state')
  AGREEMENT_ID=$(echo "$FINAL_STATUS" | jq -r '.contractAgreementId')

  echo -e "        Estado Final: ${VERDE}$STATE_FINAL${NC}"
  echo -e "        Contract Agreement ID: ${AMARELO}$AGREEMENT_ID${NC}"

  # ----------------------------------------------------------------------
  # PASSO 5: Transferência do Dado
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 5] Iniciando transferência do dado${NC}"
  echo ""
  echo -e " [HTTP] ${VERDE}POST${NC} ${CONSUMER}/management/v3/transferprocesses"

  TRANSFER_RAW=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
    -X POST $CONSUMER/management/v3/transferprocesses \
    -d "{
      \"@context\": { \"@vocab\": \"https://w3id.org/edc/v0.0.1/ns/\" },
      \"@type\": \"TransferRequestDto\",
      \"connectorId\": \"provider1\",
      \"counterPartyAddress\": \"http://provider1:19194/protocol\",
      \"contractId\": \"$AGREEMENT_ID\",
      \"protocol\": \"dataspace-protocol-http\",
      \"transferType\": \"HttpData-PULL\"
    }")

  TRANSFER_ID=$(echo "$TRANSFER_RAW" \
    | jq -r 'if type=="array" then (.[0].id // .[0]["@id"]) else (.id // .["@id"]) end')

  if [ -z "$TRANSFER_ID" ] || [ "$TRANSFER_ID" = "null" ]; then
    echo -e " [ERRO] Falha ao iniciar transferência."
    echo -e "${CINZA}[DEBUG] Resposta bruta:${NC} $TRANSFER_RAW"
    exit 1
  fi

  echo -e "        Transfer Process ID: ${AMARELO}$TRANSFER_ID${NC}"
  echo -e "\n[WAIT] Aguardando provisionamento do endpoint de dados..."
  sleep 5

  # ----------------------------------------------------------------------
  # PASSO 6: Busca do Endpoint e Token de Acesso
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 6] Obtendo endpoint e token de acesso ao dado${NC}"
  echo ""
  echo -e " [HTTP] ${VERDE}GET${NC} ${CONSUMER}/management/v3/edrs/$TRANSFER_ID/dataaddress"

  EDR=$(curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/edrs/$TRANSFER_ID/dataaddress)

  # Resgate dinâmico do endereço público real mapeado dentro do create-asset.json
  DATA_TARGET_URL=$(jq -r '.dataAddress.baseUrl // "https://data.guarnieri.studio/nginx/paciente"' resources/cenario4/create-asset.json)
  DATA_TOKEN=$(echo "$EDR"   | jq -r '.authorization // .["https://w3id.org/edc/v0.0.1/ns/authorization"] // empty')

  if [ -z "$DATA_TOKEN" ] || [ "$DATA_TOKEN" = "null" ]; then
    echo -e " [ERRO] Token de acesso não disponível."
    echo -e "${CINZA}[DEBUG] EDR response:${NC}"
    echo "$EDR" | jq .
    exit 1
  fi

  echo -e "        Target Endpoint: ${AMARELO}$DATA_TARGET_URL${NC}"
  echo -e "        Token Gerado:    ${CINZA}${DATA_TOKEN:0:40}...${NC}"

  # ----------------------------------------------------------------------
  # PASSO 7: Acesso ao Dado Real
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 7] Acessando o dado via endpoint seguro gerenciado${NC}"
  echo ""

  # CORREÇÃO: Apontando para o caminho correto do arquivo que você deu 'cat'
  TOKEN_ASSET=$(jq -r '.dataAddress.authCode // "Não configurado"' resources/create-asset.json)

  echo -e " [HTTP] ${VERDE}GET${NC} $DATA_TARGET_URL"
  echo -e "        Authorization: ${AMARELO}$TOKEN_ASSET${NC}"
  echo ""

  # Faz a requisição portando o token correto para o Nginx público
  DADO=$(curl -s -H "Authorization: $DATA_TOKEN" "$DATA_TARGET_URL")

  # Validação estrutural preventiva do JSON FHIR
  if [[ ! "$DADO" =~ ^\{ ]]; then
    echo -e " [ERRO] Não foi possível estruturar os dados clínicos recebidos."
    echo -e "${CINZA}[DEBUG] Resposta capturada:${NC} $DADO"
    exit 1
  fi

  RESOURCE_TYPE=$(echo "$DADO" | jq -r '.resourceType // "desconhecido"')
  PATIENT_NAME=$(echo "$DADO"  | jq -r '.entry[] | select(.resource.resourceType=="Patient") | .resource.name[0].given[0] + " " + .resource.name[0].family' 2>/dev/null | head -1)
  NUM_ENTRIES=$(echo "$DADO"   | jq '.entry | length' 2>/dev/null)

  echo -e "        Resource Type:  ${VERDE}$RESOURCE_TYPE${NC}"
  echo -e "        Paciente:       ${VERDE}$PATIENT_NAME${NC}"
  echo -e "        Entradas FHIR:  ${VERDE}$NUM_ENTRIES registros${NC}"
  echo ""

elif [ "$DECISAO" = "2" ]; then
  echo -e "\n[INFO] Enviando rejeição ao Provedor..."
  echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/contractnegotiations/$PROVIDER_ID/reject"
  curl -s -H "X-Api-Key: $API_KEY" -X POST \
    $PROVIDER/management/v3/contractnegotiations/$PROVIDER_ID/reject

  sleep 6

  echo -e "\n${AZUL}[VERIFICAÇÃO] Consultando estado consolidado...${NC}"
  STATE_FINAL=$(curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID | jq -r '.state')

  echo -e "        Estado Final: ${VERMELHO}$STATE_FINAL${NC}"
  echo ""
  echo -e "${VERMELHO}[CANCELADO] Negociação rejeitada. Acesso ao dado negado.${NC}"

else
  echo -e "${VERMELHO}[ERRO] Opção inválida. Execução cancelada.${NC}"
fi

echo -e "${AMARELO}======================================================================${NC}\n"
