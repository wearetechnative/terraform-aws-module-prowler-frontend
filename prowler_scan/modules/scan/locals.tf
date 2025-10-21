locals {
  region_args     = length(compact(var.prowler_scan_regions)) == 0 ? [] : concat(["-f"], compact(var.prowler_scan_regions))
  compliance_args = length(compact(var.compliance_checks)) == 0 ? [] : concat(["--compliance"], compact(var.compliance_checks))
  severity_args   = length(compact(var.severity)) == 0 ? [] : concat(["--severity"], compact(var.severity))
  command_args    = concat(local.region_args, local.compliance_args, local.severity_args)
}