path "pki*"                        { capabilities = ["read", "list"] }
path "pki_k8s/sign/k8s-sorsa-cloud"    { capabilities = ["create", "update"] }
path "pki_k8s/issue/k8s-sorsa-cloud"   { capabilities = ["create"] }
