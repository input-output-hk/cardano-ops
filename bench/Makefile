all: docs

docs: README.md

README.md: README.org
	pandoc --from org --to gfm <$< >$@
