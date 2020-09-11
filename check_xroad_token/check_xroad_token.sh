#!/bin/bash
xroad_list_tokens=$(signer-console list-tokens)

if [[ $xroad_list_tokens == "Token: 0 (OK, writable, available, active)" ]]
then
        echo "OK - $xroad_list_tokens"
        exit 0
elif [[ $xroad_list_tokens != "Token: 0 (OK, writable, available, active)" ]]
then
        echo "Critical - $xroad_list_tokens"
        exit 2
else
        echo "Unknown - $xroad_list_tokens"
        exit 3
fi