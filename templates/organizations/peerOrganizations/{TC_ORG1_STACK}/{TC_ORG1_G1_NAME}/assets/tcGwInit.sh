#!/bin/bash

# region: HTTPS cert and key.

unset TC_RAWAPI_HTTPS_CERT_FILE TC_RAWAPI_HTTPS_KEY_FILE 

export TC_RAWAPI_HTTPS_CERT="-----BEGIN CERTIFICATE-----
MIIFkDCCA3igAwIBAgIJAOzUPD/vVqBxMA0GCSqGSIb3DQEBCwUAMF0xCzAJBgNV
BAYTAkRFMSQwIgYDVQQKDBtURS1GT09EIEluZ2VybmF0aW9uYWwgR21iSC4xKDAm
BgkqhkiG9w0BCQEWGXNhbmRvci5taXNrZXlAdGUtZm9vZC5jb20wHhcNMTkwNjI4
MTYxMzU2WhcNNDYxMTEzMTYxMzU2WjBdMQswCQYDVQQGEwJERTEkMCIGA1UECgwb
VEUtRk9PRCBJbmdlcm5hdGlvbmFsIEdtYkguMSgwJgYJKoZIhvcNAQkBFhlzYW5k
b3IubWlza2V5QHRlLWZvb2QuY29tMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIIC
CgKCAgEAx459puBuJw6Yk51v9P1bDaJGoS1lNUl+lE1mp5KCEc7eS8gZn8A+9sOE
iPc2hpOsnC63kvpYXjkJDlYOQobH3jhBozprklu12ezQjkIJwTI2/6iIcc8lDNVE
1/HTkeOoDRgf4igdF8Cxgo4Q8YBRQppQ52mhtKb71DLuN186LhIokVIa1dd32uXR
afqACBe7lFdDmTdUU+MkoueTyj7uNIriROTNRyUrzDREFxxbXphYXj257/q75yes
dqUvk8MaVPdIPT5CxotyO0wroetJvF7f3F7VeRpAdpWsn+8p+Pbig5bDdIkD1k5x
UUtLLrH3LV4MmGhhlwklUrX/OUjrotc8g0eMK+cTZ9q4C+fCeRy+Eqstq/Zly4Vr
pWOb9OjbkiChryvN0cdBjiJ0Ogani9Jf5DCcggMKPQXtaxz9BRDgWyYseX28Bk8Q
hL5Upkq8N3/tWaA/EPdVhhUBeCB0JhepDFU8t3s6UyuZrIZxXyfLnI2BoDZ5S7oP
w1SW84kkLxdkIBkjhb06ZxztPT6XPjA3eYJbM7XW0x3a8jL9R2rMO9fZqGRpTLiO
c6BoOY3Alc/pusse8KWCg1rdUgmf2XyyYJdribHcffNuU04RuZRi/xnXhmag9ofQ
kYnxOrbCIuMNdA7fUKIQHaAg8sONZ5uV/GPJWleM35i6lpwF6sECAwEAAaNTMFEw
HQYDVR0OBBYEFC+OZIo2tbMEKUQDOUIaD0bYWZFrMB8GA1UdIwQYMBaAFC+OZIo2
tbMEKUQDOUIaD0bYWZFrMA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZIhvcNAQELBQAD
ggIBAHgHLAoE2sXknD0XUNFpuodB5hGwMjJALR4jqQT3kPkJwZ9JRwT6iHlsoLxo
j/jXtAMjgzebMB90eqWeqxZAlLjzaV8QjelvN06X1SRe0srqaN6gCVV+hRxOnKDD
EBRmHr1t3FkuAoKzk5ofzFwMVwjrpyCeDnCBcIA22i2g/8hlzFhbDdYFuBFoQD1w
eqSRctGornNijzq4KPNtaID4oAD6c4ifzZAt94Bvb7+SjdeqH28bkiuOS8uQ26ph
DTu7SIIN4FYCQ//yeaILIBXxisOSXWmMUWYPv+jtt+XgB9I4na1QwX978oQr3CT9
+rIzSkl63OiNxvcT6gYJBdasna+6Zz1ToIeIpyvMUhfru4WI8tLJWaE2e2UFMk8O
TU8MXBdUpDRSXPHoGTuOe99GYDqorluK73bGhVcn1aDWNxhQ0Kjs2baiPBhTfTaa
pDsgKEwrConVACPQrsRV4mGaViymXmULtf6Czus6RgfwPT+LvqjaLJWOv2zLdQ8z
gh51ODjXDKRyJhgXcGlm/CpMzmrlgbHlSbO506erCiDHn4zEUiD126AfM0gKidV1
8Y0xL4pgZT0zx8oLDryriXX8Xtgoxwx86+3LCRpAOZKlqQSfHRPZmAG+ZNdyP6sW
OwFDtZpFF4BnzOF4MJaJ1OuS+0m5xWyiRkd2JX9dj64cMfI0
-----END CERTIFICATE-----"

export TC_RAWAPI_HTTPS_KEY="-----BEGIN PRIVATE KEY-----
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
Y9rdr62KQ5aXN9FAarw54Yu3FnUOAxHK
-----END PRIVATE KEY-----"

# endregion: HTTPS

# commonPrintfBold "init.sh starts"

while true
do
	${TC_ORG1_G1_ASSETS_DIR}/main
	sleep 5
done
