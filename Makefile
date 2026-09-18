install:
	pre-commit install -t pre-commit -t commit-msg

lint:
	pre-commit run --all-files

luadoc:
	python3 scripts/generate_config_luadoc.py

luadoc-check:
	python3 scripts/generate_config_luadoc.py --check
