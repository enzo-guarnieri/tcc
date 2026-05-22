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
echo -e "${BRANCO} Ambiente: Provedor e Consumidor Locais | Cenário 4: Aprovação Externa    ${NC}"
echo -e "${AMARELO}==========================================================================${NC}"
sleep 1

# ----------------------------------------------------------------------
# PASSO 1: Publicação dos Recursos no Provedor
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 1] Provedor publica um dado em seu conector (Asset, Policy e Contract)${NC}"
echo "--------------------------------------------------------------------------"

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
echo "--------------------------------------------------------------------------"
echo -e " [HTTP] ${VERDE}POST${NC} ${CONSUMER}/management/v3/catalog/request"

CATALOG_RES=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -d @resources/catalog-request.json \
  -X POST $CONSUMER/management/v3/catalog/request)

echo -e "\n${CINZA}[CONTEÚDO COMPLETO DO CATÁLOGO FEDERADO REQUISITADO]:${NC}"
echo "$CATALOG_RES" | jq .
echo "--------------------------------------------------------------------------"

# Filtro do Offer ID
OFFER_ID=$(echo "$CATALOG_RES" | jq -r --arg ASSET "$ASSET_ID" '[.["dcat:dataset"]] | flatten | .[] | select(.["@id"] == $ASSET or .id == $ASSET) | .["odrl:hasPolicy"]["@id"]' | head -1)

if [ -z "$OFFER_ID" ] || [ "$OFFER_ID" = "null" ]; then
    echo -e " [ERRO] Recurso '$ASSET_ID' não localizado no catálogo federado."
    exit 1
fi

echo -e "        Status: ${VERDE}SUCCESS${NC} | Recurso localizado no catálogo federado."
echo -e "        Offer ID Extraído: ${AMARELO}$OFFER_ID${NC}"
sleep 2

# ----------------------------------------------------------------------
# PASSO 3: Inicialização do Protocolo de Negociação
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 3] Consumidor inicia a Negociação do Contrato (Contract Request)${NC}"
echo "--------------------------------------------------------------------------"

PAYLOAD_NEGOTIATION=$(cat <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@type": "ContractRequest",
  "counterPartyId": "provider1",
  "counterPartyAddress": "http://provider1:19194/protocol",
  "protocol": "dataspace-protocol-http",
  "policy": {
    "@context": "http://www.w3.org/ns/odrl.jsonld",
    "@id": "$OFFER_ID",
    "@type": "Offer",
    "odrl:permission": [{"odrl:action": {"@id": "odrl:use"}}],
    "odrl:prohibition": [],
    "odrl:obligation": [],
    "assigner": "provider1",
    "target": "$ASSET_ID"
  }
}
EOF
)

echo -e "${CINZA}[PAYLOAD DE CONTRATO ENVIADO PELO CONSUMER]:${NC}"
echo "$PAYLOAD_NEGOTIATION" | jq .
echo "--------------------------------------------------------------------------"

echo -e " [HTTP] ${VERDE}POST${NC} ${CONSUMER}/management/v3/contractnegotiations"
NEGOTIATION_RAW=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
  -X POST $CONSUMER/management/v3/contractnegotiations \
  -d "$PAYLOAD_NEGOTIATION")

echo -e "\n${CINZA}[RESPOSTA DA INICIALIZAÇÃO DA NEGOCIAÇÃO]:${NC}"
echo "$NEGOTIATION_RAW" | jq .
echo "--------------------------------------------------------------------------"

NEGOTIATION_ID=$(echo "$NEGOTIATION_RAW" \
  | jq -r 'if type=="array" then (.[0].id // .[0]["@id"]) else (.id // .["@id"]) end')

if [ -z "$NEGOTIATION_ID" ] || [ "$NEGOTIATION_ID" = "null" ]; then
    echo -e " [ERRO] Falha na inicialização da negociação."
    exit 1
fi
echo -e "        Status: ${VERDE}INITIALIZED${NC} | Processo registrado no conector local."
echo -e "        Consumer Negotiation ID: ${AMARELO}$NEGOTIATION_ID${NC}"

sleep 2

# ----------------------------------------------------------------------
# PASSO 4: Avaliação do Estado da Negociação
# ----------------------------------------------------------------------
echo -e "\n${AZUL}[PASSO 4] Verificando o Estado da Negociação nos conectores${NC}"
echo "--------------------------------------------------------------------------"
echo -e " [HTTP] ${VERDE}GET${NC} ${CONSUMER}/management/v3/contractnegotiations/$NEGOTIATION_ID"

NEGOTIATION_STATUS_FULL=$(curl -s -H "X-Api-Key: $API_KEY" $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID)
echo -e "\n${CINZA}[DETALHES DO ESTADO DE NEGOCIAÇÃO NO CONSUMIDOR]:${NC}"
echo "$NEGOTIATION_STATUS_FULL" | jq .

