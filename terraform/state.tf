terraform {
  backend "s3" {
    bucket       = "crimsonglow-tfstate"
    key          = "tfstate"
    region       = "ca-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
