# External connector ZIP transport adapter

This is a preparation/controller outside the product repository, not a replacement CI runner. No collection or native proof has been executed while preparing it. The synthetic tests only exercise rejection and binding rules.

The coordinator must download receipt ZIPs with the authorized GitHub connector and save each actual GitHub artifact metadata JSON object. Populate `manifest.template.json` with real run/head IDs, paths, exact byte counts and hashes. The artifact API `digest` must be present and equal `sha256:<ZIP SHA256>`; missing digest fails closed. Saved artifact metadata is hash-bound and independently compared against fresh metadata retrieved by the original collector transport. Metadata should be the artifact object, not a connector wrapper or manufactured response. Include every connector-delivered receipt ZIP, not unrelated artifacts. Do not include signed URLs or authentication.

Invoke after inputs are ready:

```sh
python /workspace/ci-artifact-transport/collect_with_connector_zips.py \
  --manifest /workspace/ACTUAL-TRANSPORT-MANIFEST.json \
  --output-dir /workspace/NEW-COLLECTION-DIRECTORY \
  --transport-report /workspace/NEW-TRANSPORT-REPORT.json
```

Both outputs must be new. This runs the existing pinned `tests/verification-ci.py` collector unchanged. It overrides only that loaded module's `api_response`: exact manifest ZIP endpoints return prevalidated immutable bytes; every other endpoint calls the original function. The adapter neither writes product files nor replaces any validation/extraction/aggregation function. ZIP responses have an empty header mapping because connector response headers were not observed; no HTTP headers are invented. Real gh metadata headers and bodies remain unchanged.

Before collection: fresh run identity/head/repository, fresh artifact ID/name/expiry/workflow-run/head/digest, saved metadata SHA, exact ZIP endpoint, ZIP size and SHA are checked. Limits: 32MiB per ZIP (collector constant), 256MiB combined cached ZIPs, 1000 entries, 1MiB per metadata file, 2MiB manifest. Duplicate endpoints, symlink input files, mismatches, unused or repeated substituted ZIPs fail closed. Collector source hash is checked before import, after import and after collection. Original collector still owns safe ZIP extraction and collection validation.

A failure can leave an incomplete collection directory, as the original collector already can. Do not consume it as accepted proof. Require controller exit0 plus transport report, then run the original `verification-ci.py aggregate` command separately against the correct frozen source and plan. The transport report records the controller and collector source hashes and explicitly does not claim aggregation acceptance.

The template pins the collector version observed at preparation time. If the coordinator intentionally changes collector source, regenerate/review the pin before use. Repository dependency modules are loaded by the original collector in its normal manner; the controller is not a substitute for the full source/plan freeze.