STATE_RES=$(echo "$NEGOTIATION_STATUS_FULL" | jq -r '.state')
echo -e "\n        Estado atual no Consumidor: ${ROXO}$STATE_RES${NC}"

# Buscando ID da negociação no Provedor
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

  echo -e "\n[WAIT] Aguardando propagação do estado e consolidação do Contract Agreement..."
  sleep 4

  echo -e "\n${AZUL}[VERIFICAÇÃO] Consultando estado consolidado da transação...${NC}"
  FINAL_STATUS=$(curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID)
  
  echo -e "${CINZA}[RESPOSTA FINAL DA NEGOCIAÇÃO PÓS-APROVAÇÃO]:${NC}"
  echo "$FINAL_STATUS" | jq .
  echo "--------------------------------------------------------------------------"

  STATE_FINAL=$(echo "$FINAL_STATUS" | jq -r '.state')
  AGREEMENT_ID=$(echo "$FINAL_STATUS" | jq -r '.contractAgreementId')

  echo -e "        Estado Final: ${VERDE}$STATE_FINAL${NC}"
  echo -e "        Contract Agreement ID (O Acordo Assinado): ${AMARELO}$AGREEMENT_ID${NC}"

  # ----------------------------------------------------------------------
  # PASSO 5: Transferência do Dado
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 5] Iniciando protocolo de transferência de dados (Transfer Request)${NC}"
  echo "--------------------------------------------------------------------------"
  
  PAYLOAD_TRANSFER=$(cat <<EOF
{
  "@context": { "@vocab": "https://w3id.org/edc/v0.0.1/ns/" },
  "@type": "TransferRequestDto",
  "connectorId": "provider1",
  "counterPartyAddress": "http://provider1:19194/protocol",
  "contractId": "$AGREEMENT_ID",
  "protocol": "dataspace-protocol-http",
  "transferType": "HttpData-PULL"
}
EOF
)
  echo -e "${CINZA}[PAYLOAD DE TRANSFERÊNCIA SOLICITADA]:${NC}"
  echo "$PAYLOAD_TRANSFER" | jq .
  echo "--------------------------------------------------------------------------"

  echo -e " [HTTP] ${VERDE}POST${NC} ${CONSUMER}/management/v3/transferprocesses"
  TRANSFER_RAW=$(curl -s -H "X-Api-Key: $API_KEY" -H "Content-Type: application/json" \
    -X POST $CONSUMER/management/v3/transferprocesses \
    -d "$PAYLOAD_TRANSFER")

  echo -e "\n${CINZA}[RESPOSTA DO PROCESSO DE TRANSFERÊNCIA EMITIDO]:${NC}"
  echo "$TRANSFER_RAW" | jq .
  echo "--------------------------------------------------------------------------"

  TRANSFER_ID=$(echo "$TRANSFER_RAW" \
    | jq -r 'if type=="array" then (.[0].id // .[0]["@id"]) else (.id // .["@id"]) end')

  if [ -z "$TRANSFER_ID" ] || [ "$TRANSFER_ID" = "null" ]; then
    echo -e " [ERRO] Falha ao iniciar transferência."
    exit 1
  fi

  echo -e "        Transfer Process ID: ${AMARELO}$TRANSFER_ID${NC}"
  echo -e "\n[WAIT] Aguardando o Provedor provisionar o Token de Acesso (EDR)..."
  sleep 5


  # ----------------------------------------------------------------------
  # PASSO 6: Busca do Endpoint e Token de Acesso (EDR)
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 6] Obtendo EDR (Endpoint Data Reference) e Token de Acesso${NC}"
  echo "--------------------------------------------------------------------------"
  echo -e " [HTTP] ${VERDE}GET${NC} ${CONSUMER}/management/v3/edrs/$TRANSFER_ID/dataaddress"

  EDR=$(curl -s -H "X-Api-Key: $API_KEY" \
    "$CONSUMER/management/v3/edrs/$TRANSFER_ID/dataaddress")

  echo -e "\n${CINZA}[CONTEÚDO DO EDR RECEBIDO (DATA ADDRESS + TOKEN ASSET)]:${NC}"
  echo "$EDR" | jq .
  echo "--------------------------------------------------------------------------"

  # Tratamento robusto para extrair o endpoint (suporta formato normal e expandido JSON-LD)
  RAW_ENDPOINT=$(echo "$EDR" | jq -r '.endpoint // .["https://w3id.org/edc/v0.0.1/ns/endpoint"] // empty')

  # Se o endpoint vier vazio, tenta buscar por mapeamento genérico de propriedades do DataAddress
  if [ -z "$RAW_ENDPOINT" ] || [ "$RAW_ENDPOINT" = "null" ]; then
    RAW_ENDPOINT=$(echo "$EDR" | jq -r '.properties["https://w3id.org/edc/v0.0.1/ns/endpoint"] // empty')
  fi

  # Como estamos rodando o script fora da rede do Docker, mapeia 'provider1' para 'localhost'
  DATA_TARGET_URL=$(echo "$RAW_ENDPOINT" | sed 's/provider1/localhost/g')

  # Captura correta do token gerado pelo EDC (suporta formato normal e expandido JSON-LD)
  DATA_TOKEN=$(echo "$EDR" | jq -r '.authorization // .["https://w3id.org/edc/v0.0.1/ns/authorization"] // empty')

  if [ -z "$DATA_TOKEN" ] || [ "$DATA_TOKEN" = "null" ]; then
    echo -e " [ERRO] Token de acesso não disponível no EDR."
    exit 1
  fi

  echo -e "        Target Endpoint Dinâmico do EDC: ${AMARELO}$DATA_TARGET_URL${NC}"
  echo -e "        Token Descentralizado (EDC JWT) Gerado: ${CINZA}${DATA_TOKEN:0:50}... [TRUNCADO]${NC}"


  # ----------------------------------------------------------------------
  # PASSO 7: Acesso ao Dado Real (Via Fluxo de Governança do Data Plane)
  # ----------------------------------------------------------------------
  echo -e "\n${AZUL}[PASSO 7] Consumidor acessando o dado clínico real via plano de dados seguro${NC}"
  echo "--------------------------------------------------------------------------"

  echo -e " [HTTP] ${VERDE}GET${NC} $DATA_TARGET_URL"
  echo -e "        Enviando requisição segura para o Data Plane do Provedor..."
  echo ""

  # TENTATIVA 1: Enviando com o formato padrão "Bearer <TOKEN>"
  echo -e " ${CINZA}[Tentativa 1] Enviando com cabeçalho 'Bearer <TOKEN>'...${NC}"
  DADO=$(curl -s -H "Authorization: Bearer $DATA_TOKEN" "$DATA_TARGET_URL")

  # Tratamento de Contingência: Se o Jetty do EDC retornar 403 Forbidden com "Bearer ",
  # significa que a versão instalada do Data Plane espera o token limpo/cru no cabeçalho
  if [[ "$DADO" == *"403 Forbidden"* ]]; then
     echo -e "${AMARELO}        [AVISO] Formato Bearer retornou 403. Tentando Token Cru direto no header...${NC}"
     DADO=$(curl -s -H "Authorization: $DATA_TOKEN" "$DATA_TARGET_URL")
  fi

  echo -e "\n${CINZA}[PAYLOAD COMPLETO DO DADO CLÍNICO DEVOLVIDO]:${NC}"

  # Tenta formatar com o JQ se for um JSON legítimo, senão exibe o texto bruto (HTML de erro, por exemplo)
  echo "$DADO" | jq . 2>/dev/null || echo "$DADO"
  echo "--------------------------------------------------------------------------"

  # Validação de sucesso para o script de TCC
  if [[ "$DADO" == *"Error"* ]] || [[ "$DADO" == *"403"* ]]; then
     echo -e "${VERMELHO} [ERRO] A requisição foi rejeitada pelo gateway do plano de dados.${NC}"
     exit 1
  else
     echo -e "${VERDE} [SUCESSO] Dados clínicos obtidos e validados via ecossistema EDC!${NC}"
  fi

