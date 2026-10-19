resource "aws_route53_zone" "this" {
  name = var.domain

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_route53_record" "this" {
  for_each = local.records

  zone_id = aws_route53_zone.this.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = each.value.alias == null ? each.value.ttl : null
  records = each.value.values

  dynamic "alias" {
    for_each = each.value.alias == null ? [] : [local.alias_targets[each.value.alias]]
    content {
      name                   = alias.value.name
      zone_id                = alias.value.zone_id
      evaluate_target_health = false
    }
  }
}
