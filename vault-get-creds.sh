SCRIPT_LOC=$(cd "$(dirname "$0")"; pwd -P)
. $SCRIPT_LOC/common_functions.sh

need "jq"
need "curl"
need "vault" #just for giggles


need_var "$SRC_IMG" "SRC_IMG"
need_var "$APPROLE_ID" "APPROLE_ID"
need_var "$VAULT_ADDR" "VAULT_ADDR"
need_var "$APPROLE_SECRET_ID" "APPROLE_SECRET_ID"
need_var "$VAULT_SOURCE_ACCOUNT_PATH" "VAULT_SOURCE_ACCOUNT_PATH"
need_var "$VAULT_SOURCE_ACCOUNT_FIELD" "VAULT_SOURCE_ACCOUNT_FIELD"
need_var "$VAULT_GOLDEN_REGISTRY_PATH" "VAULT_GOLDEN_REGISTRY_PATH"
need_var "$DEST_ACCOUNT_JSON_CREDS_PATH" "DEST_ACCOUNT_JSON_CREDS_PATH"
need_var "$SOURCE_ACCOUNT_JSON_CREDS_PATH" "SOURCE_ACCOUNT_JSON_CREDS_PATH"

VAULT_SOURCE_ACCOUNT=$(echo "$SRC_IMG" | cut -d"/" -f2)

VAULT_TOKEN=$(curl -s --request POST --data '{"role_id":"'"$APPROLE_ID"'","secret_id":"'"$APPROLE_SECRET_ID"'"}' "$VAULT_ADDR"/v1/auth/approle/login | jq -r '.auth.client_token')

if [ -z "$VAULT_TOKEN" ]; then
    die "Unable to get vault token with the provided approle ID and approle secret ID"
fi

vault login "$VAULT_TOKEN"

# download source acct creds
vault read -field "$VAULT_SOURCE_ACCOUNT_FIELD" secret/"$VAULT_SOURCE_ACCOUNT_PATH/$VAULT_SOURCE_ACCOUNT" > "$SOURCE_ACCOUNT_JSON_CREDS_PATH"

# download golden registry creds
vault read -field=data -format=json secret/"$VAULT_GOLDEN_REGISTRY_PATH/$VAULT_GOLDEN_REGISTRY_ACCOUNT" > "$DEST_ACCOUNT_JSON_CREDS_PATH"