elif [ "$DECISAO" = "2" ]; then
  echo -e "\n[INFO] Enviando rejeição ao Provedor..."
  echo -e " [HTTP] ${VERDE}POST${NC} ${PROVIDER}/management/v3/contractnegotiations/$PROVIDER_ID/reject"
  curl -s -H "X-Api-Key: $API_KEY" -X POST \
    $PROVIDER/management/v3/contractnegotiations/$PROVIDER_ID/reject

  echo -e "\n[WAIT] Propagando rejeição..."
  sleep 4

  echo -e "\n${AZUL}[VERIFICAÇÃO] Consultando estado consolidado no Consumidor...${NC}"
  STATE_FINAL=$(curl -s -H "X-Api-Key: $API_KEY" \
    $CONSUMER/management/v3/contractnegotiations/$NEGOTIATION_ID | jq -r '.state')

  echo -e "        Estado Final no Consumidor: ${VERMELHO}$STATE_FINAL${NC}"
  echo ""
  echo -e "${VERMELHO}[CANCELADO] Negociação legalmente rejeitada pela governança. Acesso negado.${NC}"

else
  echo -e "${VERMELHO}[ERRO] Opção inválida. Execução abortada.${NC}"
fi

echo -e "${AMARELO}======================================================================${NC}\n"
