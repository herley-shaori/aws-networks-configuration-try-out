

resource "aws_kms_key" "use_case_key" {
  description               = "CMK for use-case-key"
  deletion_window_in_days   = 7
  tags = {
    Name = "use-case-key"
  }
}

resource "aws_kms_alias" "use_case_key_alias" {
  name          = "alias/use-case-key"
  target_key_id = aws_kms_key.use_case_key.key_id
}

output "use_case_key_id" {
  description = "ID of the KMS CMK use-case-key"
  value       = aws_kms_key.use_case_key.key_id
}

output "use_case_key_arn" {
  description = "ARN of the KMS CMK use-case-key"
  value       = aws_kms_key.use_case_key.arn
}

output "use_case_key_alias_name" {
  description = "Alias name of the KMS CMK use-case-key"
  value       = aws_kms_alias.use_case_key_alias.name
}