# Architecture

crimsonglow.ca is a static site, a webmail, and a mailbox backup, all in one AWS account and
managed by the Terraform in [`terraform/`](../terraform/). The site is files in a private S3
bucket behind CloudFront. The webmail is Migadu's open-source Alps running in a Lambda function.
Mail itself is hosted by Migadu, not AWS; AWS holds only the DNS records that point at it and a
daily copy of every mailbox.

## Serving

```mermaid
flowchart LR
  browser([Browser])
  zone["Route 53<br/>crimsonglow.ca zone"]
  cf["CloudFront<br/>crimsonglow.ca, www"]
  router["Router function"]
  site[("S3<br/>crimsonglow-site")]
  api["API Gateway<br/>mail.crimsonglow.ca"]
  alps["Lambda: webmail<br/>Alps"]
  migadu[("Migadu<br/>mailbox")]

  browser -->|DNS lookup| zone
  browser -->|HTTPS| cf
  cf -->|every request| router
  cf -->|signed read, OAC| site
  browser -->|HTTPS| api
  api -->|invoke| alps
  alps -->|IMAPS, SMTPS| migadu
```

- **Site.** CloudFront serves every page from the private bucket; only CloudFront can read it
  (origin access control). Before each request reaches the bucket, the router function sends `/`
  to `/~kjiwa/`, `www` to the apex, and each legacy path in
  [`site/_data/redirects.yml`](../site/_data/redirects.yml) to its new address, and maps a
  trailing `/` to `index.html`. The router is rendered from `redirects.yml`, so a change to it
  takes effect with `scripts/tf.sh apply`. A missing page returns the site's own 404. A
  response-headers policy adds HSTS, a content security policy and the other security headers.
- **Webmail.** API Gateway fronts a single Lambda function that runs Alps behind the Lambda Web
  Adapter. Alps keeps no state: it signs in to Migadu over IMAP and SMTP and stores a user's
  settings in the mailbox. The stage throttles total load. Operation: [`MAIL.md`](MAIL.md).
- **Mail delivery.** MX records point at Migadu; SPF, DKIM and DMARC records in the same zone
  authorise it. AWS never sees a message in transit.

## Deploying

```mermaid
flowchart LR
  pr([Pull request])
  ci["GitHub Actions<br/>build job"]
  deploy["deploy job<br/>main only"]
  role["IAM role<br/>github-deploy"]
  site[("S3 site bucket")]
  cf["CloudFront"]
  alps["Lambda: webmail"]
  operator([Operator])
  tf["scripts/tf.sh apply"]
  stack[("All other resources")]
  state[("S3<br/>crimsonglow-tfstate")]

  pr -->|lint, build, check| ci
  ci -->|merge to main, privacy check passes| deploy
  deploy -->|OIDC token| role
  role -->|sync pages and assets| site
  role -->|invalidate| cf
  role -->|upload code| alps
  operator --> tf
  tf -->|create, change| stack
  tf -->|state| state
```

- **Content** deploys itself. Every push to `main` that passes the `build` job and the shared
  `privacy` workflow syncs the built site to S3, invalidates CloudFront and uploads the webmail
  bundle. `privacy` ([`kjiwa/.github`](https://github.com/kjiwa/.github)) fails on machine-local
  home-directory paths and owner-specific identifiers in tracked files, and on commit emails
  that are not GitHub noreply addresses. GitHub proves its identity to AWS with an OIDC token;
  the `github-deploy` role trusts only this repository's `main` branch and can only write the
  site bucket, invalidate this distribution and update the webmail function. No long-lived AWS
  key exists.
- **Infrastructure** is applied by hand: `scripts/tf.sh apply` with an administrator profile.
  The `terraform` workflow runs only `fmt`, `init -backend=false` and `validate`. The state
  lives in its own versioned bucket. Procedure: [`README.md`](../README.md#infrastructure).

## Mail backup

```mermaid
flowchart LR
  sched["EventBridge Scheduler<br/>daily"]
  build["CodeBuild<br/>mail-backup"]
  ssm["SSM Parameter Store<br/>mailbox password"]
  migadu[("Migadu<br/>mailbox")]
  archive[("S3<br/>crimsonglow-archive")]
  alarm["CloudWatch alarm"]
  sns["SNS topic"]
  you([Alert email])

  sched -->|start build| build
  build -->|read| ssm
  build -->|IMAPS, pull only| migadu
  build -->|sync Maildir| archive
  build -.->|no success in two days| alarm
  alarm --> sns
  sns -->|email| you
```

Migadu does not promise to keep a terminated account's mail, so a copy lives where this account
controls it. The archive bucket is versioned and keeps replaced and deleted objects for 365 days.
The alarm treats missing data as failure, so a job that stopped running alerts the same as one
that fails, and it emails again on recovery. Pull behaviour, alerts and restore:
[`MAIL.md`](MAIL.md).

## What is deployed

| Role | Service | Resource | Purpose |
|---|---|---|---|
| DNS | Route 53 | Hosted zone `crimsonglow.ca` and its records | Apex alias to CloudFront, `www` CNAME to the apex, `mail` alias to API Gateway, MX, SPF, DKIM, DMARC |
| Site | CloudFront | One distribution for the apex and `www` | Serves the site |
| Site | CloudFront | Router function, response-headers policy, origin access control | Redirects and index pages; security headers; private bucket access |
| Site | S3 | `crimsonglow-site` | Built site, private, readable only by CloudFront |
| Site | ACM | Certificate for apex and `www` | TLS for CloudFront; see Decisions for its region |
| Webmail | API Gateway | HTTP API, custom domain `mail.crimsonglow.ca`, throttled stage | Public entry to the webmail |
| Webmail | ACM | Regional certificate for `mail` | TLS for the custom domain |
| Webmail | Lambda | Function `webmail` with the Lambda Web Adapter layer | Runs Alps; code is uploaded by CI |
| Webmail | CloudWatch Logs | Log group `/aws/lambda/webmail` | Function logs |
| Mail backup | CloudWatch Logs | Log group `/aws/codebuild/mail-backup` | Build logs |
| Mail backup | EventBridge Scheduler | Daily schedule | Starts the build |
| Mail backup | CodeBuild | Project `mail-backup` | Pulls each mailbox with `mbsync` |
| Mail backup | S3 | `crimsonglow-archive`, versioned | The copies and their history |
| Mail backup | SSM Parameter Store | `/mail/<address>/password`, set by `mail-password.sh`, not in Terraform | IMAP password for the pull |
| Mail backup | CloudWatch, SNS | Alarm `mail-backup`, topic `crimsonglow-alerts`, email subscription | Alerts when the backup stops succeeding |
| Identity | IAM | OIDC provider for GitHub; roles `github-deploy`, `webmail` and two for the backup | CI deploys without keys; each workload gets only what it needs |
| State | S3 | `crimsonglow-tfstate`, versioned | Terraform state and lock |

## Decisions worth knowing

- **API Gateway, not CloudFront, fronts the webmail.** CloudFront's origin access control needs
  a body hash on every POST, so it cannot sit in front of the Lambda function.
- **The apex certificate is in `us-east-1`.** CloudFront reads certificates only from there.
- **The login key for the webmail is generated by Terraform.** It is in state, so the state
  bucket is the secret store for it. Rotation signs everyone out.
