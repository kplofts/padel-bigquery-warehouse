# Convenience targets. Local targets need only Node; deploy targets need bq CLI +
# BQ_PROJECT / BQ_LOCATION env vars.
.PHONY: data validate reconcile local setup load transforms deploy clean

data:                 ## generate synthetic source NDJSON into ./data
	node tools/generate.mjs

validate:             ## run local data-quality gate over ./data
	node tools/validate.mjs

reconcile:            ## print expected mart metrics from source (oracle)
	node tools/expected_metrics.mjs

local: data validate reconcile  ## generate + validate + reconcile (no cloud needed)

setup:                ## create datasets + raw tables in BigQuery
	bash load/00_setup.sh

load:                 ## load ./data into raw tables
	bash load/10_load_raw.sh

transforms:           ## build staging -> dims -> facts -> marts
	bash load/20_run_transforms.sh

deploy: setup load transforms  ## full BigQuery build

clean:
	rm -f data/*.ndjson
