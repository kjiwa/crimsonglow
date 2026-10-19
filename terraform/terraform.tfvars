account_id        = "345075859475"
domain            = "crimsonglow.ca"
github_repository = "kjiwa/crimsonglow"

records = {
  "crimsonglow.ca-A" = {
    alias = "site"
  }
  "crimsonglow.ca-AAAA" = {
    alias = "site"
  }
  "crimsonglow.ca-MX" = {
    values = ["10 aspmx1.migadu.com.", "20 aspmx2.migadu.com."]
  }
  "crimsonglow.ca-TXT" = {
    values = [
      "google-site-verification=wewhsofE1PNjCgdm8RfJGK31LuStgXOxC--ovG1qujI",
      "v=spf1 include:spf.migadu.com -all",
      "hosted-email-verify=usomlcq4",
    ]
  }
  "www.crimsonglow.ca-CNAME" = {
    values = ["crimsonglow.ca"]
  }
  "mail.crimsonglow.ca-A" = {
    alias = "webmail"
  }
  "mail.crimsonglow.ca-AAAA" = {
    alias = "webmail"
  }
  "_dmarc.crimsonglow.ca-TXT" = {
    values = ["v=DMARC1; p=none;"]
  }
  "key1._domainkey.crimsonglow.ca-CNAME" = {
    values = ["key1.crimsonglow.ca._domainkey.migadu.com."]
  }
  "key2._domainkey.crimsonglow.ca-CNAME" = {
    values = ["key2.crimsonglow.ca._domainkey.migadu.com."]
  }
  "key3._domainkey.crimsonglow.ca-CNAME" = {
    values = ["key3.crimsonglow.ca._domainkey.migadu.com."]
  }
}
