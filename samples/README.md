# Samples

Real, reproducible artifacts. Nothing here is a mock-up.

- `quant_report_sample.txt` is the unedited output of `odin --quant-report` on 72 hours of live NiceHash SHA256AsicBoost order books (17 to 20 Nov 2026).
- `odin_audit_sample.jsonl` is a sanitized, eight-record audit chain in the exact format ODIN writes. Check it yourself:

```
odin --verify-audit samples/odin_audit_sample.jsonl
```

It prints `AUDIT OK` with the chain tip. Change any character in any record and it names the line that broke.
