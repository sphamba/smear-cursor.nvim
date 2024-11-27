install:
	pre-commit install -t pre-commit -t commit-msg

lint:
	pre-commit run --all-files
