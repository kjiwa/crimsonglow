#!/bin/sh
# Publishes Terraform outputs as the GitHub repository variables ci.yml reads.

set -eu

_set_variable() {
  _set_variable_name="$1"
  _set_variable_output="$2"

  _set_variable_value=$("$(dirname "$0")/tf.sh" output -raw "$_set_variable_output")
  gh variable set "$_set_variable_name" --body "$_set_variable_value"
}

main() {
  _set_variable SITE_BUCKET site_bucket
  _set_variable DISTRIBUTION_ID distribution_id
  _set_variable AWS_ROLE_ARN deploy_role_arn
  _set_variable WEBMAIL_FUNCTION webmail_function
}

main "$@"
