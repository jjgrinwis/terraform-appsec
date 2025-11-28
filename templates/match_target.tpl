{
  "defaultFile": "NO_MATCH",
  "isNegativePathMatch": false,
  "type": "website",
  "filePaths": ["/*"],
  "hostnames": ${jsonencode(hostnames)},
  "securityPolicy": {
    "policyId": "${policy_id}"
  }
}