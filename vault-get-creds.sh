#!/bin/bash

die() { echo "$*" 1>&2 ; exit 1; }

if [ -z "$APPROLE_ID" ]; then
    die "vault approle ID APPROLE_ID needed to continue"
fi

if [ -z "$APPROLE_SECRET_ID" ]; then
    die "vault approle secret ID APPROLE_SECRET_ID needed to continue"
fi

if [ -z "$VAULT_ADDR" ]; then
    die "vault address VAULT_ADDR needed to continue"
fi

if [ -z "$VAULT_SOURCE_ACCOUNT_PATH" ]; then
    die "vault source account path VAULT_SOURCE_ACCOUNT_PATH needed to continue"
fi

if [ -z "$VAULT_SOURCE_ACCOUNT" ]; then
    die "vault source account VAULT_SOURCE_ACCOUNT needed to continue"
fi

if [ -z "$VAULT_SOURCE_ACCOUNT_FIELD" ]; then
    die "vault source account field VAULT_SOURCE_ACCOUNT_FIELD needed to continue"
fi

if [ -z "$VAULT_GOLDEN_REGISTRY_PATH" ]; then
    die "vault golden registry path VAULT_GOLDEN_REGISTRY_PATH needed to continue"
fi

if [ -z "$SOURCE_ACCOUNT_JSON_CREDS_PATH" ]; then
    die "source account json creds path SOURCE_ACCOUNT_JSON_CREDS_PATH needed to continue"
fi

if [ -z "$DEST_ACCOUNT_JSON_CREDS_PATH" ]; then
    die "dest account json creds path DEST_ACCOUNT_JSON_CREDS_PATH needed to continue"
fi

VAULT_TOKEN=$(curl -s --request POST --data '{"role_id":"'"$APPROLE_ID"'","secret_id":"'"$APPROLE_SECRET_ID"'"}' "$VAULT_ADDR"/v1/auth/approle/login | jq -r '.auth.client_token')

if [ -z "$VAULT_TOKEN" ]; then
    die "Unable to get vault token with the provided approle ID and approle secret ID"
fi

vault login "$VAULT_TOKEN"

# download source acct creds
vault read -field "$VAULT_SOURCE_ACCOUNT_FIELD" secret/"$VAULT_SOURCE_ACCOUNT_PATH/$VAULT_SOURCE_ACCOUNT" > "$SOURCE_ACCOUNT_JSON_CREDS_PATH"

# download golden registry creds
vault read -field=data -format=json secret/"$VAULT_GOLDEN_REGISTRY_PATH/$VAULT_GOLDEN_REGISTRY_ACCOUNT" > "$DEST_ACCOUNT_JSON_CREDS_PATH"
